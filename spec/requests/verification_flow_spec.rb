require 'rails_helper'

# Pins the verification workflow behavior designed in docs/VERIFICATION_WORKFLOW.md:
# four-eyes rule (admins exempt), completion gate scoped to accounts the completer
# may verify, secondary-verification hand-off, and workable secondary tasks.
RSpec.describe "Verification workflow", type: :request do
  let(:verifier)  { create(:user) }
  let(:other)     { create(:user) }
  let(:admin)     { create(:user, :admin) }
  let(:person)    { create(:person) }
  let!(:assignment) { create(:assignment, user: verifier, person: person) }

  before { sign_in verifier }

  describe "four-eyes rule on verify" do
    it "allows verifying an account entered by someone else" do
      account = create(:social_media_account, :entered, person: person, entered_by: other)

      patch verify_verification_account_path(account)

      expect(account.reload.research_status).to eq("verified")
      expect(account.verified).to be(true)
      expect(account.verified_by).to eq(verifier)
    end

    it "blocks verifying your own entry" do
      account = create(:social_media_account, :entered, person: person, entered_by: verifier)

      patch verify_verification_account_path(account)

      expect(account.reload.research_status).to eq("entered")
      expect(account.verified).to be(false)
      expect(flash[:alert]).to be_present
    end

    it "blocks verify_with_changes on your own entry" do
      account = create(:social_media_account, :entered, person: person, entered_by: verifier)

      patch verify_with_changes_verification_account_path(account),
            params: { social_media_account: { url: "https://twitter.com/changed", handle: nil, verification_notes: "x" } }

      expect(account.reload.verified).to be(false)
    end

    it "exempts admins (they may verify their own entries)" do
      sign_in admin
      create(:assignment, user: admin, person: person)
      account = create(:social_media_account, :entered, person: person, entered_by: admin, platform: "Facebook")

      patch verify_verification_account_path(account)

      expect(account.reload.verified).to be(true)
    end
  end

  describe "completing a data_validation assignment" do
    it "completes when every account is resolved" do
      create(:social_media_account, :verified, person: person)

      patch complete_verification_assignment_path(assignment)

      expect(assignment.reload.status).to eq("completed")
    end

    it "stays blocked by pending accounts entered by someone else" do
      create(:social_media_account, :entered, person: person, entered_by: other)

      patch complete_verification_assignment_path(assignment)

      expect(assignment.reload.status).to eq("in_progress")
      expect(flash[:alert]).to match(/need verification/)
    end

    it "completes when the only pending accounts are the completer's own additions, flagging them for secondary verification" do
      create(:social_media_account, :verified, person: person)
      own = create(:social_media_account, :entered, person: person, entered_by: verifier, platform: "Instagram")

      patch complete_verification_assignment_path(assignment)

      expect(assignment.reload.status).to eq("completed")
      expect(own.reload.needs_secondary_verification).to be(true)
      expect(own.verified).to be(false) # four-eyes guarantee: still unverified
      expect(person.reload.needs_secondary_verification).to be(true)
    end

    it "keeps blocking a mix: someone else's pending account blocks even when own additions exist" do
      create(:social_media_account, :entered, person: person, entered_by: other)
      create(:social_media_account, :entered, person: person, entered_by: verifier, platform: "Instagram")

      patch complete_verification_assignment_path(assignment)

      expect(assignment.reload.status).to eq("in_progress")
    end
  end

  describe "secondary verification tasks" do
    let(:flagged_person) { create(:person, needs_secondary_verification: true) }
    let!(:secondary) { create(:assignment, :secondary_verification, user: other, person: flagged_person) }
    let!(:flagged_account) do
      create(:social_media_account, :entered, person: flagged_person,
             entered_by: verifier, needs_secondary_verification: true)
    end

    before { sign_in other }

    it "is visible and workable in the verification workspace" do
      get verification_assignment_path(secondary)
      expect(response).to have_http_status(:ok)
    end

    it "shows the red flag treatment only on the secondary task; validation tasks show research status" do
      get verification_assignment_path(secondary)
      expect(response.body).to include("Needs Secondary Verification")

      # The same flagged account viewed through a data_validation task renders
      # by research status (verify turns it green) with a muted info pill —
      # the red flag is the secondary task's job, not the validator's.
      validation = create(:assignment, user: verifier, person: flagged_person)
      validation.start!
      sign_in verifier
      get verification_assignment_path(validation)

      expect(response.body).not_to include("Needs Secondary Verification</span>")
      expect(response.body).to include("Flagged for secondary review")
      expect(response.body).to include("Needs Verification") # status badge for the entered account
    end

    it "blocks completion while flagged accounts are unresolved" do
      patch complete_verification_assignment_path(secondary)

      expect(secondary.reload.status).to eq("in_progress")
    end

    it "refuses to confirm an unresolved flagged account" do
      patch confirm_secondary_verification_account_path(flagged_account)

      expect(flagged_account.reload.needs_secondary_verification).to be(true)
    end

    it "requires per-account confirmation: verifying alone does not unlock completion" do
      patch verify_verification_account_path(flagged_account)
      expect(flagged_account.reload.verified).to be(true)

      patch complete_verification_assignment_path(secondary)
      expect(secondary.reload.status).to eq("in_progress") # still flagged — not confirmed

      patch confirm_secondary_verification_account_path(flagged_account)
      expect(flagged_account.reload.needs_secondary_verification).to be(false)

      patch complete_verification_assignment_path(secondary)
      expect(secondary.reload.status).to eq("completed")
      expect(flagged_person.reload.needs_secondary_verification).to be(false)
    end

    it "confirms each flagged account independently before completion unlocks" do
      second_flagged = create(:social_media_account, :entered, person: flagged_person,
                              entered_by: verifier, needs_secondary_verification: true, platform: "TikTok")
      [flagged_account, second_flagged].each { |a| patch verify_verification_account_path(a) }

      patch confirm_secondary_verification_account_path(flagged_account)
      patch complete_verification_assignment_path(secondary)
      expect(secondary.reload.status).to eq("in_progress") # TikTok still unconfirmed

      patch confirm_secondary_verification_account_path(second_flagged)
      patch complete_verification_assignment_path(secondary)
      expect(secondary.reload.status).to eq("completed")
    end

    it "enforces four-eyes on confirmation: the enterer can't confirm their own account" do
      flagged_account.verify!(other) # resolved, but entered by `verifier`
      create(:assignment, :secondary_verification, user: verifier, person: flagged_person)
      sign_in verifier

      patch confirm_secondary_verification_account_path(flagged_account)

      expect(flagged_account.reload.needs_secondary_verification).to be(true)
      expect(flash[:alert]).to be_present
    end
  end

  describe "admin force-complete escape hatch (unchanged)" do
    it "completes regardless of pending accounts" do
      sign_in admin
      create(:social_media_account, :entered, person: person, entered_by: other)

      patch complete_admin_assignment_path(assignment)

      expect(assignment.reload.status).to eq("completed")
    end
  end
end
