require 'rails_helper'

RSpec.describe SocialMediaAccount, type: :model do
  let(:researcher) { create(:user) }
  let(:admin)      { create(:user, :admin) }

  describe "#verifiable_by?" do
    it "allows anyone for accounts with no enterer" do
      account = build(:social_media_account, entered_by: nil)
      expect(account.verifiable_by?(researcher)).to be(true)
    end

    it "blocks the user who entered the account" do
      account = build(:social_media_account, entered_by: researcher)
      expect(account.verifiable_by?(researcher)).to be(false)
    end

    it "allows a different user" do
      account = build(:social_media_account, entered_by: researcher)
      expect(account.verifiable_by?(create(:user))).to be(true)
    end

    it "exempts admins even for their own entries" do
      account = build(:social_media_account, entered_by: admin)
      expect(account.verifiable_by?(admin)).to be(true)
    end
  end

  describe "#mark_entered! modification flag" do
    it "does NOT flag first entry into a blank prepopulated stub" do
      account = create(:social_media_account) # not_started, no url

      account.mark_entered!(researcher, url: "https://twitter.com/fresh", handle: "fresh")

      expect(account.modified_during_validation).to be(false)
    end

    it "flags changing an existing URL" do
      account = create(:social_media_account, :entered)

      account.mark_entered!(researcher, url: "https://twitter.com/different", handle: "different")

      expect(account.modified_during_validation).to be(true)
    end

    it "flags re-entry over a previously verified account" do
      account = create(:social_media_account, :verified, verified: false, research_status: "verified")

      account.mark_entered!(researcher, url: account.url, handle: account.handle)

      expect(account.modified_during_validation).to be(true)
    end

    it "mark_not_found! still flags when data existed" do
      account = create(:social_media_account, :entered)

      account.mark_not_found!(researcher)

      expect(account.modified_during_validation).to be(true)
    end

    it "mark_not_found! does not flag a blank stub" do
      account = create(:social_media_account)

      account.mark_not_found!(researcher)

      expect(account.modified_during_validation).to be(false)
    end
  end

  describe "Junkipedia auto-enqueue regression" do
    it "enqueues on verification of an eligible account when the API token is configured" do
      allow(ENV).to receive(:[]).and_call_original
      allow(ENV).to receive(:[]).with("JUNKIPEDIA_API_TOKEN").and_return("test-token")
      account = create(:social_media_account, :entered, entered_by: create(:user))

      expect {
        account.verify!(researcher, notes: nil)
      }.to have_enqueued_job(EnqueueJunkipediaChannelJob).with(account.id)
    end

    it "does not enqueue without a token" do
      allow(ENV).to receive(:[]).and_call_original
      allow(ENV).to receive(:[]).with("JUNKIPEDIA_API_TOKEN").and_return(nil)
      account = create(:social_media_account, :entered, entered_by: create(:user))

      expect {
        account.verify!(researcher, notes: nil)
      }.not_to have_enqueued_job(EnqueueJunkipediaChannelJob)
    end
  end
end
