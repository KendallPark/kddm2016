class ActiveRecord::Coders::BooleanStore
  def self.load(value)
    hash = value
    hash.each { |k, v| hash[k] = value == "true" }
    hash
  end

  def self.dump(value)
    value
  end
end
