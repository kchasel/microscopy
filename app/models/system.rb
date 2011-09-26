class System < ActiveRecord::Base
  
  has_many :linkers, :as => :linking, :dependent => :destroy
  has_many :images, :through => :linkers
  has_and_belongs_to_many :courses
  
  validates_presence_of :name
  
end
