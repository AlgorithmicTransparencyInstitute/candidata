require 'rails_helper'

# Demographic research is a fourth assignment type with its own workspace.
# The rule that shapes the whole flow: a *blank field is not an answer*. A
# researcher settles a field either by recording a sourced value or by
# recording that the answer is not publicly documented — and completion is
# gated on every required field being settled one way or the other.
RSpec.describe "Demographic research", type: :request do
  let(:researcher) { create(:user, role: "researcher") }
  let(:admin)      { create(:user, :admin) }
  let(:person)     { create(:person, first_name: "Dana", last_name: "Demo") }
  let(:assignment) do
    create(:assignment, :demographic_research, user: researcher, person: person,
                        assigned_by: admin, status: "pending")
  end

  before { sign_in researcher }

  # Settle every required field so completion is reachable without repeating
  # the whole payload in each example.
  def settle_all!(target = person)
    DemographicField.core_relevant_for(target).each do |field|
      target.demographic_verifications.create!(
        field_key: field.key, status: "unknown",
        notes: "not documented", verified_by: researcher, verified_at: Time.current
      )
    end
    target.refresh_demographics_status!
  end

  describe "the queue" do
    it "lists the researcher's demographic assignments with progress" do
      assignment
      get demographics_assignments_path

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Dana Demo")
      expect(response.body).to include("Demographic Research")
    end

    it "does not leak another researcher's assignments" do
      other = create(:user, role: "researcher")
      create(:assignment, :demographic_research, user: other, assigned_by: admin,
                          person: create(:person, first_name: "Hidden", last_name: "Person"))

      get demographics_assignments_path

      expect(response.body).not_to include("Hidden Person")
    end
  end

  describe "the research page" do
    it "shows the sourcing reference material and a control per field" do
      person.update!(website_campaign: "https://dana.example", wikipedia_id: "Dana_Demo")
      person.social_media_accounts.create!(platform: "Twitter", channel_type: "Campaign",
                                          url: "https://twitter.com/dana", handle: "dana",
                                          verified: true, research_status: "verified")

      get demographics_assignment_path(assignment)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("https://dana.example")
      expect(response.body).to include("Dana_Demo")
      expect(response.body).to include("https://twitter.com/dana")
      DemographicField::CORE_KEYS.each do |key|
        expect(response.body).to include("values[#{key}]")
        expect(response.body).to include("evidence[#{key}][status]")
      end
    end

    it "starts a pending assignment on first view" do
      expect { get demographics_assignment_path(assignment) }
        .to change { assignment.reload.status }.from("pending").to("in_progress")
    end

    it "surfaces a legacy value that isn't in the controlled list, pre-ticked so it survives" do
      # Production holds 31 free-text race variants. They are rendered as their
      # own checked box, so the value round-trips and removing it is an explicit
      # untick rather than a silent side effect of saving.
      person.update!(race: "white, non-Hispanic")

      get demographics_assignment_path(assignment)

      expect(response.body).to include("Currently recorded as")
      expect(response.body).to include("white, non-Hispanic")
      expect(response.body).to include("It is kept as-is unless you change it")
      expect(response.body).to include("non-standard")
    end

    it "does not nag about a value that is in the controlled list" do
      person.update!(race: "White", gender: "Female")

      get demographics_assignment_path(assignment)

      expect(response.body).not_to include("Currently recorded as")
    end

    it "hides a dependent field until its parent answer makes it relevant" do
      get demographics_assignment_path(assignment)
      expect(response.body).not_to include("values[military_branch]")

      person.update!(military_service: "Veteran")
      get demographics_assignment_path(assignment)
      expect(response.body).to include("values[military_branch]")
    end
  end

  describe "saving determinations" do
    it "writes values, records evidence, and moves the rollup to in_progress" do
      patch demographics_assignment_path(assignment), params: {
        values: { gender: "Female", race: ["White", "Hispanic or Latino"] },
        evidence: {
          gender: { status: "verified", source_url: "https://example.com/bio" },
          race:   { status: "verified", notes: "self-described in campaign bio" }
        }
      }

      person.reload
      expect(person.gender).to eq("Female")
      expect(person.race).to eq("White, Hispanic or Latino")
      expect(person.race_values).to contain_exactly("White", "Hispanic or Latino")
      expect(person.demographics_status).to eq("in_progress")
      expect(person.demographic_verification_for(:gender).source_url).to eq("https://example.com/bio")
      expect(person.demographic_verification_for(:gender).verified_by).to eq(researcher)
    end

    it "refuses a verified determination with no source or note, saving nothing" do
      patch demographics_assignment_path(assignment), params: {
        values: { gender: "Male" },
        evidence: { gender: { status: "verified" } }
      }

      expect(response).to have_http_status(:unprocessable_entity)
      expect(person.reload.gender).to be_nil
      expect(person.demographic_verifications).to be_empty
      expect(response.body).to include("needs a source link or a note")
    end

    it "refuses 'verified' on an empty value and points at the right status instead" do
      patch demographics_assignment_path(assignment), params: {
        values: { marital_status: "" },
        evidence: { marital_status: { status: "verified", source_url: "https://example.com" } }
      }

      expect(response).to have_http_status(:unprocessable_entity)
      expect(response.body).to include("Not publicly documented")
    end

    it "accepts 'not publicly documented' with no value — an absent answer is still an answer" do
      patch demographics_assignment_path(assignment), params: {
        evidence: { birth_date: { status: "unknown", notes: "no DOB in any public source" } }
      }

      verification = person.reload.demographic_verification_for(:birth_date)
      expect(verification.status).to eq("unknown")
      expect(verification).to be_settled
    end

    it "clears a dependent value when its parent answer stops applying" do
      person.update!(military_service: "Veteran", military_branch: "Navy")
      person.demographic_verifications.create!(field_key: "military_branch", status: "verified",
                                              verified_by: researcher, verified_at: Time.current)

      patch demographics_assignment_path(assignment), params: {
        values: { military_service: "Never served" },
        evidence: { military_service: { status: "verified", source_url: "https://example.com" } }
      }

      person.reload
      expect(person.military_branch).to be_nil
      expect(person.demographic_verification_for(:military_branch)).to be_nil
    end

    it "leaves an existing determination alone when the field is left blank in this pass" do
      create(:demographic_verification, person: person, field_key: "gender",
                                        status: "verified", source_url: "https://original.example")

      patch demographics_assignment_path(assignment), params: {
        evidence: { race: { status: "unknown", notes: "not stated anywhere" } }
      }

      expect(person.reload.demographic_verification_for(:gender).source_url)
        .to eq("https://original.example")
    end
  end

  # Each of these pins a defect found in review that reached a working state
  # before it was caught.
  describe "regressions" do
    it "keeps a legacy race value that isn't in the controlled list when saving something else" do
      # 462 production people carry a token outside DemographicField::RACES. The
      # multi-select submits values[race] on every save, so recording an unrelated
      # field used to blank their race.
      person.update!(race: "white, non-Hispanic")

      get demographics_assignment_path(assignment)
      expect(response.body).to include("non-standard")

      # Simulate the form round-trip: the legacy token comes back checked.
      patch demographics_assignment_path(assignment), params: {
        values: { gender: "Female", race: ["", "white, non-Hispanic"] },
        evidence: { gender: { status: "verified", source_url: "https://example.com/bio" } }
      }

      expect(person.reload.race).to eq("white, non-Hispanic")
      expect(person.gender).to eq("Female")
    end

    it "still lets a researcher deliberately replace a legacy race value" do
      person.update!(race: "white, non-Hispanic")

      patch demographics_assignment_path(assignment), params: {
        values: { race: ["", "White"] },
        evidence: { race: { status: "verified", source_url: "https://example.com/bio" } }
      }

      expect(person.reload.race).to eq("White")
    end

    it "does not block on a determination for a field the same save made irrelevant" do
      person.update!(military_service: "Veteran", military_branch: "Navy")
      person.demographic_verifications.create!(field_key: "military_branch", status: "verified",
                                              source_url: "https://example.com/vet",
                                              verified_by: researcher, verified_at: Time.current)

      # The form echoes back military_branch's determination while the new
      # military_service answer removes the field entirely.
      patch demographics_assignment_path(assignment), params: {
        values: { military_service: "Never served", military_branch: "" },
        evidence: {
          military_service: { status: "verified", source_url: "https://example.com/none" },
          military_branch:  { status: "verified", source_url: "https://example.com/vet" }
        }
      }

      expect(response).to have_http_status(:found)
      person.reload
      expect(person.military_service).to eq("Never served")
      expect(person.military_branch).to be_nil
      expect(person.demographic_verification_for(:military_branch)).to be_nil
    end

    it "redisplays the evidence the researcher typed when the save is rejected" do
      patch demographics_assignment_path(assignment), params: {
        values: { gender: "Female" },
        evidence: {
          gender: { status: "verified" }, # no source — this is what fails
          race:   { status: "unknown", notes: "checked three bios, nothing stated" }
        }
      }

      expect(response).to have_http_status(:unprocessable_entity)
      # The note on the OTHER field must survive, or the researcher retypes
      # everything to fix one row.
      expect(response.body).to include("checked three bios, nothing stated")
      expect(response.body).to include("Female")
    end

    it "rejects a source URL that isn't a web link" do
      patch demographics_assignment_path(assignment), params: {
        values: { gender: "Female" },
        evidence: { gender: { status: "verified", source_url: "javascript:alert(document.cookie)" } }
      }

      expect(response).to have_http_status(:unprocessable_entity)
      expect(person.reload.demographic_verifications).to be_empty
      expect(response.body).to include("http:// or https://")
    end

    it "clears the reviewer stamp when the last determination is removed" do
      settle_all!
      expect(person.reload.demographics_reviewed_at).to be_present

      person.demographic_verifications.destroy_all
      person.refresh_demographics_status!

      person.reload
      expect(person.demographics_status).to eq("not_started")
      expect(person.demographics_reviewed_at).to be_nil
      expect(person.demographics_reviewed_by).to be_nil
    end
  end

  describe "completion" do
    it "is blocked while any required field is unsettled, and says which" do
      patch complete_demographics_assignment_path(assignment)

      expect(assignment.reload.status).not_to eq("completed")
      expect(flash[:alert]).to include("still need a determination")
      expect(flash[:alert]).to include("Gender")
    end

    it "does not count a value with no determination as settled" do
      person.update!(gender: "Female", race: "White", birth_date: Date.new(1970, 1, 1),
                     marital_status: "Married", children_status: "No children",
                     education_level: "Bachelor's degree",
                     education_type: "Public university or college",
                     military_service: "Never served")

      patch complete_demographics_assignment_path(assignment)

      expect(assignment.reload.status).not_to eq("completed")
    end

    it "completes once every required field is settled and marks the person complete" do
      settle_all!

      patch complete_demographics_assignment_path(assignment)

      expect(assignment.reload.status).to eq("completed")
      expect(person.reload.demographics_status).to eq("complete")
    end

    it "keeps a disputed field short of complete — it is a request for a second opinion" do
      settle_all!
      person.demographic_verification_for(:gender).update!(status: "disputed", notes: "sources disagree")

      patch complete_demographics_assignment_path(assignment)

      expect(assignment.reload.status).not_to eq("completed")
      expect(person.reload.refresh_demographics_status!).to eq("in_progress")
    end
  end

  describe "access control" do
    it "404s on another researcher's assignment" do
      other = create(:assignment, :demographic_research, user: create(:user, role: "researcher"),
                                  assigned_by: admin, person: create(:person))

      get demographics_assignment_path(other)

      expect(response).to have_http_status(:not_found)
    end

    it "404s on an assignment of a different task type" do
      validation = create(:assignment, user: researcher, person: person, assigned_by: admin)

      get demographics_assignment_path(validation)

      expect(response).to have_http_status(:not_found)
    end
  end
end
