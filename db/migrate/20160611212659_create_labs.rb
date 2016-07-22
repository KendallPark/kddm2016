class CreateLabs < ActiveRecord::Migration[5.0]
  def change
    create_table :labs do |t|
      t.belongs_to :patient, foreign_key: true
      t.datetime :date, null: false
      t.string :name_original, null: false
      t.string :name, null: false
      t.string :qualifier
      t.string :value_original, null: false
      t.numeric :value, null: false
      t.integer :pid, null: false
      t.boolean :fuzzy_name, null: false, default: false

      t.timestamps
    end
  end
end
