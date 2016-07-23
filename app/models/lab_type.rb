class LabType < ApplicationRecord
  has_many :labs

  def number_of_labs
    labs.count
  end

  def number_of_patients
    labs.pluck(:patient_id).uniq.count
  end
end
