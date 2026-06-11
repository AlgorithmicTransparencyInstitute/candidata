# Bulk upsert for the election editor grid.
#
# Each row carries person fields + candidate fields + one social handle per
# platform. Rows are processed independently (one transaction per row) so a
# validation failure in one row doesn't lose the rest of the sheet. Results
# are keyed by the client-supplied row key so the grid can update statuses,
# bind new ids, and show per-row errors inline.
#
# Social account rules:
# - new value, no account     -> create (Campaign / entered / unverified)
# - existing account, changed -> update handle+url; verified accounts are
#   flagged research_status=revised + verified=false (re-verification flow)
# - existing account, cleared -> destroy if unverified; verified accounts are
#   never destroyed from the grid (warning returned, value restored client-side)
class ElectionEditorSave
  URL_TEMPLATES = {
    'Facebook'    => 'https://www.facebook.com/%s',
    'Twitter'     => 'https://twitter.com/%s',
    'Instagram'   => 'https://www.instagram.com/%s',
    'YouTube'     => 'https://www.youtube.com/@%s',
    'TikTok'      => 'https://www.tiktok.com/@%s',
    'BlueSky'     => 'https://bsky.app/profile/%s',
    'TruthSocial' => 'https://truthsocial.com/@%s',
    'Gettr'       => 'https://gettr.com/user/%s',
    'Rumble'      => 'https://rumble.com/c/%s',
    'Telegram'    => 'https://t.me/%s',
    'Threads'     => 'https://www.threads.net/@%s'
  }.freeze

  def initialize(election, user)
    @election = election
    @user = user
    @contest_ids = Contest.joins(:ballot).where(ballots: { election_id: election.id }).pluck(:id).to_set
  end

  def call(rows:, deleted_candidate_ids:)
    {
      results: rows.map { |row| save_row(row) },
      deleted: delete_candidates(deleted_candidate_ids)
    }
  end

  private

  def save_row(row)
    key = row[:key]
    errors = []
    warnings = []

    contest_id = row[:contestId].to_i
    errors << 'Contest is required' unless contest_id.positive?
    errors << 'Contest does not belong to this election' if contest_id.positive? && !@contest_ids.include?(contest_id)
    errors << 'First name is required' if row[:firstName].to_s.strip.blank?
    errors << 'Last name is required' if row[:lastName].to_s.strip.blank?
    return { key: key, ok: false, errors: errors } if errors.any?

    person = nil
    candidate = nil
    socials = {}

    ActiveRecord::Base.transaction do
      person = upsert_person(row)
      candidate = upsert_candidate(row, person, contest_id)
      socials = upsert_socials(row, person, warnings)
    end

    {
      key: key,
      ok: true,
      candidateId: candidate.id,
      personId: person.id,
      socials: socials,
      warnings: warnings
    }
  rescue ActiveRecord::RecordInvalid => e
    { key: key, ok: false, errors: e.record.errors.full_messages }
  rescue ActiveRecord::RecordNotFound => e
    { key: key, ok: false, errors: [e.message] }
  end

  def upsert_person(row)
    person = row[:personId].present? ? Person.find(row[:personId]) : Person.new

    person.first_name = row[:firstName].to_s.strip
    person.last_name = row[:lastName].to_s.strip
    person.gender = row[:gender].presence if row.key?(:gender)
    person.race = row[:race].presence if row.key?(:race)
    person.state_of_residence ||= @election.state
    person.save! if person.changed? || person.new_record?
    person
  end

  def upsert_candidate(row, person, contest_id)
    candidate = Candidate.find_or_initialize_by(person_id: person.id, contest_id: contest_id)
    candidate.outcome = row[:outcome].presence || 'pending'
    candidate.party_at_time = row[:party].presence
    candidate.incumbent = ActiveModel::Type::Boolean.new.cast(row[:incumbent]) || false
    candidate.save! if candidate.changed? || candidate.new_record?
    candidate
  end

  def upsert_socials(row, person, warnings)
    results = {}
    (row[:socials] || {}).each do |platform, cell|
      next unless SocialMediaAccount::PLATFORMS.include?(platform)

      account_id = cell[:accountId].presence
      normalized = normalize_social(platform, cell[:value])
      account = account_id ? person.social_media_accounts.find_by(id: account_id) : nil

      if account
        results[platform] = update_account(account, platform, normalized, warnings)
      elsif normalized
        results[platform] = create_account(person, platform, normalized)
      end
    end
    results
  end

  def update_account(account, platform, normalized, warnings)
    if normalized.nil?
      if account.verified
        warnings << "#{platform}: verified accounts can't be removed from the grid — value restored"
        return account_cell(account)
      end
      account.destroy!
      return nil
    end

    return account_cell(account) if account.handle == normalized[:handle] && account.url == normalized[:url]

    was_verified = account.verified
    account.assign_attributes(
      handle: normalized[:handle],
      url: normalized[:url],
      entered_by: @user,
      entered_at: Time.current
    )
    if was_verified
      account.verified = false
      account.research_status = 'revised'
      warnings << "#{platform}: was verified — changed value will need re-verification"
    else
      account.research_status = 'entered'
    end
    account.save!
    account_cell(account)
  end

  def create_account(person, platform, normalized)
    account = person.social_media_accounts.find_or_initialize_by(platform: platform, handle: normalized[:handle])
    account.url = normalized[:url] if account.url.blank?
    if account.new_record?
      account.channel_type = 'Campaign'
      account.research_status = 'entered'
      account.entered_by = @user
      account.entered_at = Time.current
    end
    account.save!
    account_cell(account)
  end

  def account_cell(account)
    { accountId: account.id, handle: account.handle, url: account.url, verified: account.verified }
  end

  # Accepts "@handle", "handle", or a full profile URL; returns {handle:, url:}.
  def normalize_social(platform, raw)
    value = raw.to_s.strip
    return nil if value.blank?

    if value.match?(%r{\Ahttps?://}i)
      handle = handle_from_url(platform, value)
      { handle: handle, url: value }
    else
      handle = value.delete_prefix('@').strip
      { handle: handle, url: format(URL_TEMPLATES[platform], handle) }
    end
  end

  def handle_from_url(platform, url)
    path = URI.parse(url).path.to_s
    segments = path.split('/').reject(&:blank?)
    return nil if segments.empty?

    segment =
      case platform
      when 'BlueSky' then segments[segments.index('profile').to_i + 1] || segments.last
      when 'Gettr'   then segments[segments.index('user').to_i + 1] || segments.last
      when 'Rumble'  then segments[segments.index('c').to_i + 1] || segments.last
      else segments.last
      end
    segment.to_s.delete_prefix('@').presence
  rescue URI::InvalidURIError
    nil
  end

  def delete_candidates(ids)
    return [] if ids.blank?

    Candidate.where(id: ids, contest_id: @contest_ids.to_a).destroy_all.map(&:id)
  end
end
