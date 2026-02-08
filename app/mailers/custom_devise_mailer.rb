class CustomDeviseMailer < Devise::Mailer
  helper :application
  include Devise::Controllers::UrlHelpers
  include DeviseInvitable::Mailer if defined?(DeviseInvitable)

  layout "mailer"

  default from: "Candidata <noreply@candidata.space>"
  default template_path: "devise/mailer"

  def invitation_instructions(record, token, opts = {})
    # Use a simple, professional subject line that's less likely to be flagged as spam
    opts[:subject] = "Your CandiData Account Access"
    super
  end
end
