class AddSurgeryAgeToPatients < ActiveRecord::Migration[5.0]
  def self.up
    add_column :patients, :age_at_surgery, :float

    Patient.all.each do |patient|
      patient.update!(age_at_surgery: ((patient.surgery_time.to_date  - patient.dob)/(Time.days_in_year)).to_f)
    end

    lab_type = LabType.new(name: "age",
                number_of_patients: Patient.count,
                number_of_labs: Patient.count,
                val_max: Patient.maximum(:age_at_surgery),
                val_min: Patient.minimum(:age_at_surgery),
                hours_max: -1,
                hours_min: -1,
                patient_cache: Patient.all_cache)
    lab_type.save!
    lab_type.reload

    Patient.all.each do |patient|
      lab_type.labs.create!( name: "age",
                   patient_id: patient.id,
                   name_original: "age",
                   date: patient.surgery_time - 1.hour,
                   value_original: patient.age_at_surgery,
                   value: patient.age_at_surgery,
                   pid: patient.pid,
                   hours_after_surgery: -1)
    end
  end

  def self.down
    remove_column :patients, :age_at_surgery, :float
    Lab.unscoped.where(name: "age").delete_all
    LabType.unscoped.where(name: "age").delete_all
  end
end
