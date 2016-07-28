class AddNewStuffToCodons < ActiveRecord::Migration[5.0]
  def self.up
    add_column :codons, :hours_after_surgery, :decimal
    add_column :codons, :val_start, :decimal
    add_column :codons, :val_end, :decimal

    Codon.find_in_batches(batch_size: 100) do |codons|
      Codon.transaction do
        codons.each do |codon|
          lab_type = codon.lab_type
          codon.val_start = Lab.find(codon.value_start_id).value
          codon.val_end = Lab.find(codon.value_end_id).value
          codon.hours_after_surgery = Lab.find(codon.date_end_id).hours_after_surgery
          codon.delete unless codon.save
        end
      end
    end

    change_column_null :codons, :hours_after_surgery, false
    change_column_null :codons, :val_start, false
    change_column_null :codons, :val_end, false
  end

  def self.down
    remove_column :codons, :hours_after_surgery
    remove_column :codons, :val_start
    remove_column :codons, :val_end
  end
end
