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

ActiveRecord::Schema.define(version: 20160819234701) do

  # These are extensions that must be enabled in order to support this database
  enable_extension "plpgsql"
  enable_extension "hstore"

  create_table "codons", force: :cascade do |t|
    t.integer  "lab_type_id"
    t.datetime "created_at",                                       null: false
    t.datetime "updated_at",                                       null: false
    t.integer  "true_positive"
    t.integer  "false_positive"
    t.integer  "true_negative"
    t.integer  "false_negative"
    t.decimal  "fitness"
    t.decimal  "hours_after_surgery",                              null: false
    t.decimal  "val_start",                                        null: false
    t.decimal  "val_end",                                          null: false
    t.string   "dx_cache"
    t.boolean  "gilded",              default: false
    t.string   "ever_cache"
    t.string   "ratio_cache"
    t.float    "threshold",           default: 0.6392924348840148
    t.string   "crossing_cache"
    t.string   "within_days_cache"
    t.index ["lab_type_id"], name: "index_codons_on_lab_type_id", using: :btree
  end

  create_table "codons_genes", id: false, force: :cascade do |t|
    t.integer "codon_id", null: false
    t.integer "gene_id",  null: false
    t.index ["codon_id", "gene_id"], name: "index_codons_genes_on_codon_id_and_gene_id", using: :btree
    t.index ["gene_id", "codon_id"], name: "index_codons_genes_on_gene_id_and_codon_id", using: :btree
  end

  create_table "genes", force: :cascade do |t|
    t.float    "fitness"
    t.datetime "created_at",                     null: false
    t.datetime "updated_at",                     null: false
    t.string   "dx_cache"
    t.hstore   "sequence",                       null: false
    t.integer  "true_positive"
    t.integer  "true_negative"
    t.integer  "false_positive"
    t.integer  "false_negative"
    t.boolean  "gilded",         default: false
    t.string   "type"
    t.integer  "size"
    t.string   "family"
    t.string   "signature"
  end

  create_table "lab_types", force: :cascade do |t|
    t.string   "name",               null: false
    t.datetime "created_at",         null: false
    t.datetime "updated_at",         null: false
    t.integer  "number_of_patients", null: false
    t.integer  "number_of_labs",     null: false
    t.decimal  "val_max",            null: false
    t.decimal  "val_min",            null: false
    t.decimal  "hours_max",          null: false
    t.decimal  "hours_min",          null: false
    t.string   "patient_cache"
  end

  create_table "labs", force: :cascade do |t|
    t.integer  "patient_id"
    t.datetime "date",                                null: false
    t.string   "name_original",                       null: false
    t.string   "name",                                null: false
    t.string   "qualifier"
    t.string   "value_original",                      null: false
    t.decimal  "value",                               null: false
    t.integer  "pid",                                 null: false
    t.boolean  "fuzzy_name",          default: false, null: false
    t.datetime "created_at",                          null: false
    t.datetime "updated_at",                          null: false
    t.integer  "lab_type_id",                         null: false
    t.decimal  "hours_after_surgery",                 null: false
    t.boolean  "outlier",             default: false
    t.boolean  "test_data",           default: false
    t.index ["lab_type_id"], name: "index_labs_on_lab_type_id", using: :btree
    t.index ["patient_id"], name: "index_labs_on_patient_id", using: :btree
  end

  create_table "patients", force: :cascade do |t|
    t.integer  "pid",            null: false
    t.boolean  "infection"
    t.string   "sex",            null: false
    t.datetime "surgery_time",   null: false
    t.datetime "infection_time"
    t.date     "dob",            null: false
    t.datetime "created_at",     null: false
    t.datetime "updated_at",     null: false
    t.float    "age_at_surgery"
  end

  add_foreign_key "codons", "lab_types"
  add_foreign_key "labs", "lab_types"
  add_foreign_key "labs", "patients"
end
