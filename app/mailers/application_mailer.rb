class ApplicationMailer < ActionMailer::Base
  default from: "Candidata <noreply@candidata.space>"
  layout "mailer"

  # ActionMailer does NOT auto-include app/helpers the way ActionController
  # does — each helper has to be declared. Mailer templates render task types,
  # so AssignmentHelper has to be here or assignment_reminder raises
  # NoMethodError at delivery time. Pinned by spec/mailers/user_mailer_spec.rb.
  helper AssignmentHelper
end
