require 'test_helper'

class CodonTest < ActiveSupport::TestCase

  should "have references to labs" do
    codon = codons(:codon_one)
    assert_not_nil codon.value_start
    assert_not_nil codon.value_end
    assert_not_nil codon.date_start
    assert_not_nil codon.date_end
  end
end
