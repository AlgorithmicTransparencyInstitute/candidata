class CustomDeviseMailer < Devise::Mailer
  helper :application
  include Devise::Controllers::UrlHelpers
  include DeviseInvitable::Mailer if defined?(DeviseInvitable)

  layout "mailer"

  default from: "Candidata <noreply@candidata.space>"
  default template_path: "devise/mailer"

  def invitation_instructions(record, token, opts = {})
    # Use custom subject if provided, otherwise use default
    opts[:subject] ||= "Your CandiData Account Access"
    super
  end
end
