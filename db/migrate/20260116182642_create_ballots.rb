class CreateBallots < ActiveRecord::Migration[7.2]
  def change
    create_table :ballots do |t|
      t.string :state, null: false
      t.date :date, null: false
      t.string :election_type, null: false

      t.timestamps
    end
    
    add_index :ballots, [:state, :date, :election_type], unique: true, name: 'index_ballots_unique'
    add_index :ballots, :date
  end
end
