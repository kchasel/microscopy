class AddGeneralAdmin < ActiveRecord::Migration
  def self.up
    add_column :faculties, :hashed_password, :string
    add_column :faculties, :salt, :string
    f = Faculty.create(:cnet => ZoomifyVars::CONFIG[:shared_admin])
    f.update_attribute(:admin, true)
    pw = Faculty.new_root_pw
    File.open(RAILS_ROOT + '/config/first_root_pw.txt', 'w+') do |f|
      f.write("#{pw}\n\nLogin as the root user and change the root password. You can then delete this file.")
    end
  end

  def self.down
    remove_column :faculties, :hashed_password
    remove_column :faculties, :salt
    Faculty.find_by_cnet(ZoomifyVars::CONFIG[:shared_admin]).destroy
  end
end
