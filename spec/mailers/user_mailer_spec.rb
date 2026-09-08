require 'rails_helper'

# There was no mailer spec at all, which is how the assignment reminder shipped
# broken: the templates call AssignmentHelper, and ActionMailer — unlike
# ActionController — does not auto-include app/helpers. Rendering the body is
# the only thing that catches it.
RSpec.describe UserMailer, type: :mailer do
  let(:admin) { create(:user, :admin) }
  let(:researcher) { create(:user, role: "researcher", name: "Rita Researcher") }

  describe "#assignment_reminder" do
    it "renders both parts for every task type" do
      Assignment::TASK_TYPES.each do |task_type|
        create(:assignment, user: researcher, assigned_by: admin,
                            person: create(:person), task_type: task_type, status: "pending")
      end

      mail = described_class.assignment_reminder(researcher)

      expect { mail.body }.not_to raise_error
      body = mail.body.encoded
      Assignment::TASK_TYPES.each do |task_type|
        expect(body).to include(Assignment::TASK_TYPE_LABELS.fetch(task_type))
      end
      expect(mail.to).to eq([researcher.email])
      expect(mail.subject).to include("4 assignments")
    end

    it "gives each task type its own badge class rather than labelling them all validation" do
      create(:assignment, :demographic_research, user: researcher, assigned_by: admin,
                          person: create(:person), status: "pending")

      body = described_class.assignment_reminder(researcher).body.encoded

      expect(body).to include("badge-demographic_research")
      expect(body).not_to include("Data Validation")
    end

    it "renders the plain-text part too" do
      create(:assignment, :secondary_verification, user: researcher, assigned_by: admin,
                          person: create(:person), status: "pending")

      mail = described_class.assignment_reminder(researcher)
      text_part = mail.text_part&.body&.to_s || mail.body.encoded

      expect(text_part).to include("Secondary Verification")
    end
  end
end
