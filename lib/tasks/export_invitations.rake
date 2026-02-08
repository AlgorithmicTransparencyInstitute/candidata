namespace :invitations do
  desc "Export all pending invitation links to CSV"
  task export: :environment do
    require 'csv'

    # Find all users with pending invitations
    pending_users = User.where.not(invitation_token: nil)
                       .where(invitation_accepted_at: nil)
                       .order(:created_at)

    if pending_users.empty?
      puts "No pending invitations found."
      exit
    end

    # Generate CSV filename with timestamp
    timestamp = Time.current.strftime("%Y%m%d_%H%M%S")
    filename = Rails.root.join("tmp", "pending_invitations_#{timestamp}.csv")

    # Ensure tmp directory exists
    FileUtils.mkdir_p(Rails.root.join("tmp"))

    # Generate CSV
    CSV.open(filename, "w") do |csv|
      csv << ["Email", "Name", "Role", "Invitation URL", "Invited At", "Days Pending"]

      pending_users.each do |user|
        # Generate the invitation acceptance URL
        # This uses the Rails URL helpers to generate the proper URL
        invitation_url = Rails.application.routes.url_helpers.accept_user_invitation_url(
          invitation_token: user.invitation_token,
          host: ENV['MAILER_HOST'] || 'candidata-104991311c5c.herokuapp.com',
          protocol: 'https'
        )

        days_pending = if user.invitation_created_at
                        ((Time.current - user.invitation_created_at) / 1.day).round(1)
                      else
                        "N/A"
                      end

        csv << [
          user.email,
          user.name || "",
          user.role,
          invitation_url,
          user.invitation_created_at&.strftime("%Y-%m-%d %H:%M"),
          days_pending
        ]
      end
    end

    puts "✓ Exported #{pending_users.count} pending invitation(s) to:"
    puts "  #{filename}"
    puts ""
    puts "Summary:"
    puts "  - Total pending invitations: #{pending_users.count}"
    puts "  - Admin invitations: #{pending_users.where(role: 'admin').count}"
    puts "  - Researcher invitations: #{pending_users.where(role: 'researcher').count}"
    puts ""
    puts "You can now share these invitation links manually via email or Slack."
  end

  desc "Resend invitation emails to all pending invitations"
  task resend_all: :environment do
    pending_users = User.where.not(invitation_token: nil)
                       .where(invitation_accepted_at: nil)
                       .order(:created_at)

    if pending_users.empty?
      puts "No pending invitations found."
      exit
    end

    puts "Resending #{pending_users.count} invitation email(s)..."
    puts ""

    pending_users.each do |user|
      begin
        user.invite!
        puts "✓ Resent invitation to #{user.email}"
      rescue => e
        puts "✗ Failed to resend to #{user.email}: #{e.message}"
      end
    end

    puts ""
    puts "Done!"
  end
end
