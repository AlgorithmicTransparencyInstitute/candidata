require 'rails_helper'

# demographic_verifications introduced the first foreign keys pointing at
# `assignments` and `users`. Both are NO ACTION at the DB level, so without a
# matching `dependent:` on the Rails side, deleting an assignment — or a
# researcher, which cascades into their assignments — raised
# ActiveRecord::InvalidForeignKey and 500'd. Neither destroy path had any spec.
RSpec.describe "Admin destroy paths with demographic evidence", type: :request do
  let(:admin) { create(:user, :admin) }
  let(:researcher) { create(:user, role: "researcher") }
  let(:person) { create(:person) }

  before { sign_in admin }

  def record_determination!(assignment)
    person.demographic_verifications.create!(
      field_key: "gender", status: "verified", value_snapshot: "Female",
      source_url: "https://example.com/bio", verified_by: researcher,
      verified_at: Time.current, assignment: assignment
    )
  end

  it "deletes an assignment that has determinations, keeping the evidence" do
    assignment = create(:assignment, :demographic_research, user: researcher,
                                     person: person, assigned_by: admin)
    verification = record_determination!(assignment)

    delete admin_assignment_path(assignment)

    expect(Assignment.exists?(assignment.id)).to be(false)
    # The evidence outlives the work ticket — it is a record of a determination,
    # not of the assignment that prompted it.
    expect(verification.reload.assignment_id).to be_nil
    expect(verification.status).to eq("verified")
  end

  it "deletes a researcher who has recorded determinations" do
    assignment = create(:assignment, :demographic_research, user: researcher,
                                     person: person, assigned_by: admin)
    verification = record_determination!(assignment)

    delete admin_user_path(researcher)

    expect(User.exists?(researcher.id)).to be(false)
    expect(verification.reload).to be_present
    expect(verification.verified_by_id).to be_nil
    expect(verification.assignment_id).to be_nil
  end

  it "deletes a person and takes their determinations with them" do
    assignment = create(:assignment, :demographic_research, user: researcher,
                                     person: person, assigned_by: admin)
    record_determination!(assignment)

    expect { person.destroy! }.to change { DemographicVerification.count }.by(-1)
  end
end
