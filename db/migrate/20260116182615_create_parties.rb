class CreateParties < ActiveRecord::Migration[7.2]
  def change
    create_table :parties do |t|
      t.string :name, null: false
      t.string :abbreviation, null: false
      t.string :ideology

      t.timestamps
    end
    
    add_index :parties, :name, unique: true
    add_index :parties, :abbreviation, unique: true
  end
end
