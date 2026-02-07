class AddIndexToTempAccountsPersonUuid < ActiveRecord::Migration[8.0]
  def change
    add_index :temp_accounts, :person_uuid
  end
end
