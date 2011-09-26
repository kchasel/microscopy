class Subsection < ActiveRecord::Base
  
  has_many :linkers, :as => :linking, :dependent => :destroy
  has_many :images, :through => :linkers
  belongs_to :section, :include => :course
  
  validates_presence_of :name, :section_id
  
end
