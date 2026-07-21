module Verification
  class AccountsController < ApplicationController
    before_action :authenticate_user!
    before_action :require_researcher_or_admin
    layout 'researcher'
    before_action :set_account, except: [:create]
    before_action :verify_assignment, except: [:create]
    before_action :verify_assignment_for_create, only: [:create]

    def show
      @person = @account.person
    end

    def create
      @person = Person.find(params[:person_id])
      @account = @person.social_media_accounts.build(create_account_params)
      @account.entered_by = current_user
      @account.entered_at = Time.current
      @account.research_status = 'entered'

      if @account.save
        respond_to do |format|
          format.turbo_stream
          format.html { redirect_to verification_assignment_path(@assignment), notice: "Account added successfully." }
        end
      else
        respond_to do |format|
          format.turbo_stream { render turbo_stream: turbo_stream.replace("add-account-form-#{params[:channel_type]}", partial: "verification/accounts/add_form", locals: { person: @person, channel_type: params[:channel_type], account: @account }) }
          format.html { redirect_to verification_assignment_path(@assignment), alert: @account.errors.full_messages.join(", ") }
        end
      end
    end

    def update
      # Check if this is a revision (data was changed)
      url_changed = @account.url != account_params[:url]
      handle_changed = @account.handle != account_params[:handle]

      if url_changed || handle_changed
        # This is a revision - mark as revised and needs re-verification
        @account.revise!(
          current_user,
          url: account_params[:url],
          handle: account_params[:handle],
          notes: account_params[:verification_notes]
        )
        redirect_to verification_assignment_path(@assignment),
                    notice: "Account revised. This record will be re-queued for verification by another user."
      else
        # Just updating notes without changing data
        if @account.update(account_params)
          redirect_to verification_assignment_path(@assignment), notice: "Account updated."
        else
          render :show, status: :unprocessable_entity
        end
      end
    end

    def edit
      @person = @account.person
    end

    def verify_with_changes
      return unless enforce_four_eyes!

      # This allows editing AND verifying in one action
      # Update the data
      url_changed = @account.url != account_params[:url]

      if url_changed
        @account.url = account_params[:url]
        @account.handle = nil
      end

      # Mark as verified with validation source
      @account.verified_by = current_user
      @account.verified_at = Time.current
      @account.research_status = 'verified'
      @account.verified = true
      @account.verification_notes = account_params[:verification_notes]
      @account.validation_source = params[:validation_source] # Track where they verified it (Google, website, etc.)

      if @account.save
        redirect_to verification_assignment_path(@assignment), notice: "Account updated and verified."
      else
        @person = @account.person
        render :edit, status: :unprocessable_entity
      end
    end

    def mark_entered
      url = params[:url]&.strip

      if url.blank?
        redirect_to verification_assignment_path(@assignment), alert: "Please provide a URL."
        return
      end

      @account.mark_entered!(current_user, url: url, handle: nil)

      respond_to do |format|
        format.turbo_stream
        format.html { redirect_to verification_assignment_path(@assignment), notice: "Account data saved. Needs re-verification." }
      end
    end

    def mark_not_found
      @account.mark_not_found!(current_user)

      respond_to do |format|
        format.turbo_stream
        format.html { redirect_to verification_assignment_path(@assignment), notice: "Account marked as not found." }
      end
    end

    def reset_status
      @account.reset_status!(current_user)

      respond_to do |format|
        format.turbo_stream
        format.html { redirect_to verification_assignment_path(@assignment), notice: "Account status reset." }
      end
    end

    def verify
      return unless enforce_four_eyes!

      @account.verify!(current_user, notes: nil)

      respond_to do |format|
        format.turbo_stream
        format.html { redirect_to verification_assignment_path(@assignment), notice: "Account verified." }
      end
    end

    def unverify
      # Unverify the account - revert to entered or not_found state
      previous_status = if @account.url.present? || @account.handle.present?
        'entered'
      elsif @account.research_status == 'verified'
        # If it was marked as verified "not found", go back to not_found
        'not_found'
      else
        'entered'
      end

      @account.update!(
        research_status: previous_status,
        verified: false,
        verified_by: nil,
        verified_at: nil
      )

      respond_to do |format|
        format.turbo_stream
        format.html { redirect_to verification_assignment_path(@assignment), notice: "Account unverified - you can now edit it." }
      end
    end

    # Per-account secondary-verification sign-off. Secondary verification IS
    # the re-verification of accounts changed during validation — confirming
    # verifies the account (if it isn't already) AND clears the flag in one
    # step; no second validation cycle. Four-eyes still applies: the account's
    # enterer/modifier can't confirm it (their leftovers hand off to the next
    # cycle on completion instead). The assignment can only be completed once
    # every flagged account the user may act on has been confirmed
    # (see AssignmentsController#complete_secondary_verification).
    # Full-page redirect (turbo: false on the button) so the flagged-remaining
    # count and the completion button state refresh together.
    def confirm_secondary
      unless @account.needs_secondary_verification?
        redirect_to verification_assignment_path(@assignment), alert: "This account isn't flagged for secondary verification."
        return
      end

      return unless enforce_four_eyes!

      @account.verify!(current_user) if @account.needs_verification?
      @account.clear_secondary_verification!
      remaining = @account.person.social_media_accounts.needs_secondary_verification.count
      notice = if remaining.zero?
        "#{@account.platform} confirmed. All flagged accounts are confirmed — you can now complete the assignment."
      else
        "#{@account.platform} confirmed. #{remaining} flagged #{'account'.pluralize(remaining)} remaining."
      end
      redirect_to verification_assignment_path(@assignment), notice: notice
    end

    # Deactivated toggle: URL is kept — the account just isn't live on the
    # platform anymore (e.g. candidate lost and shut it down). Distinct from
    # "not found", which clears the data.
    def toggle_deactivated
      @account.toggle_deactivated!
      notice = @account.account_inactive? ? "#{@account.platform} marked deactivated — URL kept, account excluded from active data." : "#{@account.platform} reactivated."
      redirect_to verification_assignment_path(@assignment), notice: notice
    end

    # Escalation toggle: flags the account for admin review (add notes!).
    def toggle_escalated
      @account.toggle_escalated!(current_user)
      notice = @account.escalated_for_review? ? "#{@account.platform} escalated for admin review — please add notes explaining why." : "#{@account.platform} escalation removed."
      redirect_to verification_assignment_path(@assignment), notice: notice
    end

    def reject
      notes = params[:notes]&.strip
      if notes.blank?
        redirect_to verification_account_path(@account), alert: "Please provide a reason for rejection."
        return
      end

      @account.reject!(current_user, notes: notes)
      redirect_to verification_assignment_path(@assignment), notice: "Account rejected."
    end

    def update_notes
      @account.update!(research_notes: params[:research_notes])
      respond_to do |format|
        format.html { redirect_to verification_assignment_path(@assignment), notice: "Notes saved." }
        format.any { head :ok }
      end
    end

    private

    def set_account
      @account = SocialMediaAccount.find(params[:id])
    end

    # Four-eyes rule: you can't verify what you entered (admins exempt).
    def enforce_four_eyes!
      return true if @account.verifiable_by?(current_user)

      redirect_to verification_assignment_path(@assignment),
                  alert: "You entered this account — another user must verify it. It will be flagged for secondary verification when you complete this task."
      false
    end

    def verify_assignment
      @assignment = current_user.assignments.verification_tasks.active.find_by(person_id: @account.person_id)
      unless @assignment
        redirect_to verification_assignments_path, alert: "You don't have an active verification assignment for this person."
      end
    end

    def account_params
      params.require(:social_media_account).permit(:url, :handle, :verification_notes)
    end

    def create_account_params
      params.require(:social_media_account).permit(:platform, :channel_type, :url, :research_notes)
    end

    def verify_assignment_for_create
      person = Person.find(params[:person_id])
      @assignment = current_user.assignments.verification_tasks.active.find_by(person_id: person.id)
      unless @assignment
        redirect_to verification_assignments_path, alert: "You don't have an active verification assignment for this person."
      end
    end

    def require_researcher_or_admin
      unless current_user.researcher? || current_user.admin?
        redirect_to root_path, alert: "You don't have access to this area."
      end
    end
  end
end
