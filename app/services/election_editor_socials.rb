# Picks the one account per platform the election editor grid displays/edits:
# prefer Campaign accounts, then Official Office, then Personal, and within a
# tier prefer accounts that actually have a handle or URL. Works off loaded
# associations only — no extra queries.
#
# Shared by ElectionEditorController (page payload, people typeahead) and
# ElectionEditorCsvImport (prefill for matched people).
module ElectionEditorSocials
  CHANNEL_PRIORITY = ['Campaign', 'Official Office', 'Personal', nil].freeze

  module_function

  def map(person)
    person.social_media_accounts.group_by(&:platform).transform_values do |accounts|
      account = accounts.min_by do |a|
        [CHANNEL_PRIORITY.index(a.channel_type) || 99, a.handle.present? || a.url.present? ? 0 : 1]
      end
      {
        accountId: account.id,
        handle: account.handle,
        url: account.url,
        verified: account.verified
      }
    end
  end
end
