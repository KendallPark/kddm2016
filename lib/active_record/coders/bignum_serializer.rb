class ActiveRecord::Coders::BignumSerializer
  def self.load(string)
    string.to_i
  end
  def self.dump(num)
    num.to_s
  end
end
