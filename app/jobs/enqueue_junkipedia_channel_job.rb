class EnqueueJunkipediaChannelJob < ApplicationJob
  queue_as :default

  retry_on JunkipediaService::JunkipediaError, wait: :polynomially_longer, attempts: 5

  def perform(social_media_account_id, force: false)
    account = SocialMediaAccount.find_by(id: social_media_account_id)
    return unless account
    return unless eligible?(account)
    return if account.junkipedia_enqueued_at.present? && !force

    service = JunkipediaService.new
    response = service.enqueue_channel(url: account.url)

    immediate_channel_id = JunkipediaService.extract_channel_id(response)
    now = Time.current

    updates = {
      junkipedia_enqueued_at: now,
      junkipedia_last_error: nil
    }
    if immediate_channel_id.present?
      updates[:junkipedia_channel_id] = immediate_channel_id
      updates[:junkipedia_id_collected_at] = now
    end
    account.update_columns(updates)

    if immediate_channel_id.present? && ENV['JUNKIPEDIA_DEFAULT_LIST_ID'].present?
      AddChannelToDefaultListJob.perform_later(account.id)
    end
  rescue JunkipediaService::JunkipediaError => e
    account&.update_columns(junkipedia_last_error: e.message.truncate(1000))
    raise
  end

  private

  def eligible?(account)
    JunkipediaService.supported_platform?(account.platform) &&
      account.url.present? &&
      !account.account_inactive?
  end
end
