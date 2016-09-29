class TreeGene < Gene

  OPERATORS = ["and", "or", "and not", "or not"]

  def create_gene(gene)
    gene.codon_mutations ||= []
    if gene.sequence
      gene.tree_traverse! do |node|
        if node["codon_id"] && gene.codon_mutations.include?(node["codon_id"])
          new_codon = mutate_codon(node["codon_id"])
          node.merge!(codon_cache(new_codon))
        end
      end
      gene.size = gene.gene_size
    else
      gene.sequence = {
        tree: {
          type: OPERATORS.sample,
          child_1: codon_cache(random_codon),
          child_2: codon_cache(random_codon),
        }
      }
      gene.size = gene.gene_size
    end
  end

  def tree
    sequence["tree"]
  end

  def gene_size
    size = 0
    tree_traverse! do
      size += 1
    end
    size
  end

  def tree_traverse!
    traverse!(tree) { |node, depth| yield node, depth }
  end

  def traverse!(node)
    yield node
    return unless node["type"]
    traverse!(node["child_1"]) {|n| yield n }
    traverse!(node["child_2"]) {|n| yield n }
  end

  def random_codon
    lab_type_id = LabType.useful.select(:id).sample.id
    new_codon = Codon.new(lab_type_id: lab_type_id)
    unless new_codon.save
      new_codon = Codon.unscoped.find_by(val_start: new_codon.val_start, val_end: new_codon.val_end, hours_after_surgery: new_codon.hours_after_surgery)
    end
    new_codon
  end

  def evaluate!
    dx_cache = evaluate_node(tree)
    assessment = Patient.assess_dx(dx_cache)
    update!(assessment.merge(dx_cache: dx_cache))
  end

  def evaluate_node(node)
    if !node["type"]
      node["dx_pos"]
    elsif node["type"] == "and"
      evaluate_node(node["child_1"]) & evaluate_node(node["child_2"])
    elsif node["type"] == "or"
      evaluate_node(node["child_1"]) | evaluate_node(node["child_2"])
    elsif node["type"] == "and not"
      evaluate_node(node["child_1"]) & Patient.all_cache^evaluate_node(node["child_2"])
    elsif node["type"] == "or not"
      evaluate_node(node["child_1"]) | Patient.all_cache^evaluate_node(node["child_2"])
    end
  end

  def self.operators
    OPERATORS
  end

  def tree_string_rec(node)
    if !node["type"]
      "#{node["lab_name"]}: #{node["range"]}"
    elsif node["type"]
      "(#{tree_string_rec(node['child_1'])} #{node['type']} #{tree_string_rec(node["child_2"])})"
    end
  end

  def tree_string
    tree_string_rec(tree)
  end

  def stats
    message = <<-MESSAGE
    ////////////////////////////////////////
    // GENE #{id} #{tree_string}
    ////////////////////////////////////////
    ID: #{id}
    Created: #{created_at}
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

    message << decision_tree.ai+"\n"

    message
  end
end
