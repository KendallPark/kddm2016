class AddNumberOfPatientsToLabType < ActiveRecord::Migration[5.0]
  def self.up
    add_column :lab_types, :number_of_patients, :integer
    add_column :lab_types, :number_of_labs, :integer

    LabType.all.each do |lab_type|
      lab_type.number_of_patients!
      lab_type.number_of_labs!
    end

    change_column_null :lab_types, :number_of_patients, false
    change_column_null :lab_types, :number_of_labs, false
  end

  def self.down
    remove_column :lab_types, :number_of_patients
    remove_column :lab_types, :number_of_labs
  end
end
