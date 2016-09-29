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
  scope :top_gilded_uniq, -> { find_by_sql("SELECT * FROM ( SELECT DISTINCT ON (lab_type_id) * FROM (lab_types INNER JOIN codons ON codons.lab_type_id = lab_types.id AND lab_types.number_of_patients >= 10 AND codons.fitness >= 0.1) ORDER BY lab_type_id, fitness DESC NULLS LAST ) sub ORDER BY fitness DESC NULLS LAST, lab_type_id") }
  serialize :dx_cache, ActiveRecord::Coders::BignumSerializer
  serialize :ratio_cache, ActiveRecord::Coders::BignumSerializer
  serialize :ever_cache, ActiveRecord::Coders::BignumSerializer
  serialize :crossing_cache, ActiveRecord::Coders::BignumSerializer
  serialize :within_days_cache, ActiveRecord::Coders::BignumSerializer

  VALID_HOURS = [0, 1.day, 1.week, 2.weeks, 1.month, 2.months, 3.months, 6.months, 1.year, 2.years, 3.years, 5.years, 10.years].map {|i| i.to_f / 3600 * -1}

  before_validation do |codon|
    codon.lab_type ||= LabType.by_number_of_patients.first

    codon.val_start ||= Random.rand((lab_type.val_min-(lab_type.val_max-lab_type.val_min)*0.25).to_f..(lab_type.val_max+(lab_type.val_max-lab_type.val_min)*0.25).to_f)
    codon.val_end ||= Random.rand((lab_type.val_min-(lab_type.val_max-lab_type.val_min)*0.25).to_f..(lab_type.val_max+(lab_type.val_max-lab_type.val_min)*0.25).to_f)

    codon.hours_after_surgery ||= VALID_HOURS.sample

    codon.threshold ||= Random.rand
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
    labs_now = Hash[lab_type.labs.where("hours_after_surgery <=?", 0).select(:patient_id, :hours_after_surgery, :value).group(:patient_id, :hours_after_surgery, :value).order(hours_after_surgery: :asc).distinct(:patient_id).as_json.map { |lab| [lab["patient_id"], lab] } ]

    # labs within hours_after_surgery that are in range
    labs_within_days = lab_type.labs.where("hours_after_surgery >= ?", hours_after_surgery).where("value >= ?", val_start).where("value <= ?", val_end).group(:patient_id).count

    # labs in range
    labs_in_range = lab_type.labs.where("value >= ?", val_start).where("value <= ?", val_end).group(:patient_id).count
    total_labs = lab_type.labs.group(:patient_id).count

    patient_dx = {}
    ever_dx = {}
    ratio_dx = {}
    crossing_dx = {}
    within_days_dx = {}

    lab_type.patient_ids.each do |patient_id|
      if Patient.has_assessment?(patient_id)
        infected = Patient.infected?(patient_id)
      else
        infected = nil
      end

      patient_labs_in_range = labs_in_range[patient_id] || 0
      patient_total_labs = total_labs[patient_id] || 0

      within_days_dx[patient_id] = labs_within_days[patient_id] ? true : false

      percent_labs_in_range = 0
      percent_labs_in_range = patient_labs_in_range.to_f/patient_total_labs if patient_total_labs > 0
      patient_in_threshold = percent_labs_in_range >= threshold
      ratio_dx[patient_id] = patient_in_threshold

      patient_ever_lab_in_range = patient_labs_in_range > 0
      ever_dx[patient_id] = patient_ever_lab_in_range

      lab_earlier = labs_earlier[patient_id]
      lab_later = labs_later[patient_id]
      lab_now = labs_now[patient_id]

      if lab_later && lab_earlier
        value = (hours_after_surgery - lab_later['hours_after_surgery']).abs < (hours_after_surgery - lab_earlier['hours_after_surgery']).abs ? lab_later['value'] : lab_earlier['value']
      elsif lab_later
        value = lab_later['value']
      elsif lab_earlier
        value = lab_earlier['value']
      end

      next unless value

      now_value = earlier_value = lab_now['value']
      earlier_value = lab_earlier['value'] if lab_earlier
      if (now_value >= val_start && now_value <= val_end) && (earlier_value < val_start || earlier_value > val_end)
        crossing_dx[patient_id] = true
      else
        crossing_dx[patient_id] = false
      end

      # if the start is less than the we evalute inclusively
      if val_start <= val_end && value >= val_start && value <= val_end
        dx = true
      elsif val_start > val_end && (value < val_start || value > val_end)
        dx = true
      else
        dx = false
      end

      patient_dx[patient_id] = dx

      if infected != nil
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

    end
    update!(true_positive: true_positive,
            true_negative: true_negative,
            false_positive: false_positive,
            false_negative: false_negative,
            dx_cache: self.class.cache_hash_of_ids(patient_dx).to_s,
            ever_cache: self.class.cache_hash_of_ids(ever_dx).to_s,
            crossing_cache: self.class.cache_hash_of_ids(crossing_dx).to_s,
            ratio_cache: self.class.cache_hash_of_ids(ratio_dx).to_s,
            within_days_cache: self.class.cache_hash_of_ids(within_days_dx).to_s)
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
