# This file is auto-generated from the current state of the database. Instead of editing this file, 
# please use the migrations feature of Active Record to incrementally modify your database, and
# then regenerate this schema definition.
#
# Note that this schema.rb definition is the authoritative source for your database schema. If you need
# to create the application database on another system, you should be using db:schema:load, not running
# all the migrations from scratch. The latter is a flawed and unsustainable approach (the more migrations
# you'll amass, the slower it'll run and the greater likelihood for issues).
#
# It's strongly recommended to check this file into your version control system.

ActiveRecord::Schema.define(:version => 14) do

  create_table "courses", :force => true do |t|
    t.string  "name"
    t.integer "number",    :limit => 11
    t.string  "dept_code"
  end

  create_table "courses_systems", :id => false, :force => true do |t|
    t.integer "course_id", :limit => 11
    t.integer "system_id", :limit => 11
  end

  create_table "faculties", :force => true do |t|
    t.string  "cnet"
    t.boolean "admin",           :default => false
    t.string  "hashed_password"
    t.string  "salt"
    t.string  "preferences",     :default => ":login_page: 'main'"
  end

  create_table "images", :force => true do |t|
    t.string   "z_name"
    t.string   "name"
    t.string   "url"
    t.string   "zip_url"
    t.integer  "faculty_id",       :limit => 11
    t.datetime "expiry"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.string   "status"
    t.integer  "magnification",    :limit => 11
    t.integer  "size",             :limit => 11
    t.datetime "show_annotations"
  end

  create_table "linkers", :force => true do |t|
    t.integer "image_id",      :limit => 11
    t.integer "system_id",     :limit => 11
    t.integer "subsection_id", :limit => 11
    t.integer "linking_id",    :limit => 11
    t.string  "linking_type"
  end

  create_table "pathway_items", :force => true do |t|
    t.integer  "image_id",   :limit => 11
    t.integer  "pathway_id", :limit => 11
    t.integer  "position",   :limit => 11
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  create_table "pathways", :force => true do |t|
    t.string   "name"
    t.integer  "faculty_id", :limit => 11
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  create_table "sections", :force => true do |t|
    t.string  "name"
    t.integer "number",    :limit => 11
    t.integer "course_id", :limit => 11
  end

  create_table "subsections", :force => true do |t|
    t.string  "name"
    t.integer "section_id", :limit => 11
  end

  create_table "systems", :force => true do |t|
    t.string "name"
  end

end
