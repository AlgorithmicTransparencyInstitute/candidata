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

    # Deactivation is a terminal disposition: a deactivated account is resolved
    # by that very act and must never block completion (the Jean Monestime /
    # assignment 2893 bug: "1 accounts still need verification" for an account
    # the user had just marked deactivated).
    it "completes when the only pending account is deactivated" do
      create(:social_media_account, :verified, person: person)
      dead = create(:social_media_account, :entered, person: person, entered_by: other,
                    platform: "Twitter", account_inactive: true)

      patch complete_verification_assignment_path(assignment)

      expect(assignment.reload.status).to eq("completed")
      expect(dead.reload.needs_secondary_verification).to be(false) # resolved, not handed off
    end

    it "does not flag the completer's own deactivated entry for secondary verification" do
      create(:social_media_account, :verified, person: person)
      own_dead = create(:social_media_account, :entered, person: person, entered_by: verifier,
                        platform: "Instagram", account_inactive: true)

      patch complete_verification_assignment_path(assignment)

      expect(assignment.reload.status).to eq("completed")
      expect(own_dead.reload.needs_secondary_verification).to be(false)
      expect(person.reload.needs_secondary_verification).to be(false)
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

    it "confirming an unverified flagged account re-verifies it and clears the flag in one step" do
      # secondary verification IS the re-verification — no second validation cycle
      patch confirm_secondary_verification_account_path(flagged_account)

      flagged_account.reload
      expect(flagged_account.needs_secondary_verification).to be(false)
      expect(flagged_account.verified).to be(true)
      expect(flagged_account.research_status).to eq("verified")
      expect(flagged_account.verified_by).to eq(other)
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

    it "does not require confirming a deactivated flagged account, and clears its flag on completion" do
      flagged_account.update!(account_inactive: true)

      patch complete_verification_assignment_path(secondary)

      expect(secondary.reload.status).to eq("completed")
      expect(flagged_account.reload.needs_secondary_verification).to be(false)
      expect(flagged_person.reload.needs_secondary_verification).to be(false)
    end

    it "enforces four-eyes on confirmation: the enterer can't confirm their own account" do
      flagged_account.verify!(other) # resolved, but entered by `verifier`
      create(:assignment, :secondary_verification, user: verifier, person: flagged_person)
      sign_in verifier

      patch confirm_secondary_verification_account_path(flagged_account)

      expect(flagged_account.reload.needs_secondary_verification).to be(true)
      expect(flash[:alert]).to be_present
    end

    # The deadlock fix: an account the completer modified during the secondary
    # review (or a misassigned task where they entered the flagged data) can
    # never be verified/confirmed by them (four-eyes). It must not brick the
    # task — completion succeeds and hands the account, still flagged, to the
    # next secondary cycle for another user.
    it "does not deadlock when the assignee modifies a flagged account mid-review" do
      # `other` (the secondary assignee) edits the flagged account — it becomes
      # their own entry, which they can neither verify nor confirm
      patch mark_entered_verification_account_path(flagged_account, url: "https://twitter.com/corrected")
      expect(flagged_account.reload.entered_by).to eq(other)

      patch complete_verification_assignment_path(secondary)

      expect(secondary.reload.status).to eq("completed")
      # the hand-off: account and person stay flagged for the next reviewer
      expect(flagged_account.reload.needs_secondary_verification).to be(true)
      expect(flagged_person.reload.needs_secondary_verification).to be(true)
    end

    it "still blocks completion while actionable flagged accounts are unconfirmed, even with leftovers" do
      own_edit = create(:social_media_account, :entered, person: flagged_person,
                        entered_by: other, needs_secondary_verification: true, platform: "TikTok")

      patch verify_verification_account_path(flagged_account) # actionable: entered by `verifier`
      patch complete_verification_assignment_path(secondary)
      expect(secondary.reload.status).to eq("in_progress") # verified but not confirmed

      patch confirm_secondary_verification_account_path(flagged_account)
      patch complete_verification_assignment_path(secondary)
      expect(secondary.reload.status).to eq("completed")
      expect(own_edit.reload.needs_secondary_verification).to be(true) # handed off
      expect(flagged_person.reload.needs_secondary_verification).to be(true)
    end
  end

  describe "deactivated and escalation toggles" do
    let!(:account) { create(:social_media_account, :entered, person: person, entered_by: other) }

    it "marks an account deactivated keeping its URL, and reactivates on second toggle" do
      url = account.url
      patch toggle_deactivated_verification_account_path(account)

      account.reload
      expect(account.account_inactive).to be(true)
      expect(account.url).to eq(url) # deactivated ≠ not found: data is kept

      patch toggle_deactivated_verification_account_path(account)
      expect(account.reload.account_inactive).to be(false)
    end

    it "escalates for admin review with a who/when stamp, and clears on second toggle" do
      patch toggle_escalated_verification_account_path(account)

      account.reload
      expect(account.escalated_for_review).to be(true)
      expect(account.escalated_by).to eq(verifier)
      expect(account.escalated_at).to be_present

      patch toggle_escalated_verification_account_path(account)
      account.reload
      expect(account.escalated_for_review).to be(false)
      expect(account.escalated_by).to be_nil
      expect(account.escalated_at).to be_nil
    end

    it "renders the toggle icons on secondary-verification screens too (not just validation)" do
      flagged_person = create(:person, needs_secondary_verification: true)
      flagged = create(:social_media_account, :entered, person: flagged_person,
                       entered_by: verifier, needs_secondary_verification: true)
      secondary = create(:assignment, :secondary_verification, user: other, person: flagged_person)
      sign_in other

      get verification_assignment_path(secondary)

      expect(response.body).to include(toggle_deactivated_verification_account_path(flagged))
      expect(response.body).to include(toggle_escalated_verification_account_path(flagged))
    end

    it "renders a deactivated pending account without needs-verification framing" do
      account.update!(account_inactive: true)
      assignment.start!

      get verification_assignment_path(assignment)

      expect(response.body).to include("Deactivated")
      expect(response.body).not_to include("Needs Verification")
    end

    it "keeps a deactivated account out of the junkipedia-eligible scope" do
      account.verify!(verifier)
      expect(SocialMediaAccount.junkipedia_eligible).to include(account)

      patch toggle_deactivated_verification_account_path(account)
      expect(SocialMediaAccount.junkipedia_eligible).not_to include(account.reload)
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
