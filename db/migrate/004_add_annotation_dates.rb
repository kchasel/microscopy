class AddAnnotationDates < ActiveRecord::Migration
  def self.up
    add_column :images, :show_annotations, :timestamp
  end

  def self.down
    remove_column :images, :show_annotations
  end
end
