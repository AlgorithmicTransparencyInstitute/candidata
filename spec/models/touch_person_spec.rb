require 'rails_helper'

# The public API's incremental sync (?updated_since=) relies on association
# changes bumping people.updated_at. Pin that here.
RSpec.describe "Person touch on association change", type: :model do
  let(:person) { create(:person) }

  it "bumps person.updated_at when a social media account is created, updated, or destroyed" do
    person.update_column(:updated_at, 1.day.ago)
    account = person.social_media_accounts.create!(platform: "Twitter", handle: "abc",
                                                   url: "https://twitter.com/abc")
    expect(person.reload.updated_at).to be > 1.hour.ago

    person.update_column(:updated_at, 1.day.ago)
    account.update!(handle: "def", url: "https://twitter.com/def")
    expect(person.reload.updated_at).to be > 1.hour.ago

    person.update_column(:updated_at, 1.day.ago)
    account.destroy!
    expect(person.reload.updated_at).to be > 1.hour.ago
  end

  it "bumps person.updated_at when a party affiliation changes" do
    party = Party.create!(name: "Green", abbreviation: "G")
    person.update_column(:updated_at, 1.day.ago)
    person.add_party(party, is_primary: true)
    expect(person.reload.updated_at).to be > 1.hour.ago
  end

  it "does not record a PaperTrail version on the person for touch-only updates" do
    person # create before measuring
    expect {
      person.social_media_accounts.create!(platform: "Twitter", handle: "xyz",
                                           url: "https://twitter.com/xyz")
    }.not_to change { person.versions.count }
  end

  it "bumps person.updated_at when the primary party is cleared via primary_party=" do
    party = Party.create!(name: "Forward", abbreviation: "FWD")
    person.add_party(party, is_primary: true)
    person.update_column(:updated_at, 1.day.ago)

    person.primary_party = nil

    expect(person.reload.updated_at).to be > 1.hour.ago
  end
end
