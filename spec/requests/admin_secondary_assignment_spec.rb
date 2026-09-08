require 'rails_helper'

# Admins must not be able to assign a secondary_verification task to the user
# whose own pending entries are the reason the person is flagged.
RSpec.describe "Admin secondary verification assignment", type: :request do
  let(:admin)    { create(:user, :admin) }
  let(:enterer)  { create(:user) }
  let(:reviewer) { create(:user) }
  let(:person)   { create(:person, needs_secondary_verification: true) }

  before do
    sign_in admin
    create(:social_media_account, :entered, person: person,
           entered_by: enterer, needs_secondary_verification: true)
  end

  it "skips assigning to the user who entered the flagged accounts" do
    post admin_assignments_path, params: {
      user_id: enterer.id, task_type: "secondary_verification", person_ids: [person.id]
    }

    expect(Assignment.where(user: enterer, person: person, task_type: "secondary_verification")).to be_empty
    expect(flash[:notice]).to match(/0 assignments/)
  end

  it "allows assigning to a different user" do
    post admin_assignments_path, params: {
      user_id: reviewer.id, task_type: "secondary_verification", person_ids: [person.id]
    }

    expect(Assignment.where(user: reviewer, person: person, task_type: "secondary_verification").count).to eq(1)
  end

  it "tells the admin why people were skipped instead of silently dropping them" do
    post admin_assignments_path, params: {
      user_id: enterer.id, task_type: "secondary_verification", person_ids: [person.id]
    }

    expect(flash[:notice]).to include("can't verify their own work")
  end

  # The rule used to live only in Admin::AssignmentsController#create. The
  # per-person and bulk-assign screens could create a secondary task nobody
  # could ever complete — reachable once their task-type dropdowns were widened
  # to offer secondary verification.
  it "enforces the same rule on the per-person assign form" do
    post assign_researcher_admin_person_path(person), params: {
      user_id: enterer.id, task_type: "secondary_verification"
    }

    expect(Assignment.where(user: enterer, person: person, task_type: "secondary_verification")).to be_empty
    expect(flash[:alert]).to include("can't do the secondary verification")
  end

  it "enforces the same rule on bulk assign" do
    post create_bulk_assignments_admin_people_path, params: {
      user_id: enterer.id, task_type: "secondary_verification", person_ids: [person.id]
    }

    expect(Assignment.where(user: enterer, person: person, task_type: "secondary_verification")).to be_empty
    expect(flash[:notice]).to include("can't verify their own work")
  end

  it "still allows an eligible user through those paths" do
    post assign_researcher_admin_person_path(person), params: {
      user_id: reviewer.id, task_type: "secondary_verification"
    }

    expect(Assignment.where(user: reviewer, person: person, task_type: "secondary_verification").count).to eq(1)
  end
end
