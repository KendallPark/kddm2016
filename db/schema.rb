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
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema.define(version: 20160611212659) do

  # These are extensions that must be enabled in order to support this database
  enable_extension "plpgsql"

  create_table "labs", force: :cascade do |t|
    t.integer  "patient_id"
    t.datetime "date",                           null: false
    t.string   "name_original",                  null: false
    t.string   "name",                           null: false
    t.string   "qualifier"
    t.string   "value_original",                 null: false
    t.decimal  "value",                          null: false
    t.integer  "pid",                            null: false
    t.boolean  "fuzzy_name",     default: false, null: false
    t.datetime "created_at",                     null: false
    t.datetime "updated_at",                     null: false
    t.index ["patient_id"], name: "index_labs_on_patient_id", using: :btree
  end

  create_table "patients", force: :cascade do |t|
    t.integer  "pid",            null: false
    t.boolean  "infection",      null: false
    t.string   "sex",            null: false
    t.datetime "surgery_time",   null: false
    t.datetime "infection_time"
    t.date     "dob",            null: false
    t.datetime "created_at",     null: false
    t.datetime "updated_at",     null: false
  end

  add_foreign_key "labs", "patients"
end
