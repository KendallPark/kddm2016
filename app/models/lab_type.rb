class LabType < ApplicationRecord
  has_many :labs
  has_many :patients, through: :labs
  has_many :codons
  scope :by_number_of_patients, -> { order(number_of_patients: :desc) }
  scope :by_number_of_labs, -> { order(number_of_labs: :desc)}
  validates_presence_of :val_max, :val_min, :hours_max, :hours_min
  validates_presence_of :infect_cache
  serialize :patient_cache, ActiveRecord::Coders::NestedHstore
  serialize :infect_cache, ActiveRecord::Coders::BignumSerializer

  def update_min_max!
    val_min!
    val_max!
    hours_min!
    hours_max!
  end

  def val_min!
    update!(val_min: labs.minimum(:value))
    val_min
  end

  def val_max!
    update!(val_max: labs.maximum(:value))
    val_max
  end

  def hours_min!
    update!(hours_min: labs.minimum(:hours_after_surgery))
    hours_min
  end

  def hours_max!
    update!(hours_max: labs.maximum(:hours_after_surgery))
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

  def cache_patients!
    labs_by_patient = {}
    labs_by_id = Hash[labs.select(:id, :patient_id, :value, :hours_after_surgery).as_json.map { |lab| [lab["id"], lab] }]
    labs_by_id.each do |lab_id, lab|
      lab["value"] = lab["value"].to_f
      lab["hours_after_surgery"] = lab["hours_after_surgery"].to_f
      labs_by_patient[lab["patient_id"]] = {} unless labs_by_patient[lab["patient_id"]]
      labs_by_patient[lab["patient_id"]][lab_id] = lab
    end
    update!(patient_cache: labs_by_patient)
  end

  def self.cache(dx_by_id)
    # convert string keys and values to ints if not already strings
    dx_by_id = Hash[dx_by_id.to_a.map{|a| [a.first.to_i, a.last == true || a.last == "true"]}]
    temp = 0
    dx_by_id.keys.sort.each do |key|
      dx = dx_by_id[key]
      temp <<= 1
      temp |= 1 if dx
    end
    temp
  end

  def cache_infection!
    infection_by_patient = Hash[patients.select(:id, :infection).as_json.map { |patient| [patient["id"], patient["infection"]]}]
    update!(infection_cache: infection_by_patient)
  end

  def infected?(patient_id)
    infection_cache[patient_id.to_s] == 'true'
  end

  def patient_labs(patient_id)
    patient_cache[patient_id.to_s]
  end

end
