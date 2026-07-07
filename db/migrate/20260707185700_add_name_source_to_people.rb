class AddNameSourceToPeople < ActiveRecord::Migration[8.0]
  def change
    add_column :people, :name_source, :string
  end
end
