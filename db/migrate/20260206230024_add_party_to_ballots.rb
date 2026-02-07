class AddPartyToBallots < ActiveRecord::Migration[8.0]
  def change
    add_column :ballots, :party, :string
  end
end
