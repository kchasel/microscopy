class Section < ActiveRecord::Base
  
  belongs_to :course
  has_many :subsections, :dependent => :destroy
  
  validates_presence_of :number, :course_id
  
  after_create :ensure_at_least_1_subsection
  
  def images(type=:all,conditions=nil,options=nil)
    self.subsections.collect { |ss| ss.images.find(type, options, :order => 'name', :conditions => conditions) }.flatten.uniq
  end
  
  def ensure_at_least_1_subsection
    self.subsections.create(:name => "Default Subsection for Section #{number} of Course #{course.number}") if self.subsections.empty?
  end
  
end
