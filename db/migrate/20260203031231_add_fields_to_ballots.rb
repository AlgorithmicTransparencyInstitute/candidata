class AddFieldsToBallots < ActiveRecord::Migration[7.2]
  def change
    add_column :ballots, :year, :integer
    add_column :ballots, :name, :string

    add_index :ballots, :year
    add_index :ballots, [:state, :year, :election_type], unique: true
  end
end
