class LabType < ApplicationRecord
  has_many :labs

  def number_of_labs!
    number_of_labs = labs.count
    update(number_of_labs: number_of_labs)
    number_of_labs
  end

  def number_of_patients!
    number_of_patients = labs.pluck(:patient_id).uniq.count
    update(number_of_patients: number_of_patients)
    number_of_patients
  end
end
