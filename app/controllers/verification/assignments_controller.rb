module Verification
  class AssignmentsController < ApplicationController
    before_action :authenticate_user!
    before_action :require_researcher_or_admin
    layout 'researcher'
    before_action :set_assignment, only: [:show, :start, :complete, :reopen]

    def index
      @assignments = current_user.assignments.verification_tasks.active.includes(person: :social_media_accounts).order(created_at: :asc)
    end

    def show
      @person = @assignment.person
      if @assignment.task_type == 'secondary_verification'
        @flagged_remaining = @person.social_media_accounts.needs_secondary_verification.count
      end
      # Group all accounts by channel_type, regardless of verification status
      @campaign_accounts = @person.social_media_accounts.campaign.order(:platform)
      @official_accounts = @person.social_media_accounts.official.order(:platform)
      @personal_accounts = @person.social_media_accounts.personal.order(:platform)
      @current_offices = @person.officeholders.current.includes(office: [:body, :district])
      @candidacies = @person.candidates.includes(contest: [:ballot, :office]).order('contests.date DESC')
    end

    def start
      @assignment.start!
      redirect_to verification_assignment_path(@assignment), notice: "Verification started."
    end

    # Completion gate: only accounts the completer is ALLOWED to verify block
    # completion (four-eyes rule — you can't resolve your own entries, so they
    # don't trap you). Self-entered leftovers are flagged for secondary
    # verification so another user picks them up via the admin queue.
    def complete
      if @assignment.task_type == 'secondary_verification'
        complete_secondary_verification
      else
        complete_data_validation
      end
    end

    def reopen
      @assignment.reopen!
      redirect_to verification_assignment_path(@assignment), notice: "Verification reopened."
    end

    private

    def complete_data_validation
      pending = @assignment.person.social_media_accounts.needs_verification.to_a
      blocking = pending.select { |account| account.verifiable_by?(current_user) }

      if blocking.any?
        redirect_to verification_assignment_path(@assignment), alert: "#{blocking.size} accounts still need verification."
        return
      end

      @assignment.complete!

      leftover = pending - blocking # accounts the completer entered (non-admin)
      if leftover.any?
        SocialMediaAccount.where(id: leftover.map(&:id)).update_all(needs_secondary_verification: true)
        @assignment.person.update!(needs_secondary_verification: true)
      end

      # Flag accounts whose existing data was modified during validation
      @assignment.person.mark_for_secondary_verification_if_needed!

      notice = if leftover.any?
        "Verification completed! #{leftover.size} #{'account'.pluralize(leftover.size)} you added will be verified by another user."
      else
        "Verification completed!"
      end
      redirect_to verification_queue_path, notice: notice
    end

    # Completion requires an explicit per-account sign-off: every flagged
    # account must have been individually confirmed (AccountsController#confirm_secondary
    # clears its flag). Completing then just clears the person-level flag.
    def complete_secondary_verification
      remaining = @assignment.person.social_media_accounts.needs_secondary_verification.count
      if remaining > 0
        redirect_to verification_assignment_path(@assignment),
                    alert: "#{remaining} flagged #{'account'.pluralize(remaining)} still need to be confirmed — click \"Confirm Verified\" on each flagged account."
        return
      end

      @assignment.complete!
      @assignment.person.clear_secondary_verification!
      redirect_to verification_queue_path, notice: "Secondary verification completed!"
    end

    def set_assignment
      @assignment = current_user.assignments.verification_tasks.find(params[:id])
    end

    def require_researcher_or_admin
      unless current_user.researcher? || current_user.admin?
        redirect_to root_path, alert: "You don't have access to this area."
      end
    end
  end
end
