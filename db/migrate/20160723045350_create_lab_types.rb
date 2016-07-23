class CreateLabTypes < ActiveRecord::Migration[5.0]
  def change
    create_table :lab_types do |t|
      t.string :name, null: false, unique: true

      t.timestamps
    end
  end
end
