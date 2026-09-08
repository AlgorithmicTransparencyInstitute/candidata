require 'rails_helper'

# The admin assignment finder filters people on two independent axes:
# whether the demographic columns hold values, and how far a sourced review
# has got. They are separate on purpose — the population worth assigning is
# usually "has imported values, but nobody ever checked them", which neither
# axis alone can express.
RSpec.describe "Admin demographic filters", type: :request do
  let(:admin) { create(:user, :admin) }

  before { sign_in admin }

  # Someone with every required demographic value filled in, and no review.
  let!(:filled_unreviewed) do
    create(:person, first_name: "Filled", last_name: "Unreviewed",
                    gender: "Female", race: "White", birth_date: Date.new(1970, 1, 1),
                    marital_status: "Married", children_status: "No children",
                    education_level: "Bachelor's degree",
                    education_type: "Public university or college",
                    military_service: "Never served")
  end

  let!(:empty_person) { create(:person, first_name: "Empty", last_name: "Person") }

  let!(:reviewed_person) do
    person = create(:person, first_name: "Reviewed", last_name: "Complete", gender: "Male")
    DemographicField.core_relevant_for(person).each do |field|
      person.demographic_verifications.create!(field_key: field.key, status: "unknown",
                                               notes: "not documented", verified_at: Time.current)
    end
    person.refresh_demographics_status!
    person
  end

  def names_in_response
    { filled: response.body.include?("Filled Unreviewed"),
      empty: response.body.include?("Empty Person"),
      reviewed: response.body.include?("Reviewed Complete") }
  end

  it "separates 'has values' from 'has been reviewed'" do
    get new_admin_assignment_path(demographic_presence: 'all_present', demographics_status: 'not_started')

    expect(response).to have_http_status(:ok)
    shown = names_in_response
    expect(shown[:filled]).to be(true)      # values, never reviewed — the target population
    expect(shown[:empty]).to be(false)      # no values
    expect(shown[:reviewed]).to be(false)   # reviewed
  end

  it "finds people missing at least one required field" do
    get new_admin_assignment_path(demographic_presence: 'any_missing')

    shown = names_in_response
    expect(shown[:empty]).to be(true)
    expect(shown[:filled]).to be(false)
  end

  it "finds people missing one named field" do
    get new_admin_assignment_path(missing_demographic_field: 'marital_status')

    shown = names_in_response
    expect(shown[:empty]).to be(true)
    expect(shown[:reviewed]).to be(true)  # reviewed as "unknown", so still no value
    expect(shown[:filled]).to be(false)
  end

  it "ignores an unknown field key rather than erroring" do
    get new_admin_assignment_path(missing_demographic_field: 'not_a_field')

    expect(response).to have_http_status(:ok)
  end

  it "filters by review status" do
    get new_admin_assignment_path(demographics_status: 'complete')

    shown = names_in_response
    expect(shown[:reviewed]).to be(true)
    expect(shown[:filled]).to be(false)
    expect(shown[:empty]).to be(false)
  end

  it "finds people with a field where sources conflict" do
    reviewed_person.demographic_verification_for(:gender)
                   .update!(status: "disputed", notes: "sources disagree")

    get new_admin_assignment_path(demographics_disputed: '1')

    shown = names_in_response
    expect(shown[:reviewed]).to be(true)
    expect(shown[:empty]).to be(false)
  end

  it "offers demographic research as a task type and filters on having one" do
    get new_admin_assignment_path

    expect(response.body).to include('value="demographic_research"')
    expect(response.body).to include('Demographic Research')
    expect(response.body).to include('no_demographic_research')
  end

  it "creates demographic research assignments in bulk" do
    researcher = create(:user, role: "researcher")

    expect {
      post admin_assignments_path, params: {
        user_id: researcher.id, task_type: 'demographic_research',
        person_ids: [empty_person.id, filled_unreviewed.id]
      }
    }.to change { Assignment.demographic_research.count }.by(2)

    expect(researcher.assignments.demographic_research.map(&:person))
      .to contain_exactly(empty_person, filled_unreviewed)
  end
end
