class CreatePeople < ActiveRecord::Migration[7.2]
  def change
    create_table :people do |t|
      t.string :first_name, null: false
      t.string :last_name, null: false
      t.references :party_affiliation, foreign_key: { to_table: :parties }
      t.date :birth_date
      t.date :death_date
      t.string :state_of_residence

      t.timestamps
    end
    
    add_index :people, [:first_name, :last_name]
    add_index :people, :state_of_residence
  end
end
