class CreateSystems < ActiveRecord::Migration
  def self.up
    create_table :systems do |t|
      t.column :name, :string
    end
  end

  def self.down
    drop_table :systems
  end
end
