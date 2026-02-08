class AddValidationSourceToSocialMediaAccounts < ActiveRecord::Migration[8.0]
  def change
    add_column :social_media_accounts, :validation_source, :string
  end
end
