class Lab < ApplicationRecord
  belongs_to :patient
  validates_numericality_of :value
  validates_presence_of :patient, :date, :name_original, :name, :value, :value_original, :pid

  def self.test_names
    self.pluck(:name).uniq
  end

  def self.number_of_labs
    Lab.group(:name).distinct.count
  end

  def self.number_of_patients_with_labs
    Lab.group(:name).distinct.count(:patient_id)
  end
end
