require 'rails_helper'

# An assigner can narrow a demographic task to a subset of fields ("just get me
# race and gender for these 500 people"). The subset gates THAT assignment.
#
# The load-bearing rule: it must not touch `people.demographics_status`. That
# rollup means "every core field settled" and the admin filters depend on it —
# letting a two-field task claim a person is complete would quietly poison the
# thing admins use to find work.
RSpec.describe "Scoped demographic research", type: :request do
  let(:researcher) { create(:user, role: "researcher") }
  let(:admin)      { create(:user, :admin) }
  let(:person)     { create(:person, first_name: "Sub", last_name: "Set") }

  let(:scoped) do
    create(:assignment, :demographic_research, user: researcher, person: person,
                        assigned_by: admin, status: "in_progress",
                        required_demographic_fields: %w[gender race])
  end

  before { sign_in researcher }

  def settle!(target, keys)
    keys.each do |key|
      target.demographic_verifications.create!(field_key: key, status: "unknown",
                                               notes: "not documented",
                                               verified_by: researcher, verified_at: Time.current)
    end
    target.refresh_demographics_status!
  end

  describe "the completion gate" do
    it "completes once the required subset is settled, leaving other fields open" do
      settle!(person, %w[gender race])

      patch complete_demographics_assignment_path(scoped)

      expect(scoped.reload.status).to eq("completed")
    end

    it "does not mark the person complete — other core fields are still unresearched" do
      settle!(person, %w[gender race])

      patch complete_demographics_assignment_path(scoped)

      person.reload
      expect(person.demographics_status).to eq("in_progress")
      expect(person.unsettled_demographic_fields.map(&:key))
        .to include(:birth_date, :marital_status, :education_level)
    end

    it "still blocks while a required field is unsettled, naming only in-scope fields" do
      settle!(person, %w[gender])

      patch complete_demographics_assignment_path(scoped)

      expect(scoped.reload.status).not_to eq("completed")
      expect(flash[:alert]).to include("Race / ethnicity")
      # Out-of-scope fields must not appear in the blocking message.
      expect(flash[:alert]).not_to include("Marital status")
    end

    it "is unaffected by out-of-scope fields being settled or not" do
      settle!(person, %w[gender race marital_status])

      patch complete_demographics_assignment_path(scoped)

      expect(scoped.reload.status).to eq("completed")
    end

    it "tells the researcher the person still has gaps" do
      settle!(person, %w[gender race])

      patch complete_demographics_assignment_path(scoped)

      expect(flash[:notice]).to include("Gender and Race / ethnicity")
      expect(flash[:notice]).to include("remain unresearched")
    end
  end

  describe "an unscoped assignment" do
    let(:unscoped) do
      create(:assignment, :demographic_research, user: researcher, person: person,
                          assigned_by: admin, status: "in_progress")
    end

    it "still requires every core field — blank scope means all" do
      settle!(person, %w[gender race])

      patch complete_demographics_assignment_path(unscoped)

      expect(unscoped.reload.status).not_to eq("completed")
      expect(unscoped.demographic_fields_required.map(&:key)).to match_array(DemographicField::CORE_KEYS)
    end

    it "marks the person complete when it finishes, as before" do
      settle!(person, DemographicField::CORE_KEYS.map(&:to_s))

      patch complete_demographics_assignment_path(unscoped)

      expect(unscoped.reload.status).to eq("completed")
      expect(person.reload.demographics_status).to eq("complete")
    end
  end

  describe "the research page" do
    it "marks in-scope fields required and leaves the rest editable but optional" do
      get demographics_assignment_path(scoped)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Gender and Race / ethnicity")
      expect(response.body).to include("required")
      expect(response.body).to include("optional")
      # Out-of-scope fields are still on the page — a researcher who finds a
      # DOB while sourcing race should be able to record it.
      expect(response.body).to include("values[birth_date]")
      expect(response.body).to include("values[marital_status]")
    end

    it "counts progress against the assignment's subset, not the whole registry" do
      get demographics_assignment_path(scoped)

      expect(response.body).to include("0 of 2 required fields determined")
    end

    it "still lets a researcher save an out-of-scope field" do
      patch demographics_assignment_path(scoped), params: {
        values: { marital_status: "Married" },
        evidence: { marital_status: { status: "verified", source_url: "https://example.com/bio" } }
      }

      expect(person.reload.marital_status).to eq("Married")
    end
  end

  describe "dependent fields inside a scope" do
    it "drops an irrelevant dependent from the requirement" do
      assignment = create(:assignment, :demographic_research, user: researcher, person: person,
                                       assigned_by: admin, status: "in_progress",
                                       required_demographic_fields: %w[military_service military_branch])

      # No military service recorded, so Branch does not apply and must not block.
      expect(assignment.demographic_fields_required_for(person).map(&:key)).to eq([:military_service])

      person.update!(military_service: "Veteran")
      expect(assignment.demographic_fields_required_for(person).map(&:key))
        .to match_array([:military_service, :military_branch])
    end
  end

  describe "validation" do
    it "rejects an unknown field key rather than silently ignoring it" do
      assignment = build(:assignment, :demographic_research, user: researcher, person: person,
                                      assigned_by: admin,
                                      required_demographic_fields: %w[gender not_a_field])

      expect(assignment).not_to be_valid
      expect(assignment.errors[:required_demographic_fields].join).to include("not_a_field")
    end
  end

  describe "admin creation" do
    before { sign_in admin }

    it "creates assignments scoped to the ticked fields" do
      other = create(:person)

      post admin_assignments_path, params: {
        user_id: researcher.id, task_type: "demographic_research",
        person_ids: [person.id, other.id],
        required_demographic_fields: %w[gender race]
      }

      created = Assignment.demographic_research.where(user: researcher)
      expect(created.count).to eq(2)
      expect(created.map(&:required_demographic_fields).uniq).to eq([%w[gender race]])
    end

    it "ignores an unknown key posted in the form" do
      post admin_assignments_path, params: {
        user_id: researcher.id, task_type: "demographic_research",
        person_ids: [person.id],
        required_demographic_fields: %w[gender bogus_key]
      }

      expect(Assignment.demographic_research.last.required_demographic_fields).to eq(%w[gender])
    end

    it "leaves the scope empty — meaning all fields — when nothing is ticked" do
      post admin_assignments_path, params: {
        user_id: researcher.id, task_type: "demographic_research", person_ids: [person.id]
      }

      assignment = Assignment.demographic_research.last
      expect(assignment.required_demographic_fields).to eq([])
      expect(assignment.scoped_demographics?).to be(false)
      expect(assignment.demographic_fields_required.map(&:key)).to match_array(DemographicField::CORE_KEYS)
    end

    it "does not put a field scope on a non-demographic task type" do
      post admin_assignments_path, params: {
        user_id: researcher.id, task_type: "data_collection", person_ids: [person.id],
        required_demographic_fields: %w[gender]
      }

      expect(Assignment.data_collection.last.required_demographic_fields).to eq([])
    end

    it "shows the scope on the assignment page" do
      scoped
      get admin_assignment_path(scoped)

      expect(response.body).to include("Fields required")
      expect(response.body).to include("Gender and Race / ethnicity")
    end
  end
end
