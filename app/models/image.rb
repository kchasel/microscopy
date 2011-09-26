class Image < ActiveRecord::Base
  
  # All of the validations below must be true when a slide is created. Those validating the uploaded file are only applied
  # when a slide is created, but the rest must always be true, whether the slide is being created or updated.
  
  validates_presence_of :name, :status, :message => 'must have a value.'
  validates_presence_of :file, :on => :create, :unless => :batch_file
  validates_numericality_of :magnification, :message => 'is required. Please enter the magnification 
  at which this slide was produced, using only digits.'
  validates_each :file, :on => :create, :unless => :batch_file do |i, attr, value|
    i.errors.add attr, 'must be a zip file (Mac users: make sure your file has an extension).' if i.extension != 'zip'
  end
  validates_uniqueness_of :name
  validates_uniqueness_of :z_name, :message => ": There is already a slide with this filename in the system.
  Duplicate filenames are not allowed."
  validates_each :section_ids, :if => Proc.new { |image| image.subsections.empty? } do |record, attr, value|
    if not value.delete_if { |e| e == "" }.empty?
      record.errors.add :commatted_secs, 'are in the incorrect format.' if value.select { |id| id =~ /^\d{5} \d{1,2}$/ } != value
      record.errors.add :commatted_secs, "are the same. You can't add the same section twice." if value.uniq != value
    end
  end
  
  belongs_to :faculty
  has_many :linkers
  has_many :subsections, :through => :linkers, :include => [:section], :source => :linking, :source_type => "Subsection", :class_name => "Subsection"
  #has_many :subsections, :through => :linkers, :include => [:section], :source => :subsection, :conditions => "linkers.linking_type = 'Subsection'"
  has_many :systems, :through => :linkers, :source => :linking, :source_type => "System", :class_name => "System"
  # has_many :systems, :through => :linkers, :source => :system, :conditions => "linkers.linking_type = 'System'"
  has_many :pathway_items, :dependent => :destroy
  has_many :pathways, :through => :pathway_items
  
  # The following actions are performed when a new slide is created (but not when updated). The first extracts relevant data
  # from the uploaded file, including filename and what will be the URL of the zip. The second actually does the saving
  # of the zip, unzipping, and creation of the XML file for the slide from template.xml
  before_validation_on_create :uploaded_file
  after_create :save_files
  after_save :assign_sections, :assign_systems
  
  # This action is performed when a slide is deleted. It removes all files relating to the slide.
  after_destroy :delete_files
  
  # These are attributes of slide in addition to those from the database. They are for the most part only used in this model
  attr_accessor :file, :content_type, :file_name_base, :file_name_all, :extension, :batch, :commatted_secs, :maintain_sections, :systems_array, :maintain_systems
  
  def batch_file
    return true if self.batch == true
    return false
  end
  
  # Extracts information from the uploaded zip when a new slide is being added. Not run if the new slide is part of a
  # batch upload.
  def uploaded_file
    unless self.batch == true
    if self.file != ""
      self.file_name_all = sanitize_fn(file.original_filename)
      self.file_name_base = file_name_all.split('.')[0]
      self.extension = file_name_all.split('.')[1]
      self.content_type = file.content_type.strip
      zip_url = "#{Z_URL}/zips/#{file_name_all}"
      write_attribute("zip_url", zip_url)
      write_attribute("z_name", file_name_base)
    end
    end
  end
  
  def self.only_public
    with_scope :find => { :conditions => 'status = \'public\'' } do
      yield
    end
  end
  
  def self.no_show_private_to_all(user)
    with_scope :find => { :conditions => ["IF(faculty_id != ?, status != ?, status IN (?,?,?))", user.id, 'private_all', 'private','public','private_all'] } do
      yield
    end
  end
  
  def self.only_edit_own(user)
    with_scope :find => { :conditions => ["faculty_id = ?", user.id] } do
      yield
    end
  end
  
  # Transfers ownership of a slide to another user, identified by user.
  def transfer_to(user)
    self.update_attribute(:faculty_id, user.id)
  end
  
  # Makes the annotations of the slide visible to students immediately
  def show_now
    update_attribute(:show_annotations, Time.now)
  end
  
  # Called to determine if annotations are visible now
  def annotations?
    show_annotations < Time.now if show_annotations
  end
  
  def commatted_secs
    if @commatted_secs == nil
      @commatted_secs = create_commatted_list_of_sections
    end
    @commatted_secs
  end
  
  def create_commatted_list_of_sections
    list = ""
    sections.each do |s|
      list += "#{s.course.number} #{s.number}"
      list += ", " unless s == sections.last
    end
    list
  end
  
  def section_ids
    commatted_secs.split(/, |,/)
  end
  
  def assign_sections
    if commatted_secs != create_commatted_list_of_sections
      all_ss = self.subsections
      self.subsections.delete(all_ss) unless maintain_existing == true
      section_ids.each do |s|
        cnum, snum = s.split[0], s.split[1]
        self.add_section=Course.find_or_create_by_number(:number => cnum, :name => "MEDC #{cnum}").sections.find_or_create_by_number(:number => snum, :name => "Section #{snum}")
      end
    end
  end
  
  def systems_array
    if @systems_array == nil
      @systems_array = system_ids
    end
    @systems_array
  end
  
  def assign_systems
    array = systems_array.uniq.reject { |s| s == "" }
    sysarray = System.find(array)
    systems.delete(systems)
    systems << sysarray
  end
  
  def maintain_existing
    if @maintain_existing == "1"
      return true
    else
      return false
    end
  end
  

  def sections(course=nil)
    self.subsections.collect { |ss| 
      if course
        ss.section if course.id == ss.section.course_id
      else
        ss.section
      end }.compact.uniq
  end

  def add_section=(newsec)
    self.subsections << newsec.subsections.first if not self.sections.include?(newsec)
  end
  
  def courses
    self.sections.collect { |s| s.course }.uniq
  end
    
  private
  
  # Sanitizes a filename to make it safe for the server
  def sanitize_fn(file_name)
    just_fn = File.basename(file_name)
    just_fn.sub(/[^\w.\-]/,'_')
  end
  
  # Redefines the status attribute to ensure that status is always one of  'private', 'public', or 'private_all'
  def status=(value)
    if value == 'private' or value == 'private_all'
      write_attribute('status', value)
    else
      write_attribute('status', 'public')
    end
  end
  
  def save_files
    folder_url = "/z_images/#{id}/#{z_name}/"
    update_attribute(:url, folder_url)
    unless self.batch == true
      # this is only executed if the new slide is not part of a batch upload (= has a corresponding zip file)
      zip_url = "/z_images/zips/#{file_name_all}"
      unzip_url = "/z_images/#{id}/"
      File.open(PUB_URL + zip_url, "wb") do |f|
        f.write(self.file.read)
      end
      # this unzips the zip file into its new home, /public/z_images/[id of new slide]. It ignores files that
      # begin with '__', as these are often unnecessary hidden files added by Mac OS X.
      # Kernel.system("ditto -xk #{PUB_URL + zip_url} #{PUB_URL + unzip_url}") works too on the Mac
      Kernel.system("unzip #{PUB_URL + zip_url} -x __* -d #{PUB_URL + unzip_url}")
      # Now the zip file is deleted (no longer necessary)
      Kernel.system("rm #{PUB_URL + zip_url}")
    else
      # Creates the new home for the slide, then moves its folder from the upload folder (defined in application.rb)
      # to the new ID folder, /public/z_images/[id of new slide]
      Kernel.system("mkdir #{PUB_URL}/z_images/#{id}/; mv #{UPLOAD_LOCATION}/#{z_name} #{PUB_URL}/z_images/#{id}/#{z_name}")
    end
    generate_xml
  end
  
  # Creates a new XML file for the slide from the template XML file, /public/z_images/xml/template.xml
  def generate_xml
    xml_url = "/z_images/xml/#{id}.xml"
    template = "/template.xml"
    slide_name = self.name
    creation_time = get_time_for_template
    File.open(PUB_URL + xml_url, "wb") do |f|
      File.open(PUB_URL + template) do |t|
        t.each do |s|
          s.gsub!('#{TIMENOW}', creation_time)
          s.gsub!('#{SLIDENAME}', slide_name)
          f.write(s)
        end
      end
    end
  end
  
  def get_time_for_template
    Time.now.strftime('%Y%m%d%H%M%S')
  end

  
  def delete_files
    # After a db entry is deleted, deletes the XML file associated with that entry, as well as the folder containing the slide data
    # and the original zip file that was uploaded (if it was not deleted on upload)
    xml_url = "/z_images/xml/#{id}.xml"
    begin
      File.delete(PUB_URL + self.zip_url) if self.zip_url and File.exists?(PUB_URL + self.zip_url)
      system("rm -r #{PUB_URL}/z_images/#{id}/")
      File.delete(PUB_URL + xml_url)
    rescue
    end
  end
  
  def check_for_abandoned_structures
    # Delete any courses that are left with no images
    self.courses.each { |c| c.destroy if c.images.empty? }
    # Delete any sections that are left with no images
    self.sections.each { |s| s.destroy if s.images.empty? }
    # Delete any subsections that are left with no images
    self.subsections.each { |ss| ss.destroy if ss.images.empty? }
  end
  
end
