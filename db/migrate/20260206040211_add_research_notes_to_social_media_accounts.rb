class AddResearchNotesToSocialMediaAccounts < ActiveRecord::Migration[7.2]
  def change
    add_column :social_media_accounts, :research_notes, :text
  end
end
