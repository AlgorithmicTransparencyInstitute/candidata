require 'rails_helper'

# The researcher dashboard must give all three task types the same treatment:
# data_collection, data_validation, AND secondary_verification (which was
# missing — secondary tasks were invisible unless the researcher happened to
# visit /verification directly).
RSpec.describe "Researcher dashboard", type: :request do
  let(:researcher) { create(:user, role: "researcher") }
  let(:admin) { create(:user, :admin) }

  before { sign_in researcher }

  def person_named(first, last)
    Person.create!(first_name: first, last_name: last, state_of_residence: "NY")
  end

  def assign!(person, task_type, status)
    Assignment.create!(user: researcher, person: person, assigned_by: admin,
                       task_type: task_type, status: status)
  end

  it "shows active assignments of all three task types" do
    collection = assign!(person_named("Colin", "Collect"), "data_collection", "pending")
    validation = assign!(person_named("Val", "Verify"), "data_validation", "pending")
    secondary  = assign!(person_named("Sec", "Second"), "secondary_verification", "pending")

    get researcher_root_path

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("Colin Collect")
    expect(response.body).to include("Val Verify")
    expect(response.body).to include("Sec Second")
    expect(response.body).to include("Secondary Verification")
    # secondary card links into the verification workspace, which owns that flow
    expect(response.body).to include(verification_assignment_path(secondary))
    expect(response.body).to include(start_verification_assignment_path(secondary))
    # sanity: the other two cards still link where they always did
    expect(response.body).to include(researcher_assignment_path(collection))
    expect(response.body).to include(verification_assignment_path(validation))
  end

  it "shows an in-progress secondary assignment as Continue with flagged-account count" do
    person = person_named("Amanda", "Flagged")
    person.social_media_accounts.create!(platform: "Facebook", channel_type: "Campaign",
                                         needs_secondary_verification: true)
    assign!(person, "secondary_verification", "in_progress")

    get researcher_root_path

    expect(response.body).to include("1 accounts flagged for re-review")
    expect(response.body).to include("Continue")
  end
end
