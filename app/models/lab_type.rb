class LabType < ApplicationRecord
  has_many :labs
  has_many :patients, through: :labs
  scope :by_number_of_patients, -> { order(number_of_patients: :desc) }
  scope :by_number_of_labs, -> { order(number_of_labs: :desc)}
  serialize :patient_cache, ActiveRecord::Coders::NestedHstore
  # serialize :infection_cache, ActiveRecord::Coders::BooleanStore
  validates_presence_of :val_max, :val_min, :hours_max, :hours_min

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
