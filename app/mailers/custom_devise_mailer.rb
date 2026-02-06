class CustomDeviseMailer < Devise::Mailer
  helper :application
  include Devise::Controllers::UrlHelpers

  layout "mailer"

  default from: "Candidata <noreply@candidata.space>"
  default template_path: "devise/mailer"
end
