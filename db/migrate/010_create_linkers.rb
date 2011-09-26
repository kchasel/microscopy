class CreateLinkers < ActiveRecord::Migration
  def self.up
    create_table :linkers do |t|
      t.column :image_id, :integer
      t.column :system_id, :integer
      t.column :subsection_id, :integer
      t.column :linking_id, :integer
      t.column :linking_type, :string
    end
  end

  def self.down
    drop_table :linkers
  end
end
