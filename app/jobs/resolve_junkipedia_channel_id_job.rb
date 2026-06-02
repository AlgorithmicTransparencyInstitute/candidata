class ResolveJunkipediaChannelIdJob < ApplicationJob
  queue_as :default

  retry_on JunkipediaService::JunkipediaError, wait: :polynomially_longer, attempts: 5

  def perform(social_media_account_id, force: false)
    account = SocialMediaAccount.find_by(id: social_media_account_id)
    return unless account
    return if account.junkipedia_channel_id.present? && !force
    return unless account.url.present? || account.handle.present?

    service = JunkipediaService.new
    response = service.search_channel(
      url: account.url,
      handle: account.handle,
      platform: JunkipediaService.junkipedia_platform(account.platform)
    )

    channel_id = JunkipediaService.first_channel_id(response)
    return unless channel_id.present?

    now = Time.current
    updates = {
      junkipedia_channel_id: channel_id,
      junkipedia_id_collected_at: now,
      junkipedia_last_error: nil
    }
    # If we found the channel without ever having enqueued (e.g. it was pushed
    # via an earlier rake task), stamp enqueued_at too so the record reads as
    # fully synced rather than half-tracked.
    updates[:junkipedia_enqueued_at] = now if account.junkipedia_enqueued_at.nil?

    account.update_columns(updates)

    if ENV['JUNKIPEDIA_DEFAULT_LIST_ID'].present?
      AddChannelToDefaultListJob.perform_later(account.id)
    end
  rescue JunkipediaService::JunkipediaError => e
    account&.update_columns(junkipedia_last_error: e.message.truncate(1000))
    raise
  end
end
