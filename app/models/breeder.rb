class Breeder
  def initialize(options={})
    @pool = options[:pool]
    @mutation_rate = options[:mutation_rate] || 0.1
  end

  def breed!
    babies = []
    @pool.shuffle.each_slice(2) do |mother, father|
      return unless father
      baby = mate(mother, father)
      babies << baby if baby.save
    end
    babies
  end

  def mutate?
    Random.rand <= @mutation_rate
  end

end
