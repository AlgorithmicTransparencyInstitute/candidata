class AddChannelToDefaultListJob < ApplicationJob
  queue_as :default

  retry_on JunkipediaService::JunkipediaError, wait: :polynomially_longer, attempts: 5

  def perform(social_media_account_id)
    list_id = ENV['JUNKIPEDIA_DEFAULT_LIST_ID']
    return if list_id.blank?

    account = SocialMediaAccount.find_by(id: social_media_account_id)
    return unless account
    return if account.junkipedia_channel_id.blank?

    JunkipediaService.new.add_channels_to_list(
      list_id: list_id,
      channel_ids: [account.junkipedia_channel_id]
    )
  rescue JunkipediaService::JunkipediaError => e
    account&.update_columns(junkipedia_last_error: e.message.truncate(1000))
    raise
  end
end
