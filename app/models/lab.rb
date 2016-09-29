class Lab < ApplicationRecord
  belongs_to :patient
  belongs_to :lab_type
  has_many :codons, foreign_key: :value_start_id
  has_many :codons, foreign_key: :value_end_id
  has_many :codons, foreign_key: :date_start_id
  has_many :codons, foreign_key: :date_end_id
  validates_numericality_of :value
  validates_presence_of :patient, scope: :unscoped
  validates_presence_of :date, :name_original, :name, :value, :value_original, :pid
  validates_uniqueness_of :pid, scope: [:date, :name_original, :name, :value, :value_original]

  default_scope -> { where(outlier: false).where("hours_after_surgery < ?", 0) }
  scope :by_date, -> { order(date: :asc) }
  scope :by_value, -> { order(value: :asc) }
  scope :by_hours, -> { order(hours_after_surgery: :asc)}
  scope :test_data, -> { where(outlier: false, test_data: true).where("hours_after_surgery < ?", 0) }
  # scope :all_data, -> { unscoped.where(outlier: false).where("hours_after_surgery < ?", 0) }

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
