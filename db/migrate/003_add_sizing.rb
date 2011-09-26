class AddSizing < ActiveRecord::Migration
  def self.up
    add_column :images, :magnification, :integer
    add_column :images, :size, :integer
  end

  def self.down
    remove_column :images, :magnification
    remove_column :images, :size
  end
end
