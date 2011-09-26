class AddUserPrefs < ActiveRecord::Migration
  def self.up
    add_column :faculties, :preferences, :string, :default => ":login_page: 'main'"
  end

  def self.down
    remove_column :faculties, :preferences
  end
end
 