class AddPersonUuidToTempAccounts < ActiveRecord::Migration[8.0]
  def change
    add_column :temp_accounts, :person_uuid, :string
  end
end
