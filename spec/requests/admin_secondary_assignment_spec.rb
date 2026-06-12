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
end
