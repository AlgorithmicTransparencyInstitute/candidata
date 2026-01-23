class CreateCandidates < ActiveRecord::Migration[7.2]
  def change
    create_table :candidates do |t|
      t.references :person, null: false, foreign_key: true
      t.references :contest, null: false, foreign_key: true
      t.string :outcome, null: false
      t.integer :tally, default: 0

      t.timestamps
    end
    
    add_index :candidates, [:person_id, :contest_id], unique: true, name: 'index_candidates_unique'
    add_index :candidates, :outcome
  end
end
