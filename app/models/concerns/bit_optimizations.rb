module BitOptimizations
  extend ActiveSupport::Concern

  module ClassMethods
    def cache_hash_of_ids(dx_by_pid)
      temp = 0
      dx_by_pid.each do |pid, value|
        dx = value
        temp |= (1 << (pid-1)) if dx
      end
      temp
    end

    def cache_array_of_ids(id_array)
      temp = 0
      id_array.each do |pid|
        temp |= (1 << (pid-1))
      end
      temp
    end

    def true_bit?(bits, index)
      ((bits >> (index - 1)) & 1) == 1
    end

    def nth_bit(bits, index)
      (bits >> (index - 1)) & 1
    end
  end

end
