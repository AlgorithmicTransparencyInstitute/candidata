# Picks the one account per platform the election editor grid displays/edits:
# prefer accounts that actually have a handle or URL over blank pre-populated
# stubs, then within that prefer Campaign, then Official Office, then Personal.
# (Content-first ordering keeps a blank Campaign stub from shadowing a real
# handle held on another channel.) Works off loaded associations only — no
# extra queries.
#
# Shared by ElectionEditorController (page payload, people typeahead) and
# ElectionEditorCsvImport (prefill for matched people).
module ElectionEditorSocials
  CHANNEL_PRIORITY = ['Campaign', 'Official Office', 'Personal', nil].freeze

  module_function

  def map(person)
    person.social_media_accounts.group_by(&:platform).transform_values do |accounts|
      account = accounts.min_by do |a|
        [a.handle.present? || a.url.present? ? 0 : 1, CHANNEL_PRIORITY.index(a.channel_type) || 99]
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
