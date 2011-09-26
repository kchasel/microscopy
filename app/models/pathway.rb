class Pathway < ActiveRecord::Base
  
  validates_presence_of :name
  validates_presence_of :order, :on => :create
  validates_uniqueness_of :name
  
  has_many :pathway_items, :order => :position, :dependent => :destroy
  has_many :images, :through => :pathway_items
  
  after_save :delete_if_empty
  
  attr_accessor :order
  
  # Find all the images associated with the supplied pathway by the order.
  def sorted_images
    return pathway_items.collect { |item| item.image }
  end
  
  # If the supplied value is a String (coming from the scriptaculous Sortable on the pathway new/edit pages), converts
  # it into an array. If the value is an array, set order to it immediately. Then creates/finds pathway items
  # that correspond to the image ids in the order. Changes do not take effect until the pathway is saved!!
  # NOTE – The order is not a database value. The order of the pathway is determined by the 'position' column
  # on each PathwayItem. See acts_as_list for more information.
  def order=(value)
    if value.class == String
      @order = sortable_to_array(value)
    else
      @order = value == nil ? [] : value
    end
    if new_record?
      counter = 1
      @order.each do |id|
         pathway_items.build(:image_id => id, :position => counter)
         counter += 1
      end
    else
      in_list_items = []
      @order.reverse.each do |id|
        pwitem = pathway_items.find_or_create_by_image_id(id)
        pwitem.move_to_top
        in_list_items << pwitem
      end
      pathway_items.each do |item|
        destroy_item_if_not_included(item, in_list_items)
      end
    end
  end
  
  # Converts a scriptaculous Sortable.serialize string to an array
  def sortable_to_array(value)
    return value.split('&').collect {|v| v.scan(/\d/).to_s.to_i }
  end
  
  # Only allows the supplied user to find their own pathways.
  def self.only_own(user)
    Pathway.with_scope :find => { :conditions => ["faculty_id = ?", user.id]} do
      yield
    end
  end
  
  private
  
  # Destroys an item if it's not included in the array
  def destroy_item_if_not_included(item, array)
    unless array.include?(item)
      item.destroy
    end
  end
  
  # If the pathway has no pathway_items, delete it.
  def delete_if_empty
    reload
    if pathway_items.empty?
      destroy
    end
  end
  
end
