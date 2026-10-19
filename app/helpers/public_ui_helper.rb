# Shared building blocks for the public site (layouts/public). One place for
# page titles/meta, avatars, party badges and outcome chips, so every page
# renders them the same way.
module PublicUiHelper
  SITE_NAME = 'CandiData'.freeze
  DEFAULT_DESCRIPTION = 'Verified social media accounts, offices and 2026 races for U.S. elected officials ' \
                        'and candidates, from the Algorithmic Transparency Institute.'.freeze

  # Tile-grid US map positions: state => [column, row] on a 12x8 grid
  # (the common NPR-style layout). Used by public/_state_tile_map.
  STATE_TILES = {
    'AK' => [0, 0], 'ME' => [11, 0],
    'WI' => [6, 1], 'VT' => [10, 1], 'NH' => [11, 1],
    'WA' => [1, 2], 'ID' => [2, 2], 'MT' => [3, 2], 'ND' => [4, 2], 'MN' => [5, 2], 'IL' => [6, 2],
    'MI' => [7, 2], 'NY' => [9, 2], 'MA' => [10, 2],
    'OR' => [1, 3], 'NV' => [2, 3], 'WY' => [3, 3], 'SD' => [4, 3], 'IA' => [5, 3], 'IN' => [6, 3],
    'OH' => [7, 3], 'PA' => [8, 3], 'NJ' => [9, 3], 'CT' => [10, 3], 'RI' => [11, 3],
    'CA' => [1, 4], 'UT' => [2, 4], 'CO' => [3, 4], 'NE' => [4, 4], 'MO' => [5, 4], 'KY' => [6, 4],
    'WV' => [7, 4], 'VA' => [8, 4], 'MD' => [9, 4], 'DE' => [10, 4],
    'AZ' => [2, 5], 'NM' => [3, 5], 'KS' => [4, 5], 'AR' => [5, 5], 'TN' => [6, 5], 'NC' => [7, 5],
    'SC' => [8, 5], 'DC' => [9, 5],
    'OK' => [4, 6], 'LA' => [5, 6], 'MS' => [6, 6], 'AL' => [7, 6], 'GA' => [8, 6],
    'HI' => [0, 7], 'TX' => [4, 7], 'FL' => [9, 7]
  }.freeze

  # Page <title> and meta description. Call from a view:
  #   <% page_meta title: @person.full_name, description: "..." %>
  def page_meta(title: nil, description: nil, image: nil)
    content_for(:page_title, title) if title
    content_for(:page_description, description) if description
    content_for(:page_image, image) if image
  end

  def full_page_title
    title = content_for(:page_title)
    title.present? ? "#{title} · #{SITE_NAME}" : "#{SITE_NAME} — U.S. officials and candidates"
  end

  def page_description
    content_for(:page_description).presence || DEFAULT_DESCRIPTION
  end

  def nav_link_to(label, path, active: nil)
    active = request.path.start_with?(path) if active.nil?
    classes = active ? 'text-brand-700 bg-brand-50' : 'text-ink-muted hover:text-ink hover:bg-surface'
    link_to label, path, class: "#{classes} rounded-md px-3 py-2 text-sm font-medium",
                         'aria-current': (active ? 'page' : nil)
  end

  # Photo over an initials fallback. Many photo URLs are hot-linked from
  # official sites that block it (403), so a failed image removes itself and
  # the initials underneath show through.
  def person_avatar(person, size: 'size-12', text: 'text-base', rounded: 'rounded-full')
    initials = [person.first_name, person.last_name].compact_blank.map { |n| n[0] }.join.upcase
    content_tag :span, class: "#{size} #{rounded} #{text} relative shrink-0 inline-flex items-center justify-center " \
                              'overflow-hidden bg-line text-ink-muted font-semibold' do
      parts = [content_tag(:span, initials, 'aria-hidden': true)]
      if person.photo_url.present?
        parts << image_tag(person.photo_url, alt: '', loading: 'lazy', referrerpolicy: 'no-referrer',
                                             onerror: 'this.remove()', class: 'absolute inset-0 size-full object-cover')
      end
      safe_join(parts)
    end
  end

  # Party colour appears only here, as a small badge: the label always
  # carries the meaning, colour is secondary.
  def party_badge(party_name, short: false)
    return if party_name.blank?

    name = party_name.to_s.delete_suffix(' Party')
    tone = case name
           when /\ADemocrat/ then 'bg-party-dem-bg text-party-dem'
           when /\ARepublican/ then 'bg-party-rep-bg text-party-rep'
           else 'bg-party-other-bg text-party-other'
           end
    label = short ? party_abbrev(name) : name
    content_tag :span, label, title: (short ? name : nil),
                class: "#{tone} inline-flex items-center rounded px-1.5 py-0.5 text-xs font-semibold"
  end

  def party_abbrev(name)
    case name
    when /\ADemocrat/ then 'D'
    when /\ARepublican/ then 'R'
    when /\AIndependent\z/ then 'I'
    when /\ALibertarian/ then 'L'
    when /\AGreen/ then 'G'
    else name.split.map { |w| w[0] }.join.first(3).upcase
    end
  end

  OUTCOME_LABELS = {
    'won' => 'Won', 'advanced' => 'Advanced', 'lost' => 'Lost',
    'pending' => 'On ballot', 'withdrawn' => 'Withdrew', 'unknown' => 'Result unknown'
  }.freeze

  def outcome_chip(outcome)
    return if outcome.blank?

    tone = case outcome
           when *Candidate::WINNING_OUTCOMES then 'bg-status-won-bg text-status-won'
           when 'pending' then 'bg-brand-50 text-brand-700'
           else 'bg-surface text-ink-muted ring-1 ring-line'
           end
    icon = Candidate::WINNING_OUTCOMES.include?(outcome) ? '✓ ' : ''
    content_tag :span, "#{icon}#{OUTCOME_LABELS.fetch(outcome, outcome.humanize)}",
                class: "#{tone} inline-flex items-center rounded-full px-2 py-0.5 text-xs font-medium whitespace-nowrap"
  end

  CHANNEL_LABELS = { 'Official Office' => 'Official', 'Campaign' => 'Campaign', 'Personal' => 'Personal' }.freeze

  def channel_label(channel_type)
    CHANNEL_LABELS[channel_type]
  end

  # "Updated 3 Oct 2026": absolute date, rendered server-side (no build-time
  # relative strings that go stale).
  def updated_stamp(time, label: 'Updated')
    return if time.blank?

    content_tag :span, class: 'text-xs text-ink-faint' do
      safe_join([label, ' ', content_tag(:time, l(time.to_date, format: :long), datetime: time.iso8601)])
    end
  end

  PLATFORM_NAMES = { 'Twitter' => 'X (Twitter)', 'BlueSky' => 'Bluesky', 'TruthSocial' => 'Truth Social',
                     'Gettr' => 'GETTR' }.freeze

  def platform_name(platform)
    PLATFORM_NAMES.fetch(platform, platform)
  end

  # "@handle" for display, from whatever form the handle/URL is stored in.
  def display_handle(account)
    handle = SocialHandles.normalize(account.platform, account.handle.presence || account.url)&.dig(:handle)
    # Skip ids that aren't human handles: numeric Facebook ids, YouTube UC… channel ids.
    return if handle.blank? || handle.include?('/') || handle.match?(/\A\d{8,}\z/) || handle.match?(/\AUC[\w-]{22}\z/)

    "@#{handle}"
  rescue StandardError
    nil
  end

  # "U.S. Representative · CT Congressional District 4", "U.S. Senator · AK".
  def seat_label(office)
    return 'Unknown office' unless office

    where = if office.district
              office.district.full_name
            elsif office.state.present? && !office.title.to_s.include?(office.state.to_s) && !office.title.to_s.include?(' of ')
              [office.seat, office.state].compact_blank.join(', ')
            else
              office.seat
            end
    [office.title, where.presence].compact.join(' · ')
  end

  # "2026 Democratic primary", "2026 general election".
  def contest_kind(contest)
    kind = if contest.contest_type == 'primary' && contest.party.present?
             "#{contest.party} primary"
           elsif contest.contest_type == 'general'
             'general election'
           else
             contest.contest_type.to_s.humanize.downcase
           end
    [contest.date&.year, kind].compact.join(' ')
  end
end
