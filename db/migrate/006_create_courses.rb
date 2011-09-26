class CreateCourses < ActiveRecord::Migration
  def self.up
    create_table :courses do |t|
      t.column :name, :string
      t.column :number, :integer
      t.column :dept_code, :string
    end
  end

  def self.down
    drop_table :courses
    add_column :images, :course_number, :string
    add_column :images, :course_section, :string
  end
end
