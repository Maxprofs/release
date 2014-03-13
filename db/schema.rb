# encoding: UTF-8
# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# Note that this schema.rb definition is the authoritative source for your
# database schema. If you need to create the application database on another
# system, you should be using db:schema:load, not running all the migrations
# from scratch. The latter is a flawed and unsustainable approach (the more migrations
# you'll amass, the slower it'll run and the greater likelihood for issues).
#
# It's strongly recommended to check this file into your version control system.

ActiveRecord::Schema.define(:version => 20140313150840) do

  create_table "applications", :force => true do |t|
    t.string   "name"
    t.string   "repo"
    t.datetime "created_at",                      :null => false
    t.datetime "updated_at",                      :null => false
    t.string   "status_notes"
    t.string   "shortname"
    t.string   "domain"
    t.boolean  "archived",     :default => false, :null => false
  end

  add_index "applications", ["name"], :name => "index_applications_on_name", :unique => true
  add_index "applications", ["repo"], :name => "index_applications_on_repo", :unique => true

  create_table "deployments", :force => true do |t|
    t.string   "version"
    t.string   "environment"
    t.integer  "application_id"
    t.datetime "created_at",     :null => false
    t.datetime "updated_at",     :null => false
  end

  add_index "deployments", ["application_id", "environment", "created_at"], :name => "index_deployments_on_application_id_etc"

  create_table "releases", :force => true do |t|
    t.datetime "created_at",  :null => false
    t.datetime "updated_at",  :null => false
    t.integer  "user_id"
    t.datetime "start_at"
    t.datetime "end_at"
    t.text     "description"
  end

  create_table "users", :force => true do |t|
    t.string   "name"
    t.string   "email"
    t.string   "uid"
    t.text     "permissions"
    t.boolean  "remotely_signed_out", :default => false
    t.datetime "created_at",                             :null => false
    t.datetime "updated_at",                             :null => false
  end

end
