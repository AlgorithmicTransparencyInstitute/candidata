require 'csv'

# Server side of the election editor "Import CSV" flow. PREVIEW ONLY — parses
# the file, maps columns to grid fields, validates values against the app's
# vocabularies, and matches offices/contests/people. It writes nothing: on
# confirm the client creates missing ballots+contests through the existing
# contests endpoint and stages rows into the grid, so every DB write still
# goes through the tested paths (ElectionEditorController#create_contest and
# ElectionEditorSave).
#
# Matching rules mirror the batch pipeline (Importers::EnhancedCandidate2026Importer):
# people match by exact first+last (case-insensitive) within the election's
# state — a single match links, multiple matches link only for incumbents;
# office text like "U.S. House" + district resolves to the canonical Office
# titles ("U.S. Representative" + seat "District N"). Anything the heuristics
# can't resolve is returned as an unresolved contest group for the user to
# bind manually in the dialog.
class ElectionEditorCsvImport
  MAX_ROWS = 2000

  FIELDS = ([
    ['fullName',  'Candidate name (full)'],
    ['firstName', 'First name'],
    ['lastName',  'Last name'],
    ['party',     'Party'],
    ['office',    'Office'],
    ['district',  'District / seat'],
    ['incumbent', 'Incumbent'],
    ['withdrew',  'Withdrew'],
    ['primaryContestant', 'Primary contestant?'],
    ['outcome',   'Outcome'],
    ['gender',    'Gender'],
    ['race',      'Race'],
    ['state',     'State (sanity check)']
  ] + SocialMediaAccount::PLATFORMS.map { |p| ["social:#{p}", p] })
    .map { |id, label| { id: id, label: label } }.freeze

  FIELD_IDS = FIELDS.map { |f| f[:id] }.freeze

  # Normalized CSV header → field id. Headers are normalized to
  # lowercase_with_underscores before lookup, so "Is Incumbent?" matches
  # "is_incumbent".
  HEADER_ALIASES = {
    'candidate_name' => 'fullName', 'candidatename' => 'fullName',
    'candidate' => 'fullName', 'name' => 'fullName', 'full_name' => 'fullName',
    'first_name' => 'firstName', 'first' => 'firstName',
    'last_name' => 'lastName', 'last' => 'lastName',
    'party' => 'party', 'party_affiliation' => 'party',
    'office' => 'office', 'office_name' => 'office', 'office_sought' => 'office',
    'district' => 'district', 'district_number' => 'district', 'seat' => 'district',
    'incumbent' => 'incumbent', 'is_incumbent' => 'incumbent',
    'withdrew' => 'withdrew', 'withdrawn' => 'withdrew',
    'primary_contestant' => 'primaryContestant',
    'outcome' => 'outcome', 'result' => 'outcome',
    'gender' => 'gender', 'sex' => 'gender',
    'race' => 'race', 'ethnicity' => 'race',
    'state' => 'state',
    'twitter' => 'social:Twitter', 'x' => 'social:Twitter',
    'twitter_x' => 'social:Twitter', 'x_twitter' => 'social:Twitter',
    'facebook' => 'social:Facebook', 'instagram' => 'social:Instagram',
    'youtube' => 'social:YouTube', 'tiktok' => 'social:TikTok',
    'bluesky' => 'social:BlueSky', 'bsky' => 'social:BlueSky',
    'truthsocial' => 'social:TruthSocial', 'truth_social' => 'social:TruthSocial',
    'gettr' => 'social:Gettr', 'rumble' => 'social:Rumble',
    'telegram' => 'social:Telegram', 'threads' => 'social:Threads'
  }.freeze

  # Source spreadsheets vary ("Democrat" vs "Democratic", single letters, GOP…).
  # Canonical values are the Contest::PARTIES vocabulary.
  PARTY_ALIASES = {
    'democrat' => 'Democratic', 'democratic' => 'Democratic', 'dem' => 'Democratic', 'd' => 'Democratic',
    'republican' => 'Republican', 'gop' => 'Republican', 'rep' => 'Republican', 'r' => 'Republican',
    'libertarian' => 'Libertarian', 'lib' => 'Libertarian', 'l' => 'Libertarian',
    'independent' => 'Independent', 'ind' => 'Independent', 'i' => 'Independent',
    'no party preference' => 'No Party Preference', 'npp' => 'No Party Preference',
    'nonpartisan' => 'Nonpartisan', 'non-partisan' => 'Nonpartisan', 'non partisan' => 'Nonpartisan',
    'unaffiliated' => 'Unaffiliated', 'una' => 'Unaffiliated'
  }.freeze

  OUTCOME_ALIASES = {
    'advanced (unopposed)' => 'advanced', 'unopposed' => 'advanced',
    'winner' => 'won', 'win' => 'won', 'loser' => 'lost', 'loss' => 'lost',
    'withdrawn' => 'withdrawn', 'withdrew' => 'withdrawn'
  }.freeze

  TRUTHY = %w[true t yes y 1 x].freeze
  FALSY_PLACEHOLDERS = ['', 'false', 'f', 'no', 'n', '0', 'n/a', 'na', '99', 'see notes', 'unknown'].freeze
  # Values researchers type in a social cell to mean "checked, no account".
  SOCIAL_PLACEHOLDERS = ['x', 'xx', 'n/a', 'na', 'none', '-', '--', '?', 'tbd', '99', 'see notes'].freeze

  class ParseError < StandardError; end

  def initialize(election)
    @election = election
    @contests = Contest.joins(:ballot).where(ballots: { election_id: election.id })
                       .includes(:office, :ballot).to_a
    @group_cache = {}
  end

  def preview(csv_text:, mapping_override: {})
    table = parse(csv_text)
    headers = table.headers.compact.map(&:to_s)
    mapping = build_mapping(headers, mapping_override)
    errors = structural_errors(table, mapping)
    return empty_result(mapping, errors) if errors.any?

    @headers_for_field = mapping.each_with_object(Hash.new { |h, k| h[k] = [] }) do |entry, acc|
      acc[entry[:field]] << entry[:header] if entry[:field]
    end

    raw_rows = table.reject { |r| r.to_h.values.all?(&:blank?) }
    @people_by_name = people_index(raw_rows)
    @candidate_index = Candidate.where(contest_id: @contests.map(&:id))
                                .pluck(:person_id, :contest_id, :id)
                                .to_h { |person_id, contest_id, id| [[person_id, contest_id], id] }

    seen = {}
    rows = raw_rows.each_with_index.map { |raw, i| build_row(raw, i + 2, seen) }
    narrow_unresolved_groups!(rows)

    {
      fields: FIELDS,
      mapping: mapping,
      rows: rows,
      contestGroups: contest_groups(rows),
      summary: summary(rows),
      errors: []
    }
  rescue ParseError => e
    empty_result([], [e.message])
  end

  private

  def parse(csv_text)
    text = csv_text.to_s.dup.force_encoding(Encoding::UTF_8)
    text = text.valid_encoding? ? text : text.encode(Encoding::UTF_8, invalid: :replace, undef: :replace)
    text = text.delete_prefix("\xEF\xBB\xBF")
    table = CSV.parse(text, headers: true, skip_blanks: true, liberal_parsing: true)
    raise ParseError, 'The file has no data rows' if table.empty?
    raise ParseError, "Too many rows (#{table.size}) — the import is capped at #{MAX_ROWS} rows per file" if table.size > MAX_ROWS

    table
  rescue CSV::MalformedCSVError => e
    raise ParseError, "Could not parse CSV: #{e.message}"
  end

  def normalize_header(header)
    header.to_s.strip.downcase.gsub(/[^a-z0-9]+/, '_').gsub(/\A_+|_+\z/, '')
  end

  # mapping_override comes from the dialog's mapping selects: {header => field id or ""}.
  def build_mapping(headers, mapping_override)
    override = (mapping_override || {}).to_h.transform_values(&:presence)
    headers.map do |header|
      field =
        if override.key?(header)
          override[header]
        else
          HEADER_ALIASES[normalize_header(header)]
        end
      { header: header, field: FIELD_IDS.include?(field) ? field : nil }
    end
  end

  def structural_errors(table, mapping)
    mapped = mapping.filter_map { |m| m[:field] }
    errors = []
    errors << 'No columns are mapped — the CSV headers were not recognized' if mapped.empty?
    unless mapped.include?('fullName') || (mapped.include?('firstName') && mapped.include?('lastName'))
      errors << 'A name column is required: map "Candidate name (full)" or both "First name" and "Last name"'
    end
    errors << 'An Office column is required' unless mapped.include?('office')
    if primary? && !mapped.include?('party')
      errors << 'A Party column is required for a primary election (it determines the party ballot)'
    end
    dupes = mapped.tally.select { |field, n| n > 1 && field != nil }.keys
    if dupes.any?
      labels = FIELDS.select { |f| dupes.include?(f[:id]) }.map { |f| f[:label] }
      errors << "Multiple columns are mapped to the same field: #{labels.join(', ')}"
    end
    errors
  end

  def empty_result(mapping, errors)
    { fields: FIELDS, mapping: mapping, rows: [], contestGroups: [],
      summary: { total: 0 }, errors: errors }
  end

  def primary?
    @election.election_type == 'primary'
  end

  def field_value(raw, field)
    (@headers_for_field[field] || []).each do |header|
      value = raw[header].to_s.strip
      return value if value.present?
    end
    nil
  end

  def field_mapped?(field)
    @headers_for_field.key?(field)
  end

  def truthy?(value)
    TRUTHY.include?(value.to_s.strip.downcase)
  end

  # ---------- row assembly ----------

  def build_row(raw, line, seen)
    issues = []
    warnings = []

    first, last = names_from(raw, issues)

    state = field_value(raw, 'state')
    if state.present? && state.upcase != @election.state
      issues << "Row is for state #{state.upcase}, but this election is #{@election.state}"
    end

    party_raw = field_value(raw, 'party')
    party = canonical_party(party_raw)
    if party_raw.present? && !Contest::PARTIES.include?(party)
      if primary?
        issues << "Unknown party #{party_raw.inspect} — not in the ballot vocabulary"
      else
        warnings << "Unknown party #{party_raw.inspect} — will be stored as typed"
      end
    elsif primary? && party_raw.blank?
      issues << 'Party is required for a primary election'
    end

    primary_contestant = field_value(raw, 'primaryContestant')
    if primary? && primary_contestant.present? && !truthy?(primary_contestant)
      issues << 'Marked as not a primary contestant — does not belong on this primary ballot'
    end

    withdrawn = truthy?(field_value(raw, 'withdrew'))
    outcome = canonical_outcome(field_value(raw, 'outcome'), withdrawn, issues)
    incumbent = truthy?(field_value(raw, 'incumbent'))
    gender = canonical_gender(field_value(raw, 'gender'), warnings)
    race = field_value(raw, 'race')

    group = resolve_group(raw, party)
    issues << 'Office is required' if group.nil?

    person = match_person(first, last, incumbent, warnings)
    merge_candidate_id = nil
    if person && group && group[:contestId]
      merge_candidate_id = @candidate_index[[person.id, group[:contestId]]]
      warnings << 'Already a candidate in this contest — the existing row will be updated' if merge_candidate_id
    end

    if first.present? && last.present? && group
      dup_key = [first.downcase, last.downcase, group[:key]]
      if seen[dup_key]
        issues << "Duplicate of row #{seen[dup_key]} (same name and contest) — skipped"
      else
        seen[dup_key] = line
      end
    end

    {
      index: line,
      firstName: first.to_s,
      lastName: last.to_s,
      party: (Contest::PARTIES.include?(party) ? party : party_raw).presence,
      outcome: outcome,
      incumbent: incumbent,
      withdrawn: withdrawn,
      gender: gender,
      race: race,
      contestKey: group&.dig(:key),
      contestId: group&.dig(:contestId),
      personId: person&.id,
      personLabel: person&.full_name,
      mergeCandidateId: merge_candidate_id,
      socials: social_cells(raw, person, warnings),
      csv: csv_values(raw, party, outcome, incumbent, gender, race),
      issues: issues,
      warnings: warnings
    }
  end

  def names_from(raw, issues)
    first = field_value(raw, 'firstName')
    last = field_value(raw, 'lastName')
    if first.blank? || last.blank?
      full = field_value(raw, 'fullName')
      if full.present?
        parsed_first, parsed_last = split_full_name(full)
        issues << "Could not split name #{full.inspect} into first/last" if parsed_first.blank?
        first = first.presence || parsed_first
        last = last.presence || parsed_last
      end
    end
    issues << 'First name is required' if first.blank?
    issues << 'Last name is required' if last.blank?
    [first, last]
  end

  # "Clyde W. Jones, Jr." → ["Clyde", "Jones"]. Middle names/suffixes are
  # dropped — the grid (and ElectionEditorSave) only carry first/last.
  def split_full_name(full)
    name = full.squish
    name = name.sub(/,?\s+(Jr\.?|Sr\.?|II|III|IV|V)\z/i, '')
    name = name.gsub(/"[^"]*"/, ' ').gsub(/\([^)]*\)/, ' ').squish
    parts = name.split(/\s+/)
    return [nil, nil] if parts.size < 2

    [parts.first, parts.last]
  end

  # "Democrat" → "Democratic", "GOP" → "Republican"; a trailing " Party" is
  # dropped first so "Unity Party"/"No Labels Party" hit the vocabulary.
  def canonical_party(raw)
    value = raw.to_s.squish.sub(/\s+party\z/i, '')
    return nil if value.blank?

    PARTY_ALIASES[value.downcase] || value
  end

  def canonical_outcome(raw, withdrawn, issues)
    value = raw.to_s.squish.downcase
    return withdrawn ? 'withdrawn' : 'pending' if FALSY_PLACEHOLDERS.include?(value)

    outcome = OUTCOME_ALIASES[value] || value
    unless Candidate::OUTCOMES.include?(outcome)
      issues << "Unknown outcome #{raw.inspect} (expected one of: #{Candidate::OUTCOMES.join(', ')})"
      return 'pending'
    end
    outcome
  end

  def canonical_gender(raw, warnings)
    value = raw.to_s.squish
    return nil if FALSY_PLACEHOLDERS.include?(value.downcase)

    case value.downcase
    when 'male', 'm' then 'Male'
    when 'female', 'f', 'w' then 'Female'
    when 'other', 'nonbinary', 'non-binary', 'nb' then 'Other'
    else
      warnings << "Unrecognized gender #{raw.inspect} — left blank"
      nil
    end
  end

  # Only values the CSV actually provided (used when merging into an existing
  # grid row, so absent columns never clobber existing data).
  def csv_values(raw, party, outcome, incumbent, gender, race)
    csv = { socials: {} }
    csv[:party] = party if field_value(raw, 'party').present?
    csv[:outcome] = outcome if field_value(raw, 'outcome').present? || truthy?(field_value(raw, 'withdrew'))
    csv[:incumbent] = incumbent if field_value(raw, 'incumbent').present?
    csv[:gender] = gender if gender.present?
    csv[:race] = race if race.present?
    SocialMediaAccount::PLATFORMS.each do |platform|
      value = social_value(raw, platform)
      csv[:socials][platform] = value if value.present?
    end
    csv
  end

  def social_value(raw, platform)
    value = field_value(raw, "social:#{platform}")
    return nil if value.blank? || SOCIAL_PLACEHOLDERS.include?(value.downcase)

    value
  end

  # Grid-ready social cells. The CSV value wins; a matched person's existing
  # account (per ElectionEditorSocials priority) provides the accountId binding
  # so saves update that account instead of creating a duplicate — but ONLY
  # when both refer to the same handle. A genuinely different CSV handle (the
  # workbooks usually carry the campaign account while the DB holds the
  # verified official-office one) is staged unbound, so saving creates a
  # separate campaign account and never overwrites the existing one.
  def social_cells(raw, person, warnings)
    existing = person ? ElectionEditorSocials.map(person) : {}
    cells = {}
    SocialMediaAccount::PLATFORMS.each do |platform|
      csv_value = social_value(raw, platform)
      account = existing[platform]
      next if csv_value.blank? && account.nil?

      if csv_value.present? && account
        csv_handle = SocialHandles.normalize(platform, csv_value)&.dig(:handle)
        unless SocialHandles.same?(platform, account[:handle], csv_handle)
          cells[platform] = { accountId: nil, value: csv_value, url: nil, verified: false }
          existing_label = SocialHandles.comparable(platform, account[:handle]).presence || account[:url]
          warnings << "#{platform}: CSV value differs from the existing account (#{existing_label}) — " \
                      'it will be saved as a separate campaign account'
          next
        end
      end

      cells[platform] = {
        accountId: account&.dig(:accountId),
        value: csv_value.presence || account&.dig(:url) || account&.dig(:handle) || '',
        url: account&.dig(:url),
        verified: !!account&.dig(:verified)
      }
    end
    cells
  end

  # ---------- person matching ----------

  def people_index(raw_rows)
    keys = raw_rows.filter_map do |raw|
      first, last = names_from(raw, [])
      "#{first} #{last}".squish.downcase if first.present? && last.present?
    end.uniq
    return {} if keys.empty?

    Person.where(state_of_residence: @election.state)
          .where("LOWER(TRIM(COALESCE(first_name,'') || ' ' || COALESCE(last_name,''))) IN (?)", keys)
          .includes(:social_media_accounts)
          .group_by { |p| "#{p.first_name} #{p.last_name}".squish.downcase }
  end

  # Same policy as the batch importer: incumbents take the first match (they
  # are almost always already in the DB from GovProj); non-incumbents only
  # link when the match is unambiguous.
  def match_person(first, last, incumbent, warnings)
    return nil if first.blank? || last.blank?

    matches = @people_by_name["#{first} #{last}".squish.downcase] || []
    return matches.first if matches.size == 1
    return nil if matches.empty?

    if incumbent
      matches.first
    else
      warnings << "#{matches.size} existing people named #{first} #{last} — not linked (use the name typeahead in the grid to pick one)"
      nil
    end
  end

  # ---------- office / contest resolution ----------

  def resolve_group(raw, party)
    office_text = field_value(raw, 'office')
    return nil if office_text.blank?

    district = field_value(raw, 'district')
    ballot_party = primary? ? party : nil
    key = [office_text.downcase.squish, district.to_s[/\d+/] || district.to_s.downcase.squish, ballot_party].join('|')

    @group_cache[key] ||= begin
      offices = matching_offices(office_text, district)
      office_ids = offices.map(&:id)
      contests = @contests.select { |c| office_ids.include?(c.office_id) }
      contests = contests.select { |c| c.ballot.party == ballot_party } if primary?

      label = district.present? && !office_text.match?(/\d/) ? "#{office_text} — District #{district}" : office_text
      base = { key: key, label: label, party: ballot_party, contestId: nil, officeId: nil, officeLabel: nil, note: nil }

      # Several offices can be textually identical (e.g. a state's two U.S.
      # Senate seats). When only one of them is already contested in this
      # election, a new party ballot for "the" seat means that one.
      if offices.size > 1
        used_office_ids = @contests.map(&:office_id).to_set
        narrowed = offices.select { |o| used_office_ids.include?(o.id) }
        offices = narrowed if narrowed.size == 1 && contests.empty?
      end

      if contests.size == 1
        base.merge(status: 'matched', contestId: contests.first.id,
                   officeLabel: contests.first.office.display_name)
      elsif contests.size > 1
        base.merge(status: 'unresolved', note: "#{contests.size} contests in this election match — pick the office manually")
      elsif offices.size == 1
        base.merge(status: 'create', officeId: offices.first.id, officeLabel: offices.first.display_name)
      elsif offices.size > 1
        base.merge(status: 'unresolved', officeIds: offices.map(&:id),
                   note: "#{offices.size} offices match #{office_text.inspect} — pick one manually")
      else
        base.merge(status: 'unresolved', note: "No #{@election.state} office matches #{office_text.inspect}")
      end
    end
  end

  def state_offices
    @state_offices ||= Office.where(state: @election.state).select(:id, :title, :seat).to_a
  end

  def state_name
    @state_name ||= State.find_by(abbreviation: @election.state)&.name
  end

  def matching_offices(office_text, district)
    text = office_text.squish
    dnum = district.to_s[/\d+/] || text[/\bdistrict\s*0*(\d+)/i, 1]

    if (target = canonical_target(text, dnum))
      found = state_offices.select do |o|
        target[:titles].any? { |t| o.title.casecmp?(t) } && seat_match?(o.seat, target[:seat])
      end
      return found if found.any?
    end

    wanted_seat = dnum ? "District #{dnum.to_i}" : district.presence
    found = state_offices.select { |o| o.title.casecmp?(text) && seat_match?(o.seat, wanted_seat) }
    return found if found.any?

    found = state_offices.select { |o| o.display_name.casecmp?(text) }
    return found if found.any?

    # "Governor" → "Governor of Iowa"-style titles
    state_offices.select do |o|
      o.title.downcase.start_with?("#{text.downcase} of") && seat_match?(o.seat, wanted_seat)
    end
  end

  # Canonical Office titles for the office-name conventions the source
  # spreadsheets use (matches how the batch importer creates offices).
  def canonical_target(text, dnum)
    st = @election.state
    seat = dnum ? "District #{dnum.to_i}" : nil

    case text
    when /\Au\.?\s*s\.?\s*(house|rep)/i, /\Aus\s+house/i, /\bcongressional\b/i
      { titles: ['U.S. Representative'], seat: seat }
    when /\Au\.?\s*s\.?\s*sen/i, /\Aus\s+sen/i
      { titles: ['U.S. Senator'], seat: nil }
    when /\A(lt\.?|lieutenant)\s+governor\b/i
      { titles: [state_name ? "Lieutenant Governor of #{state_name}" : nil, 'Lieutenant Governor'].compact, seat: nil }
    when /\Agovernor\b/i
      { titles: [state_name ? "Governor of #{state_name}" : nil, 'Governor'].compact, seat: nil }
    when /\Aattorney\s+general\b/i
      { titles: [state_name ? "Attorney General of #{state_name}" : nil, "#{st} Attorney General", 'Attorney General'].compact, seat: nil }
    when /\Asecretary\s+of\s+state\b/i
      { titles: [state_name ? "Secretary of State of #{state_name}" : nil, "#{st} Secretary of State", 'Secretary of State'].compact, seat: nil }
    when /\Astate\s+(house|rep|assembly|delegate)/i, /\Ahouse\s+of\s+delegates/i
      { titles: ["#{st} State Representative", "#{st} State Assembly Member", "#{st} State Delegate", 'State Representative'], seat: seat }
    when /\Astate\s+sen/i
      { titles: ["#{st} State Senator", 'State Senator'], seat: seat }
    # Bare "House"/"Senate" (the raw state workbooks' convention) means the
    # federal race — the state-legislature forms are matched above first.
    when /\Ahouse\b/i
      { titles: ['U.S. Representative'], seat: seat }
    when /\Asen(ate|ator)\b/i
      { titles: ['U.S. Senator'], seat: nil }
    end
  end

  def seat_match?(office_seat, wanted_seat)
    a = office_seat.to_s.squish
    b = wanted_seat.to_s.squish
    return true if a.blank? && b.blank?

    a_num = a[/\d+/]
    b_num = b[/\d+/]
    return a_num.to_i == b_num.to_i if a_num && b_num

    a.casecmp?(b)
  end

  # ---------- aggregation ----------

  # A group stuck between several textually identical offices (e.g. a state's
  # two U.S. Senate seats) resolves when one of the group's linked people
  # currently HOLDS one of those offices — the incumbent tells us which seat
  # the race is for.
  def narrow_unresolved_groups!(rows)
    narrowed = {} # sorted officeIds signature => resolved Office

    @group_cache.each do |key, group|
      next unless group[:status] == 'unresolved' && group[:officeIds].present?

      person_ids = rows.select { |r| r[:contestKey] == key }.filter_map { |r| r[:personId] }
      next if person_ids.empty?

      held = Officeholder.current.where(person_id: person_ids, office_id: group[:officeIds])
                         .distinct.pluck(:office_id)
      next unless held.size == 1

      office = Office.find(held.first)
      narrowed[group[:officeIds].sort] = office
      @group_cache[key] = group.merge(status: 'create', officeId: office.id,
                                      officeLabel: office.display_name, note: nil)
    end

    # Propagate to sibling groups tied between the same offices (e.g. the other
    # party's ballot for the same Senate seat).
    @group_cache.each do |key, group|
      next unless group[:status] == 'unresolved' && group[:officeIds].present?

      office = narrowed[group[:officeIds].sort]
      next unless office

      @group_cache[key] = group.merge(status: 'create', officeId: office.id,
                                      officeLabel: office.display_name, note: nil)
    end
  end

  def contest_groups(rows)
    counts = rows.group_by { |r| r[:contestKey] }
    @group_cache.values.map do |group|
      group.except(:officeIds).merge(rowCount: (counts[group[:key]] || []).size)
    end
  end

  def summary(rows)
    groups = @group_cache.values
    {
      total: rows.size,
      withIssues: rows.count { |r| r[:issues].any? },
      linked: rows.count { |r| r[:personId] },
      newPeople: rows.count { |r| r[:personId].nil? && r[:issues].empty? },
      updates: rows.count { |r| r[:mergeCandidateId] },
      withdrawn: rows.count { |r| r[:withdrawn] },
      contestsMatched: groups.count { |g| g[:status] == 'matched' },
      contestsToCreate: groups.count { |g| g[:status] == 'create' },
      contestsUnresolved: groups.count { |g| g[:status] == 'unresolved' }
    }
  end
end
