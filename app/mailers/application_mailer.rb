class ApplicationMailer < ActionMailer::Base
  default from: ENV.fetch('DEVISE_MAILER_FROM', 'noreply@candidata.org')
  layout "mailer"
end
