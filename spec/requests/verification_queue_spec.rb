require 'rails_helper'

# The verification queue serves BOTH verification task types, in separate
# sections: data_validation and secondary_verification. The researcher-layout
# sidebar shows a per-type badge for each ("Validation" / "Secondary Review") —
# previously one "Verification" badge counted only data_validation while the
# page it linked to listed both types, so the numbers never matched.
RSpec.describe "Verification queue", type: :request do
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

  it "lists validation and secondary assignments in their own sections" do
    assign!(person_named("Val", "Verify"), "data_validation", "pending")
    flagged = person_named("Sec", "Second")
    flagged.social_media_accounts.create!(platform: "Facebook", channel_type: "Campaign",
                                          needs_secondary_verification: true)
    assign!(flagged, "secondary_verification", "pending")

    get verification_queue_path

    expect(response).to have_http_status(:ok)
    expect(response.body).to include('id="validation"')
    expect(response.body).to include('id="secondary"')
    expect(response.body).to include("Val Verify")
    expect(response.body).to include("Sec Second")
    expect(response.body).to include("1 accounts flagged for re-review")
    expect(response.body).to include("Start Validation")  # validation button
    expect(response.body).to include("Start Review")  # secondary button
  end

  it "shows separate sidebar badges for validation and secondary counts" do
    assign!(person_named("Val", "One"), "data_validation", "pending")
    2.times { |i| assign!(person_named("Sec", "Number#{i}"), "secondary_verification", "pending") }

    get verification_queue_path

    expect(response.body).to include("Data Validation")
    expect(response.body).to include("Secondary Verification")
    # per-type stats tiles
    expect(response.body).to include("Pending Validation")
    expect(response.body).to include("Pending Secondary")
  end
end
