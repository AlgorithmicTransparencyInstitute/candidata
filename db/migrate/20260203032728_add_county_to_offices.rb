class AddCountyToOffices < ActiveRecord::Migration[7.2]
  def change
    add_column :offices, :county, :string
  end
end
