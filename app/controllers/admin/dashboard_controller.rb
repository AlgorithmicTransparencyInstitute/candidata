class Admin::DashboardController < Admin::BaseController
  def index
    # Data counts
    @data_counts = {
      people: Person.count,
      offices: Office.count,
      parties: Party.count,
      contests: Contest.count,
      ballots: Ballot.count,
      candidates: Candidate.count,
      officeholders: Officeholder.count,
      social_media_accounts: SocialMediaAccount.count
    }

    # Assignment stats
    @assignment_stats = {
      total: Assignment.count,
      pending: Assignment.pending.count,
      in_progress: Assignment.in_progress.count,
      completed: Assignment.completed.count,
      research_pending: Assignment.research.pending.count,
      verification_pending: Assignment.verification.pending.count
    }

    # Research workflow stats
    @research_stats = {
      accounts_total: SocialMediaAccount.campaign.count,
      accounts_pending: SocialMediaAccount.campaign.where(research_status: ['pending', nil]).count,
      accounts_entered: SocialMediaAccount.campaign.where(research_status: 'entered').count,
      accounts_verified: SocialMediaAccount.campaign.where(research_status: 'verified').count,
      accounts_rejected: SocialMediaAccount.campaign.where(research_status: 'rejected').count
    }

    # Users
    @users = User.all
    @researchers = User.where(role: 'researcher')

    # Recent assignments
    @recent_assignments = Assignment.includes(:user, :person, :assigned_by)
                                    .order(created_at: :desc)
                                    .limit(10)

    # People needing assignment
    @unassigned_people = Person.left_joins(:assignments)
                               .where(assignments: { id: nil })
                               .limit(10)
  end
end
