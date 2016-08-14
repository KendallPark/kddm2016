class Gene < ApplicationRecord
  include Biostats
  include BitOptimizations

  has_and_belongs_to_many :codons
  serialize :sequence, ActiveRecord::Coders::NestedHstore

  default_scope -> { where(gilded: false) }
  scope :by_fitness, -> { where.not(fitness: nil).order(fitness: :desc) }
  scope :by_uniq_fitness, -> { where.not(fitness: nil).order(fitness: :desc).select('distinct on (fitness) *').to_a }


  THRESHOLD = 1

  attr_accessor :codon_mutations, :weight_mutations

  before_validation do |gene|
    gene.codon_mutations ||= []
    gene.weight_mutations ||= []
    if gene.sequence
      gene.weight_mutations.each do |lab_type_id|
        gene.sequence[lab_type_id]["weight"] = random_weight(gene.sequence.keys.count, gene.sequence[lab_type_id]["weight"])
      end
      gene.codon_mutations.each do |lab_type_id|
        codon_id = gene.sequence[lab_type_id]["codon_id"]
        old_codon = Codon.unscoped.find(codon_id)
        new_codon = old_codon.dup
        randomized_value = [:val_start, :val_end, :hours_after_surgery].sample
        new_codon[randomized_value] = nil
        unless new_codon.save
          new_codon = Codon.unscoped.find_by(val_start: new_codon.val_start, val_end: new_codon.val_end, hours_after_surgery: new_codon.hours_after_surgery)
        end
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

  after_create do |gene|
    gene.evaluate!
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
    {
      lab_type_id: codon.lab_type_id,
      lab_name: codon.lab_type.name,
      codon_id: codon.id,
      dx_pos: codon.dx_pos,
      dx_neg: codon.dx_neg,
      range: codon.range,
      days_after_surgery: codon.days_after_surgery,
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
    fitness = yield(true_positive, true_negative, false_positive, false_negative, sensitivity, specificity, ppv, npv, lr_pos, lr_neg, accuracy)
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

end
