class UserMailer < ApplicationMailer
  def assignment_reminder(user)
    @user = user
    @incomplete_assignments = user.assignments.where(status: [ 'pending', 'in_progress' ])
                                   .includes(person: [ :party_affiliation, :officeholders, :candidates ])
                                   .order(created_at: :asc)

    mail(
      to: @user.email,
      subject: "Reminder: You have #{@incomplete_assignments.count} #{'assignment'.pluralize(@incomplete_assignments.count)} to complete"
    )
  end
end
