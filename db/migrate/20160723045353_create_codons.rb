class CreateCodons < ActiveRecord::Migration[5.0]
  def change
    create_table :codons do |t|
      t.belongs_to :lab_type, foreign_key: true

      t.belongs_to :value_start, references: :labs
      t.belongs_to :value_end, references: :labs

      t.belongs_to :date_start, references: :labs
      t.belongs_to :date_end, references: :labs

      t.timestamps
    end
  end
end
