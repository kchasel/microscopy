class CreateImages < ActiveRecord::Migration
  def self.up
    create_table :images do |t|
      t.column :z_name, :string
      t.column :name, :string
      t.column :url, :string
      t.column :zip_url, :string
      t.column :faculty_id, :integer
      t.column :expiry, :datetime
      t.column :created_at, :timestamp
      t.column :updated_at, :timestamp
      t.column :status, :string
    end
  end

  def self.down
    drop_table :images
  end
end
