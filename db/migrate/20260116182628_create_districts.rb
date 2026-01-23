class CreateDistricts < ActiveRecord::Migration[7.2]
  def change
    create_table :districts do |t|
      t.string :state, null: false
      t.integer :district_number
      t.string :level, null: false
      t.text :boundaries

      t.timestamps
    end
    
    add_index :districts, [:state, :district_number, :level], unique: true, name: 'index_districts_unique'
    add_index :districts, :state
  end
end
