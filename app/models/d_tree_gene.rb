require 'csv'
class DTreeGene < TreeGene

  def create_gene(gene)
    gene.codon_mutations ||= []
    if gene.sequence
      gene.tree_traverse! do |node|
        if node["codon_id"] && gene.codon_mutations.include?(node["codon_id"])
          if [true, true, true, false].sample
            new_codon = mutate_codon(node["codon_id"])
            node.merge!(codon_cache(new_codon))
          else
            strat = VALID_STRATS.sample
            # strat = ["within_days"].sample
            node.merge!(strat: VALID_STRATS.sample)
          end
        end
      end
    elsif gene.starting_codon
      gene.sequence = {
        tree: codon_cache(gene.starting_codon).merge(strat: VALID_STRATS.sample, true: {assessment: true}, false: {assessment: false}),
      }.with_indifferent_access
    else
      gene.sequence = {
        tree: codon_cache(random_codon).merge(strat: VALID_STRATS.sample, true: {assessment: true}, false: {assessment: false}),
      }.with_indifferent_access
    end
    gene.size = gene.gene_size
    gene.signature = generate_signature
  end

  def dx_test
    recache_codons!
    evaluate!
    patient_dx = {}
    Patient.patient_ids.each do |pid|
      next if Patient.has_assessment?(pid)
      dx = self.class.true_bit?(dx_cache, pid) ? 1 : 0
      patient_dx[Patient.find(pid).pid] = dx
    end
    rows = []
    patient_data_path = Rails.root.join("data", "private", "WoundInf_Eval_noLabel.csv")
    patient_csv = CSV.open(patient_data_path, headers: true, converters: [:numeric, :date_time])
    patient_csv.each do |patient_row|
      patient_hash = patient_row.to_h
      binding.pry unless patient_dx[patient_hash["PID"]]
      rows << [patient_hash["PID"], patient_dx[patient_hash["PID"]]]
    end
    path = Rails.root.join("data", "private", "results.csv")
    CSV.open(path, "w") do |csv|
      rows.each do |row|
        csv << row
      end
    end
    patient_dx
  end

  def recache_codons!
    tree_traverse! do |node|
      if node["codon_id"]
        codon = Codon.find(node["codon_id"])
        codon.evaluate!
        node.merge!(codon_cache(codon.reload))
      end
    end
  end

  def generate_signature
    sig = ""
    tree_traverse! do |node, depth|
      sig << "#{depth}: #{node["lab_name"]} (#{node["strat"]})  " if node["lab_name"]
    end
    sig
  end

  def signature!
    update!(signature: generate_signature)
  end

  def traverse!(node, depth=0)
    yield node, depth
    traverse!(node["true"], depth+1) {|n| yield n } if node["true"]
    traverse!(node["false"], depth+1) {|n| yield n } if node["false"]
  end

  def evaluate!
    true_positive = 0
    true_negative = 0
    false_positive = 0
    false_negative = 0

    patient_dx = {}

    Patient.patient_ids.each do |pid|
      dx = evaluate_node(tree, pid)
      patient_dx[pid] = dx
      next unless Patient.has_assessment?(pid)
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

  def tree_string
    message = ""
    tree_traverse! do |node|
      next unless node["lab_name"]
      message << "#{node["lab_name"]} (#{node["strat"]}): #{node["range"]}  "
    end
    message
  end

  def decision_tree
    recurse_decision_tree(tree)
  end

  def recurse_decision_tree(node)
    return node["assessment"] if !node["true"]
    hash = {
      lab_name: node["lab_name"],
      strat: node["strat"],
      range: node["range"],
      days_after_surgery: node["days_after_surgery"],
      threshold: node["threshold"],
    }
    hash["true"] = recurse_decision_tree(node["true"])
    hash["false"] = recurse_decision_tree(node["false"])
    return hash
  end

  def evaluate_node(node, pid)
    return node["assessment"] if !node["true"]
    strat = case node["strat"]
    when "ever_in_range"
      node["ever_cache"]
    when "percent_labs_in_range"
      node["ratio_cache"]
    when "crosses_into_range"
      node["crossing_cache"]
    when "snapshot"
      node["dx_pos"]
    when "within_days"
      node["within_days_cache"]
    when "is_male"
      Patient.male_cache
    when "is_female"
      Patient.female_cache
    end
    yes = self.class.nth_bit(strat, pid) == 1
    if yes
      evaluate_node(node["true"], pid)
    else
      evaluate_node(node["false"], pid)
    end
  end

end
