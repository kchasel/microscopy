class PathwayItem < ActiveRecord::Base
  
  belongs_to :pathway
  belongs_to :image
  acts_as_list :scope => :pathway
  
  before_create :ensure_image_exists
  
  def self.only_public
    with_scope :find => { :include => "image", :conditions => "images.status = 'public'" } do
      yield
    end
  end
  
  def ensure_image_exists
    if Image.find(image_id)
      return true
    end
  rescue
    return false
  end
  
end
