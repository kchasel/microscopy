class DropCourseColumnsInImageTable < ActiveRecord::Migration
  
  # This migration does nothing unless the existing database contains course number and section number fields
  # in the images table, in which case these fields are removed.
  
  def self.up
    remove_column(:images, :course_number) if Image.new.respond_to?(:course_number)
    remove_column(:images, :course_section) if Image.new.respond_to?(:course_section)
  end

  def self.down
  end
end
