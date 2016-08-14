module Biostats
  extend ActiveSupport::Concern

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

  def accuracy
    return 0 if (true_positive + true_negative + false_positive + false_negative) == 0
    ((true_positive + true_negative).to_f/(true_positive + true_negative + false_positive + false_negative).to_f)
  end

end
