class AddLabTypeToLabs < ActiveRecord::Migration[5.0]
  def self.up
    add_reference :labs, :lab_type, foreign_key: true

    Lab.test_names.each do |name|
      lab_type = LabType.create!(name: name)
      Lab.where(name: name).update_all(lab_type_id: lab_type.id)
    end

    change_column_null :labs, :lab_type_id, false
  end

  def self.down
    remove_reference :labs, :lab_type
  end
end
