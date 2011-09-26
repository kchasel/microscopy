class CreateFaculties < ActiveRecord::Migration
  def self.up
    create_table :faculties do |t|
      t.column :cnet, :string
      t.column :admin, :boolean, :default => false
    end
  end

  def self.down
    drop_table :faculties
  end
end
