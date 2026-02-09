module Verification
  class AccountsController < ApplicationController
    before_action :authenticate_user!
    before_action :require_researcher_or_admin
    layout 'researcher'
    before_action :set_account
    before_action :verify_assignment

    def show
      @person = @account.person
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
      # This allows editing AND verifying in one action
      # Update the data
      url_changed = @account.url != account_params[:url]
      handle_changed = @account.handle != account_params[:handle]

      if url_changed || handle_changed
        @account.url = account_params[:url]
        @account.handle = account_params[:handle]
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
      handle = params[:handle]&.strip

      if url.blank? && handle.blank?
        redirect_to verification_assignment_path(@assignment), alert: "Please provide a URL or handle."
        return
      end

      @account.mark_entered!(current_user, url: url, handle: handle)

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

    def reject
      notes = params[:notes]&.strip
      if notes.blank?
        redirect_to verification_account_path(@account), alert: "Please provide a reason for rejection."
        return
      end

      @account.reject!(current_user, notes: notes)
      redirect_to verification_assignment_path(@assignment), notice: "Account rejected."
    end

    private

    def set_account
      @account = SocialMediaAccount.find(params[:id])
    end

    def verify_assignment
      @assignment = current_user.assignments.data_validation.active.find_by(person_id: @account.person_id)
      unless @assignment
        redirect_to verification_assignments_path, alert: "You don't have an active verification assignment for this person."
      end
    end

    def account_params
      params.require(:social_media_account).permit(:url, :handle, :verification_notes)
    end

    def require_researcher_or_admin
      unless current_user.researcher? || current_user.admin?
        redirect_to root_path, alert: "You don't have access to this area."
      end
    end
  end
end
