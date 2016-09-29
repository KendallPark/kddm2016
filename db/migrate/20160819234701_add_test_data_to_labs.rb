class AddTestDataToLabs < ActiveRecord::Migration[5.0]
  def change
    add_column :labs, :test_data, :boolean, default: false
  end
end
