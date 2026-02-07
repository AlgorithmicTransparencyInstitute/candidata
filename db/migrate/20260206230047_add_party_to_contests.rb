class AddPartyToContests < ActiveRecord::Migration[8.0]
  def change
    add_column :contests, :party, :string
  end
end
