class Codon < ApplicationRecord
  include Biostats
  include BitOptimizations

  belongs_to :lab_type
  validates :lab_type, presence: true
  validates_presence_of :val_start, :val_end, :hours_after_surgery
  validates_uniqueness_of :lab_type, scope: [:val_start, :val_end, :hours_after_surgery]
  default_scope -> { where(gilded: false) }
  scope :by_fitness, -> { where.not(fitness: nil).order(fitness: :desc) }
  scope :by_uniq_fitness, -> { where.not(fitness: nil).order(fitness: :desc).select('distinct on (fitness) *').to_a }
  scope :gilded, -> { unscoped.where(gilded: true) }
  scope :by_power, -> { where.not(fitness: nil).order("((true_positive + true_negative)*fitness) desc") }
  scope :top_gilded_uniq, -> { find_by_sql("SELECT * FROM ( SELECT DISTINCT ON (lab_type_id) * FROM (lab_types INNER JOIN codons ON codons.lab_type_id = lab_types.id AND lab_types.number_of_patients >= 100 AND codons.fitness >= 0.1) ORDER BY lab_type_id, fitness DESC NULLS LAST ) sub ORDER BY fitness DESC NULLS LAST, lab_type_id") }
  serialize :dx_cache, ActiveRecord::Coders::BignumSerializer

  VALID_HOURS = [0, 1.day, 1.week, 2.weeks, 1.month, 2.months, 3.months, 6.months, 1.year, 2.years, 3.years, 5.years, 10.years].map {|i| i.to_f / 3600 * -1}

  before_validation do |codon|
    codon.lab_type ||= LabType.by_number_of_patients.first

    codon.val_start ||= Random.rand((lab_type.val_min-(lab_type.val_max-lab_type.val_min)*0.25).to_f..(lab_type.val_max+(lab_type.val_max-lab_type.val_min)*0.25).to_f)
    codon.val_end ||= Random.rand((lab_type.val_min-(lab_type.val_max-lab_type.val_min)*0.25).to_f..(lab_type.val_max+(lab_type.val_max-lab_type.val_min)*0.25).to_f)

    codon.hours_after_surgery ||= VALID_HOURS.sample
  end

  after_create do |codon|
    codon.evaluate!
  end

  def self.valid_hours
    VALID_HOURS
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
    hours_after_surgery/24
  end

  def range
    "#{val_start.round(1)}-#{val_end.round(1)}"
  end

  def stats
    <<-MESSAGE
    ////////////////////////////////////////
    // #{lab_type.name} n = #{lab_type.number_of_patients}
    ////////////////////////////////////////
    ID: #{id}
    Days: #{days_after_surgery.round}
    Range: #{range}
    Sens: #{(sensitivity*100).round(1)}%
    Spec: #{(specificity*100).round(1)}%
    +LR: #{lr_pos.round(2)}
    -LR: #{lr_neg.round(2)}
    PPV: #{(ppv*100).round(1)}%
    NPV: #{(npv*100).round(1)}%
    Fit: #{fitness}

    MESSAGE
  end


  def evaluate!
    true_positive = 0
    false_positive = 0
    false_negative = 0
    true_negative = 0

    labs_earlier = Hash[lab_type.labs.where("hours_after_surgery <=?", hours_after_surgery).select(:patient_id, :hours_after_surgery, :value).group(:patient_id, :hours_after_surgery, :value).order(hours_after_surgery: :desc).distinct(:patient_id).as_json.map { |lab| [lab["patient_id"], lab] } ]
    labs_later = Hash[lab_type.labs.where("hours_after_surgery >=?", hours_after_surgery).select(:patient_id, :hours_after_surgery, :value).group(:patient_id, :hours_after_surgery, :value).order(hours_after_surgery: :asc).distinct(:patient_id).as_json.map { |lab| [lab["patient_id"], lab] } ]

    patient_dx = {}

    lab_type.patient_ids.each do |patient_id|

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

      infected = Patient.infected?(patient_id)
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
    update!(true_positive: true_positive, true_negative: true_negative, false_positive: false_positive, false_negative: false_negative, dx_cache: self.class.cache_hash_of_ids(patient_dx).to_s)
  end

  def dx_pos
    dx_cache
  end

  def dx_neg
    dx_cache^lab_type.patient_cache
  end

  def fitness!
    evaluate! unless true_positive && true_negative && false_positive && false_negative
    fitness = yield(true_positive, true_negative, false_positive, false_negative, sensitivity, specificity, ppv, npv, lr_pos, lr_neg)
    update!(fitness: fitness)
    fitness
  end

end
