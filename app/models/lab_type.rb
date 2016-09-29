class LabType < ApplicationRecord
  include BitOptimizations
  has_many :labs
  has_many :patients, through: :labs
  has_many :codons
  scope :by_number_of_patients, -> { order(number_of_patients: :desc) }
  scope :by_number_of_labs, -> { order(number_of_labs: :desc)}
  scope :useful, -> { where("number_of_patients >= ?", 10).by_number_of_patients }
  validates_presence_of :val_max, :val_min, :hours_max, :hours_min
  validates_presence_of :patient_cache
  serialize :patient_cache, ActiveRecord::Coders::BignumSerializer

  def update_min_max!
    changes = {
      val_min: labs.minimum(:value) || 0,
      val_max: labs.maximum(:value) || 0,
      hours_min: labs.minimum(:hours_after_surgery) || 0,
      hours_max: labs.maximum(:hours_after_surgery) || 0,
    }
    update!(changes)
  end

  def update_everything!
    changes = {
      val_min: labs.minimum(:value) || 0,
      val_max: labs.maximum(:value) || 0,
      hours_min: labs.minimum(:hours_after_surgery) || 0,
      hours_max: labs.maximum(:hours_after_surgery) || 0,
      number_of_labs: labs.count,
      number_of_patients: labs.pluck(:patient_id).uniq.count,
      patient_cache: cache_patients.to_s
    }
    update(changes)
  end

  def val_min!
    update!(val_min: labs.minimum(:value) || 0)
    val_min
  end

  def val_max!
    update!(val_max: labs.maximum(:value) || 0)
    val_max
  end

  def hours_min!
    update!(hours_min: labs.minimum(:hours_after_surgery) || 0)
    hours_min
  end

  def hours_max!
    update!(hours_max: labs.maximum(:hours_after_surgery) || 0)
    hours_max
  end

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

  def patient_ids
    patients.pluck(:id).uniq
  end

  def cache_patients
    cache_array_of_ids(patient_ids)
  end

end
