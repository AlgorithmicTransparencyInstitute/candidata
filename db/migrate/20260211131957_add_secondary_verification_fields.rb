class AddSecondaryVerificationFields < ActiveRecord::Migration[8.0]
  def change
    # Add fields to social_media_accounts to track modifications during validation
    add_column :social_media_accounts, :modified_during_validation, :boolean, default: false, null: false
    add_column :social_media_accounts, :needs_secondary_verification, :boolean, default: false, null: false

    # Add field to people to mark those needing secondary verification
    add_column :people, :needs_secondary_verification, :boolean, default: false, null: false
    add_index :people, :needs_secondary_verification
  end
end
