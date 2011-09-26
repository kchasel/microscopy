class CreatePathways < ActiveRecord::Migration
  def self.up
    create_table :pathways do |t|
      t.string :name
      t.integer :faculty_id
      t.timestamps
    end
    create_table :pathway_items do |t|
      t.integer :image_id
      t.integer :pathway_id
      t.integer :position
      t.timestamps
    end
  end

  def self.down
    drop_table :pathways
    drop_table :pathway_items
  end
end
