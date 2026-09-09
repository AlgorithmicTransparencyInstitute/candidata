require 'rails_helper'

# Researchers arrive and leave in cohorts. Deactivation is a soft state: their
# work stays attributed to them, but they stop appearing anywhere someone is
# being CHOSEN, and they can no longer sign in.
RSpec.describe "Researcher deactivation", type: :request do
  let(:admin)     { create(:user, :admin, name: "Ada Admin") }
  let(:active)    { create(:user, role: "researcher", name: "Nora New") }
  let(:departed)  { create(:user, role: "researcher", name: "Gus Graduated") }

  describe "the model" do
    it "keeps work attributed after deactivation — the reason this isn't a delete" do
      person = create(:person)
      account = create(:social_media_account, :entered, person: person, entered_by: departed)
      verification = person.demographic_verifications.create!(
        field_key: "gender", status: "verified", source_url: "https://example.com",
        verified_by: departed, verified_at: Time.current
      )

      departed.deactivate!(by: admin)

      expect(account.reload.entered_by).to eq(departed)
      expect(verification.reload.verified_by).to eq(departed)
      expect(departed.reload).to be_deactivated
      expect(departed.deactivated_by).to eq(admin)
    end

    it "blocks authentication, which also ends any live session" do
      expect(active.active_for_authentication?).to be(true)

      active.deactivate!(by: admin)

      expect(active.active_for_authentication?).to be(false)
      expect(active.inactive_message).to eq(:account_deactivated)
    end

    it "restores access on reactivation" do
      active.deactivate!(by: admin)
      active.reactivate!

      expect(active.reload).to be_active
      expect(active.deactivated_by).to be_nil
      expect(active.active_for_authentication?).to be(true)
    end

    it "keeps `researchers` meaning everyone, and scopes only where a human is chosen" do
      departed.deactivate!(by: admin)
      active

      expect(User.researchers).to include(departed, active)
      expect(User.active_researchers).to include(active)
      expect(User.active_researchers).not_to include(departed)
    end
  end

  describe "sign-in" do
    it "refuses a deactivated user with a clear message" do
      user = create(:user, role: "researcher", password: "Test-pass-123!")
      user.deactivate!(by: admin)

      post user_session_path, params: { user: { email: user.email, password: "Test-pass-123!" } }

      expect(response).not_to redirect_to(researcher_root_path)
      follow_redirect! if response.redirect?
      expect(response.body).to include("deactivated")
    end

    it "still lets an active researcher in" do
      user = create(:user, role: "researcher", password: "Test-pass-123!")

      post user_session_path, params: { user: { email: user.email, password: "Test-pass-123!" } }

      expect(response).to redirect_to(researcher_root_path)
    end
  end

  describe "pickers" do
    before do
      active # let is lazy — force both researchers into existence
      departed.deactivate!(by: admin)
      sign_in admin
    end

    it "omits deactivated researchers from the assignment builder" do
      get new_admin_assignment_path

      expect(response.body).to include("Nora New")
      expect(response.body).not_to include("Gus Graduated")
    end

    it "omits them from the per-person assign dropdown" do
      person = create(:person)
      get admin_person_path(person)

      expect(response.body).to include("Nora New")
      expect(response.body).not_to include("Gus Graduated")
    end

    it "omits them from bulk assign" do
      get bulk_assign_admin_people_path

      expect(response.body).to include("Nora New")
      expect(response.body).not_to include("Gus Graduated")
    end

    it "keeps the current assignee on the edit form even if they're deactivated" do
      assignment = create(:assignment, user: departed, person: create(:person), assigned_by: admin)

      get edit_admin_assignment_path(assignment)

      # Dropping them would silently reassign the task on save.
      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Gus Graduated")
      expect(response.body).to include("deactivated")
      expect(response.body).to include("Nora New")
    end

    it "reassigns a stranded assignment to an active researcher" do
      assignment = create(:assignment, user: departed, person: create(:person), assigned_by: admin)

      patch admin_assignment_path(assignment), params: { assignment: { user_id: active.id } }

      expect(assignment.reload.user).to eq(active)
    end
  end

  describe "assignment guards" do
    before do
      active
      departed.deactivate!(by: admin)
      sign_in admin
    end

    it "refuses to create assignments for a deactivated researcher" do
      person = create(:person)

      expect {
        post admin_assignments_path, params: {
          user_id: departed.id, task_type: "data_collection", person_ids: [person.id]
        }
      }.not_to change { Assignment.count }

      expect(flash[:alert]).to include("deactivated")
    end

    it "refuses on the per-person path too" do
      person = create(:person)

      post assign_researcher_admin_person_path(person), params: {
        user_id: departed.id, task_type: "data_collection"
      }

      expect(Assignment.where(user: departed)).to be_empty
      expect(flash[:alert]).to include("deactivated")
    end

    it "refuses on bulk assign" do
      person = create(:person)

      post create_bulk_assignments_admin_people_path, params: {
        user_id: departed.id, task_type: "data_collection", person_ids: [person.id]
      }

      expect(Assignment.where(user: departed)).to be_empty
      expect(flash[:alert]).to include("deactivated")
    end
  end

  describe "admin actions" do
    before { sign_in admin }

    it "deactivates a researcher and warns about stranded work" do
      create(:assignment, user: active, person: create(:person), assigned_by: admin, status: "pending")

      patch deactivate_admin_user_path(active)

      expect(active.reload).to be_deactivated
      expect(flash[:notice]).to include("1 open assignment")
      expect(flash[:notice]).to include("reassign")
    end

    it "refuses to let an admin deactivate themselves" do
      patch deactivate_admin_user_path(admin)

      expect(admin.reload).to be_active
      expect(flash[:alert]).to include("your own account")
    end

    it "reactivates" do
      active.deactivate!(by: admin)

      patch reactivate_admin_user_path(active)

      expect(active.reload).to be_active
    end

    it "bulk deactivates a cohort, leaving the acting admin alone" do
      a = create(:user, role: "researcher", cohort: "Spring 2026")
      b = create(:user, role: "researcher", cohort: "Spring 2026")

      post bulk_deactivate_admin_users_path, params: { user_ids: [a.id, b.id, admin.id] }

      expect(a.reload).to be_deactivated
      expect(b.reload).to be_deactivated
      expect(admin.reload).to be_active
      expect(flash[:notice]).to include("left active")
    end

    it "defaults the users list to active only" do
      active
      departed.deactivate!(by: admin)

      get admin_users_path

      expect(response.body).to include("Nora New")
      expect(response.body).not_to include("Gus Graduated")
    end

    it "can still show deactivated users" do
      departed.deactivate!(by: admin)

      get admin_users_path(status: 'inactive')

      expect(response.body).to include("Gus Graduated")
      expect(response.body).to include("Deactivated")
    end

    it "explains rather than 500s when a user can't be deleted" do
      create(:social_media_account, :entered, person: create(:person), entered_by: departed)

      delete admin_user_path(departed)

      expect(User.exists?(departed.id)).to be(true)
      expect(flash[:alert]).to include("Deactivate them instead")
    end
  end

  describe "impersonation" do
    before { sign_in admin }

    it "refuses to start impersonating a deactivated user" do
      departed.deactivate!(by: admin)

      post impersonate_admin_user_path(departed)

      expect(session[:impersonating_user_id]).to be_nil
      expect(flash[:alert]).to include("deactivated")
    end

    it "drops an in-flight impersonation when the user is deactivated mid-session" do
      post impersonate_admin_user_path(active)
      expect(session[:impersonating_user_id]).to eq(active.id)

      active.deactivate!(by: admin)

      # This path bypasses Warden, so it needs its own check.
      get admin_users_path
      expect(session[:impersonating_user_id]).to be_nil
      expect(response).to have_http_status(:ok)
    end
  end
end
