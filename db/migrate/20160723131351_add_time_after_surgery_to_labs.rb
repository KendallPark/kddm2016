class AddTimeAfterSurgeryToLabs < ActiveRecord::Migration[5.0]
  def self.up
    add_column :labs, :hours_after_surgery, :decimal

    Patient.all.each do |patient|
      patient.labs.each do |lab|
        lab.update!(hours_after_surgery: (lab.date - patient.surgery_time) / 3600)
      end
    end

    change_column_null :labs, :hours_after_surgery, false
  end

  def self.down
    remove_column :labs, :hours_after_surgery
  end

end
