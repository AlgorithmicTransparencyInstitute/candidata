class AddBodyIdToOffices < ActiveRecord::Migration[7.2]
  def change
    add_reference :offices, :body, null: true, foreign_key: true
  end
end
