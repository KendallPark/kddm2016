class CreatePatients < ActiveRecord::Migration[5.0]
  def change
    create_table :patients do |t|
      t.integer :pid, null: false
      t.boolean :infection, null: false
      t.string :sex, null: false
      t.datetime :surgery_time, null: false
      t.datetime :infection_time, null: false
      t.date :dob, null: false

      t.timestamps
    end
  end
end
