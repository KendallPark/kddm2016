class Gene < ApplicationRecord
  include Biostats
  include BitOptimizations

  has_and_belongs_to_many :codons
  serialize :sequence, ActiveRecord::Coders::NestedHstore
  serialize :dx_cache, ActiveRecord::Coders::BignumSerializer

  default_scope -> { where(gilded: false, family: nil) }
  scope :by_fitness, -> { where.not(fitness: nil).order(fitness: :desc) }
  scope :by_uniq_fitness, -> { where.not(fitness: nil).order(fitness: :desc, size: :asc).select('distinct on (fitness) *').to_a }
  # scope :by_uniq_sig, -> { find_by_sql("SELECT * FROM ( SELECT DISTINCT ON (signature) * FROM genes WHERE (signature IS NOT NULL) ORDER BY signature DESC, fitness DESC, size ASC NULLS LAST ) sub ORDER BY fitness DESC, size ASC NULLS LAST, signature") }

  scope :by_sensitivity, -> { where.not(fitness: nil).order("true_positive / (true_positive + false_negative)") }
  scope :by_specificity, -> { where.not(fitness: nil).order("true_negative / (true_negative + false_positive)") }
  scope :sizes, -> { where.not(size: nil).order(:size).group(:size).distinct.pluck(:size) }

  THRESHOLD = 1
  VALID_STRATS = ["snapshot", "ever_in_range", "percent_labs_in_range", "crosses_into_range", "is_male", "is_female", "within_days"]

  attr_accessor :codon_mutations, :weight_mutations, :starting_codon, :starting_strat

  before_validation do |gene|
    create_gene(gene)
  end

  after_create do |gene|
    gene.evaluate!
  end

  def self.by_uniq_sig(size=nil)
    if size
      find_by_sql("SELECT * FROM ( SELECT DISTINCT ON (signature) * FROM genes WHERE (signature IS NOT NULL AND fitness IS NOT NULL AND size = #{size}) ORDER BY signature DESC, fitness DESC, size ASC NULLS LAST ) sub ORDER BY fitness DESC, size ASC NULLS LAST, signature")
    else
      find_by_sql("SELECT * FROM ( SELECT DISTINCT ON (signature) * FROM genes WHERE (signature IS NOT NULL AND fitness IS NOT NULL) ORDER BY signature DESC, fitness DESC, size ASC NULLS LAST ) sub ORDER BY fitness DESC, size ASC NULLS LAST, signature")
    end
  end

  def create_gene(gene)
    gene.codon_mutations ||= []
    gene.weight_mutations ||= []
    if gene.sequence
      gene.weight_mutations.each do |lab_type_id|
        gene.sequence[lab_type_id]["weight"] = random_weight(gene.sequence.keys.count, gene.sequence[lab_type_id]["weight"])
      end
      gene.codon_mutations.each do |lab_type_id|
        codon_id = gene.sequence[lab_type_id]["codon_id"]
        new_codon = gene.mutate_codon(codon_id)
        gene.sequence[lab_type_id] = codon_cache(new_codon.reload).merge(weight: gene.sequence[lab_type_id]["weight"])
      end
    else
      top_codons = Codon.top_gilded_uniq
      count = top_codons.length
      new_sequence = {}
      Codon.top_gilded_uniq.each do |codon|
        new_sequence[codon.lab_type_id] = codon_cache(codon).merge(weight: random_weight(count))
      end
      gene.sequence = new_sequence
    end
  end

  def mutate_codon(codon_id)
    old_codon = Codon.unscoped.find(codon_id)
    new_codon = old_codon.dup
    randomized_value = [:val_start, :val_end, :hours_after_surgery].sample
    new_codon[randomized_value] = nil
    new_codon.threshold = nil
    unless new_codon.save
      new_codon = Codon.unscoped.find_by(val_start: new_codon.val_start, val_end: new_codon.val_end, hours_after_surgery: new_codon.hours_after_surgery)
    end
    new_codon
  end

  def recache_codons!
    new_sequence = {}
    sequence.each do |lab_type_id, cached_codon|
      codon = Codon.unscoped.find(cached_codon["codon_id"])
      new_sequence[lab_type_id] = codon_cache(codon).merge(weight: cached_codon["weight"])
    end
    update!(sequence: new_sequence)
  end

  def codon_cache(codon)
    if codon.within_days_cache == 0
      print "!"
      codon.evaluate!
      codon.reload
    end
    {
      lab_type_id: codon.lab_type_id,
      lab_name: codon.lab_type.name,
      codon_id: codon.id,
      range: codon.range,
      days_after_surgery: codon.days_after_surgery,
      dx_pos: codon.dx_pos,
      ever_cache: codon.ever_cache,
      crossing_cache: codon.crossing_cache,
      within_days_cache: codon.within_days_cache,
      ratio_cache: codon.ratio_cache,
      threshold: codon.threshold,
    }.with_indifferent_access
  end

  def random_weight(size, initial=nil)
    fraction = 1.0/size
    initial ||= 0
    # initial + Random.rand(-THRESHOLD.to_f..THRESHOLD.to_f)
    Random.rand(-1.0..1)
    [0, 0, 0, 0, 0, 1, 2, 3, 4, 5, -1, -2, -3, -4, -5].sample
  end

  def evaluate!
    true_positive = 0
    true_negative = 0
    false_positive = 0
    false_negative = 0

    patient_dx = {}

    Patient.patient_ids.each do |pid|
      sum = 0
      sequence.each do |lab_type_id, codon|
        sum += codon["weight"] * self.class.nth_bit(codon["dx_pos"], pid) if codon["weight"] > 0
        sum -= codon["weight"] * self.class.nth_bit(codon["dx_neg"], pid) if codon["weight"] < 0
      end
      dx = sum.to_f/5 >= THRESHOLD
      patient_dx[pid] = dx
      infected = Patient.infected?(pid)

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

  def fitness!
    evaluate! unless true_positive && true_negative && false_positive && false_negative
    fitness = yield(true_positive, true_negative, false_positive, false_negative, sensitivity, specificity, ppv, npv, lr_pos, lr_neg, accuracy, size)
    if fitness == :destroy
      destroy!
      return
    end
    update!(fitness: fitness)
    fitness
  end

  def lab_types_sorted_by_weight
    sequence.values.sort_by { |lab_type| lab_type["weight"] }.reverse
  end

  def stats
    message = <<-MESSAGE
    ////////////////////////////////////////
    // GENE #{id}
    ////////////////////////////////////////
    ID: #{id}
    Sens: #{(sensitivity*100).round(1)}%
    Spec: #{(specificity*100).round(1)}%
    +LR: #{lr_pos.round(2)}
    -LR: #{lr_neg.round(2)}
    PPV: #{(ppv*100).round(1)}%
    NPV: #{(npv*100).round(1)}%
    Correct: #{true_positive + true_negative}
    Incorrect: #{false_positive + false_negative}
    Accuracy: #{(accuracy*100).round(1)}%

    MESSAGE

    table = Terminal::Table.new do |t|
      t.add_row ["Lab Name", "Weight", "Range", "Days Before Surgery"]
      t.add_separator
      lab_types_sorted_by_weight.each do |lab_type|
        t.add_row [lab_type['lab_name'], lab_type["weight"].round(2), lab_type["range"], (lab_type["days_after_surgery"].to_f * -1).round(0)]
      end
    end
    message << table.to_s

    message << "\n"
    message
  end

  def gild!
    update!(gilded: true)
  end

end
