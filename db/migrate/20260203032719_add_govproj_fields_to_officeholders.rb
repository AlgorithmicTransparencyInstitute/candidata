class AddGovprojFieldsToOfficeholders < ActiveRecord::Migration[7.2]
  def change
    add_column :officeholders, :official_email, :string
    add_column :officeholders, :official_phone, :string
    add_column :officeholders, :official_address, :text
    add_column :officeholders, :contact_form_url, :string
    add_column :officeholders, :next_election_date, :date
    add_column :officeholders, :term_end_date, :date
  end
end
