class CreateStates < ActiveRecord::Migration[7.2]
  def change
    create_table :states do |t|
      t.string :name, null: false
      t.string :abbreviation, null: false
      t.string :fips_code
      t.string :state_type, default: 'state'

      t.timestamps
    end
    add_index :states, :abbreviation, unique: true
    add_index :states, :name, unique: true
    add_index :states, :fips_code, unique: true
  end
end
