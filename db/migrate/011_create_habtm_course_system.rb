class CreateHabtmCourseSystem < ActiveRecord::Migration
  def self.up
    create_table :courses_systems, :id => false do |t|
      t.column :course_id, :integer
      t.column :system_id, :integer
    end
  end

  def self.down
    drop_table :courses_systems
  end
end
