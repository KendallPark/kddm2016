class CreateGenes < ActiveRecord::Migration[5.0]
  def change
    create_table :genes do |t|
      t.float :fitness
      t.integer :generation, null: false

      t.timestamps
    end
  end
end
