class Course < ActiveRecord::Base
  
  has_many :sections, :include => :subsections, :dependent => :destroy, :order => :number
  has_many :subsections, :through => :sections
  has_and_belongs_to_many :systems
  
  validates_presence_of :name
  validates_format_of :number, :with => /\d{5}/
  
  def images(type=:all,conditions=nil,options=nil)
    self.subsections.collect { |ss| ss.images.find(type, options, :order => 'name', :conditions => conditions) }.flatten.uniq
  end 
  
end
