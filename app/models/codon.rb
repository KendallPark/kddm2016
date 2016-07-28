class Codon < ApplicationRecord
  belongs_to :lab_type
  validates :lab_type, presence: true
  validates_presence_of :val_start, :val_end, :hours_after_surgery
  validates_uniqueness_of :lab_type, scope: [:val_start, :val_end, :hours_after_surgery]
  scope :by_fitness, -> { where.not(fitness: nil).order(fitness: :desc)}
  serialize :dx_cache, ActiveRecord::Coders::BignumSerializer

  before_validation do |codon|
    codon.lab_type ||= LabType.by_number_of_patients.first

    codon.val_start ||= Random.rand(lab_type.val_min..lab_type.val_max)
    codon.val_end ||= Random.rand(lab_type.val_min..lab_type.val_max)

    codon.hours_after_surgery ||= Random.rand(lab_type.hours_min..lab_type.hours_max)
  end

  after_create do |codon|
    codon.evaluate!
  end

  def self.purge_invalid!
    all.each { |c| c.destroy if c.invalid? }
  end

  def start_value
    val_start
  end

  def end_value
    val_end
  end

  def days_after_surgery
    hours_after_surgery/60
  end

  def range
    "#{val_start}-#{val_end}"
  end

  def sensitivity
    return 0 if (true_positive + false_negative) == 0
    true_positive.to_f / (true_positive + false_negative)
  end

  def specificity
    return 0 if (true_negative + false_positive) == 0
    true_negative.to_f / (true_negative + false_positive)
  end

  def ppv
    return 0 if (true_positive + false_positive) == 0
    true_positive.to_f/(true_positive + false_positive)
  end

  def npv
    return 0 if (true_negative + false_negative) == 0
    true_negative.to_f/(true_negative + false_negative)
  end

  def lr_pos
    return 0 if (1.0-specificity) == 0
    sensitivity/(1.0-specificity)
  end

  def lr_neg
    return 0 if specificity == 0
    (1.0-sensitivity)/specificity
  end

  def evaluate!
    true_positive = 0
    false_positive = 0
    false_negative = 0
    true_negative = 0

    labs_earlier = Hash[lab_type.labs.where("hours_after_surgery <=?", hours_after_surgery).select(:patient_id, :hours_after_surgery, :value).group(:patient_id, :hours_after_surgery, :value).order(hours_after_surgery: :desc).distinct(:patient_id).as_json.map { |lab| [lab["patient_id"], lab] } ]
    labs_later = Hash[lab_type.labs.where("hours_after_surgery >=?", hours_after_surgery).select(:patient_id, :hours_after_surgery, :value).group(:patient_id, :hours_after_surgery, :value).order(hours_after_surgery: :asc).distinct(:patient_id).as_json.map { |lab| [lab["patient_id"], lab] } ]

    patient_dx = {}

    lab_type.patient_cache.each do |patient_id_s, labs_by_id|
      patient_id = patient_id_s.to_i

      lab_earlier = labs_earlier[patient_id]
      lab_later = labs_later[patient_id]

      if lab_later && lab_earlier
        value = (hours_after_surgery - lab_later['hours_after_surgery']).abs < (hours_after_surgery - lab_earlier['hours_after_surgery']).abs ? lab_later['value'] : lab_earlier['value']
      elsif lab_later
        value = lab_later['value']
      elsif lab_earlier
        value = lab_earlier['value']
      end

      next unless value

      infected = lab_type.infected?(patient_id)
      # if the start is less than the we evalute inclusively
      if val_start <= val_end && value >= val_start && value <= val_end
        dx = true
      elsif val_start > val_end && (value < val_start || value > val_end)
        dx = true
      else
        dx = false
      end

      patient_dx[patient_id] = dx

      if(dx == true && infected == true)
        true_positive += 1
      elsif(dx == true && infected == false)
        false_positive += 1
      elsif(dx == false && infected == true)
        false_negative += 1
      elsif(dx == false && infected == false)
        true_negative +=1
      end

    end
    update!(true_positive: true_positive, true_negative: true_negative, false_positive: false_positive, false_negative: false_negative, dx_cache: LabType.cache(patient_dx))
  end

  def fitness!
    evaluate! unless true_positive && true_negative && false_positive && false_negative
    fitness = yield(true_positive, true_negative, false_positive, false_negative, sensitivity, specificity, ppv, npv, lr_pos, lr_neg)
    update!(fitness: fitness)
    fitness
  end

end
