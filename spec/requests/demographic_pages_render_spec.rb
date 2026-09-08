require 'rails_helper'

# Smoke coverage for the pages the demographic research feature touched.
# These are template-heavy screens with no other spec covering them; a typo in
# the ERB would otherwise only surface in production.
RSpec.describe "Pages touched by demographic research", type: :request do
  let(:admin) { create(:user, :admin) }
  let(:researcher) { create(:user, role: "researcher") }
  let(:person) { create(:person, first_name: "Render", last_name: "Check") }

  context "as an admin" do
    before { sign_in admin }

    it "renders the person show page with the demographics table and evidence" do
      person.update!(gender: "Female", race: "White, Asian", marital_status: "Married")
      person.demographic_verifications.create!(
        field_key: "gender", status: "verified", source_url: "https://example.com/bio",
        notes: "campaign bio", verified_by: admin, verified_at: Time.current
      )
      person.refresh_demographics_status!

      get admin_person_path(person)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Demographics")
      expect(response.body).to include("Marital status")
      expect(response.body).to include("https://example.com/bio")
      expect(response.body).to include("White, Asian")
    end

    it "renders the person edit form with gender values the model actually accepts" do
      get edit_admin_person_path(person)

      expect(response).to have_http_status(:ok)
      # This form used to submit 'M'/'F'/'O', which failed Person's inclusion
      # validation, so gender could never be saved from here.
      Person::GENDERS.each { |g| expect(response.body).to include("value=\"#{g}\"") }
      expect(response.body).not_to include('value="M">')
    end

    it "saves demographics from the admin person form" do
      patch admin_person_path(person), params: {
        person: { gender: "Non-binary", marital_status: "Divorced", military_service: "Veteran",
                  military_branch: "Navy", education_level: "Master's degree" }
      }

      person.reload
      expect(person.gender).to eq("Non-binary")
      expect(person.marital_status).to eq("Divorced")
      expect(person.military_branch).to eq("Navy")
    end

    it "renders the admin guide with the demographic research section" do
      get admin_guide_path

      expect(response).to have_http_status(:ok)
      expect(response.body).to include('id="demographic-research"')
      expect(response.body).to include("7. Demographic Research")
      expect(response.body).to include("a blank field is not an answer")
    end
  end

  context "as a researcher" do
    before { sign_in researcher }

    it "renders the researcher guide with the demographic research section" do
      get researcher_guide_path

      expect(response).to have_http_status(:ok)
      expect(response.body).to include('id="demographic-research"')
      expect(response.body).to include("Not publicly documented")
    end

    it "renders the demographics research page for an assigned person" do
      assignment = create(:assignment, :demographic_research, user: researcher,
                                       person: person, assigned_by: admin)

      get demographics_assignment_path(assignment)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Render Check")
      expect(response.body).to include("Sources for this person")
      DemographicField::GROUPS.each { |group| expect(response.body).to include(group) }
    end
  end
end
