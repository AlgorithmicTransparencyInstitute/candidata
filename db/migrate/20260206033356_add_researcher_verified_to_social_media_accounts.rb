class AddResearcherVerifiedToSocialMediaAccounts < ActiveRecord::Migration[7.2]
  def change
    add_column :social_media_accounts, :researcher_verified, :boolean, default: false, null: false
  end
end
