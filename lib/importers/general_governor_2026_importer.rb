require 'csv'

module Importers
  # Imports the 2026 gubernatorial GENERAL election candidate list
  # (data/2026_general/governors/*.csv, exported from the
  # "2026_Gubernatorial_General_Election_Candidates" Google Sheet).
  #
  # For each state on the sheet it find-or-creates the full record chain:
  #   Election (general, 2026-11-03) -> Ballot (general, no party)
  #   -> Contest (general, "Governor of <State>") -> Candidate
  # and matches each candidate to an existing Person before creating one.
  #
  # Writes go through ElectionEditorSave so imported rows get exactly the
  # election editor's semantics (Campaign/entered/unverified socials, verified
  # accounts never touched, blank per-platform stubs) and stay editable in the
  # grid at /admin/elections/:id/editor.
  #
  # DRY RUN BY DEFAULT: prints a per-candidate match report and writes nothing.
  # Pass apply: true to write. Rows whose person match is ambiguous are never
  # written — resolve them via MATCH_OVERRIDES and re-run.
  #
  # Social accounts: before the editor save, every sheet URL is resolved against
  # ALL of the person's existing accounts on that platform (any channel type,
  # URL-form or bare handle) so a channel already on file is reused, not
  # duplicated. See GitHub issue #2 for why exact handle matching isn't enough.
  class GeneralGovernor2026Importer
    ELECTION_DATE = Date.new(2026, 11, 3)
    YEAR = 2026

    SHEET_PLATFORMS = {
      'Facebook' => 'Facebook',
      'Instagram' => 'Instagram',
      'Twitter/X' => 'Twitter',
      'YouTube' => 'YouTube',
      'TikTok' => 'TikTok',
      'BlueSky' => 'BlueSky'
    }.freeze

    # Names the generic parser can't split correctly.
    NAME_OVERRIDES = {
      'Pro-Life (Marvin Thomas Richardson)' => { first: 'Marvin', middle: 'Thomas', last: 'Richardson' },
      'Keisha R Lance Bottoms' => { first: 'Keisha', middle: 'R', last: 'Lance Bottoms' },
      'Sarah Huckabee Sanders' => { first: 'Sarah', middle: 'Huckabee', last: 'Sanders' },
      'Helena Buonanno Foulkes' => { first: 'Helena', middle: 'Buonanno', last: 'Foulkes' },
      'Jeffrey Peter "Dr. Jeff" Datto' => { first: 'Jeffrey', middle: 'Peter', last: 'Datto' },
      'Moliere Moe Dimanche' => { first: 'Moliere', middle: 'Moe', last: 'Dimanche' },
      'Charles Van Morgan' => { first: 'Charles', middle: nil, last: 'Van Morgan' },
      'Robert E Brooks Sr' => { first: 'Robert', middle: 'E', last: 'Brooks', suffix: 'Sr.' }
    }.freeze

    # Sheet name -> existing person id, for matches the automatic matcher can't
    # make (name form differs) or must not make (ambiguous). Filled in from the
    # dry-run review; :new forces creation of a new person.
    MATCH_OVERRIDES = {
      # The automatic match is #192490 "Douglas Jones Jr.", a Chambers County
      # commissioner — not former U.S. Senator Doug Jones, who isn't on file.
      'Doug Jones' => :new
    }.freeze

    NICKNAMES = {
      'tommy' => %w[thomas tom], 'jb' => %w[jay j.b. jaybee], 'bobby' => %w[robert bob],
      'rick' => %w[richard ricky], 'mike' => %w[michael], 'andy' => %w[andrew],
      'dave' => %w[david], 'greg' => %w[gregory], 'gregg' => %w[gregory], 'ned' => %w[edward],
      'phil' => %w[philip phillip], 'doug' => %w[douglas], 'fred' => %w[frederick],
      'ty' => %w[tyler], 'jim' => %w[james], 'joe' => %w[joseph], 'wes' => %w[wesley],
      'dan' => %w[daniel], 'don' => %w[donald], 'pat' => %w[patrick], 'ken' => %w[kenneth],
      'steve' => %w[steven stephen], 'rob' => %w[robert], 'zach' => %w[zachary],
      'deb' => %w[debra deborah], 'debra' => %w[deb], 'cindy' => %w[cynthia],
      'josh' => %w[joshua], 'tina' => %w[christina], 'kathy' => %w[kathleen],
      'jerri' => %w[jerrilyn], 'colt' => %w[colton], 'jeff' => %w[jeffrey],
      'terri' => %w[teresa theresa]
    }.freeze

    Result = Struct.new(:row_num, :name, :state, :party, :status, :decision, :person, :detail, keyword_init: true)

    attr_reader :results, :created

    def initialize(csv_path, apply: false, user: nil)
      @csv_path = csv_path
      @apply = apply
      @user = user
      @results = []
      @created = Hash.new(0)
      @states = State.all.index_by(&:name)
    end

    def call
      rows = CSV.read(@csv_path, headers: true, encoding: 'bom|utf-8').map { |r| r.to_h.transform_keys { |k| k.to_s.strip } }
      rows.each_with_index { |row, i| @results << review(row, i + 2) }

      write! if @apply
      self
    end

    private

    def review(row, row_num)
      name = row['Candidate'].to_s.squish
      state = @states[row['State'].to_s.strip]
      base = { row_num: row_num, name: name, state: state&.abbreviation, party: party_label(row['Party']),
               status: row['Incumbent_Status'].to_s.strip }
      return Result.new(**base, decision: :error, detail: "unknown state #{row['State'].inspect}") unless state

      office = Office.find_by(title: "Governor of #{state.name}", state: state.abbreviation)
      return Result.new(**base, decision: :error, detail: "no Governor of #{state.name} office") unless office

      parts = parse_name(name)
      decision, person, detail = match_person(name, parts, state.abbreviation, base[:status], office)
      Result.new(**base, decision: decision, person: person, detail: detail).tap do |r|
        r.define_singleton_method(:row) { row }
        r.define_singleton_method(:parts) { parts }
        r.define_singleton_method(:office) { office }
      end
    end

    # -> [decision, person, detail]; decision is :match, :new, or :ambiguous
    def match_person(name, parts, state, status, office)
      # Re-runs: a row already imported is identified by its source name on a
      # candidacy in this exact contest. Checked first so forced :new rows
      # don't create the person again.
      prior = Candidate.joins(:person, :contest)
                       .where(contests: { office_id: office.id, contest_type: 'general', date: ELECTION_DATE })
                       .where(people: { name_source: name })
                       .first&.person
      return [:match, prior, 'already imported'] if prior

      if MATCH_OVERRIDES.key?(name)
        override = MATCH_OVERRIDES[name]
        return [:new, nil, 'override: create new'] if override == :new

        return [:match, Person.find(override), 'override']
      end

      if status == 'Incumbent'
        gov = Officeholder.current.where(office_id: office.id).includes(:person).first&.person
        return [:ambiguous, nil, 'sheet says Incumbent but no current governor on file'] unless gov
        return [:match, gov, 'current governor'] if name_compatible?(parts, gov)

        return [:ambiguous, nil, "sheet says Incumbent but current governor is #{gov.full_name} (#{gov.id})"]
      end

      pool = Person.where('LOWER(last_name) = ?', parts[:last].downcase)
      in_state = pool.where(state_of_residence: state).select { |p| name_compatible?(parts, p) }
      return [:match, in_state.first, 'same state + name'] if in_state.size == 1
      if in_state.size > 1
        return [:ambiguous, nil, "#{in_state.size} in-state matches: #{in_state.map { |p| "#{p.full_name}##{p.id}" }.join(', ')}"]
      end

      # A same-name record with NO state could be this person (federal
      # officeholders sometimes import stateless) — surface it for review.
      # Same-name records in other states are different people: note them.
      named = pool.select { |p| name_compatible?(parts, p) }
      stateless, other_states = named.partition { |p| p.state_of_residence.blank? }
      if stateless.any?
        return [:ambiguous, nil, "stateless same-name record(s): #{stateless.map { |p| "#{p.full_name}##{p.id}" }.join(', ')}"]
      end

      note = other_states.any? ? "(same name elsewhere: #{other_states.map { |p| "#{p.full_name}##{p.id}/#{p.state_of_residence}" }.join(', ')})" : nil
      [:new, nil, note]
    end

    def name_compatible?(parts, person)
      first_forms(parts[:first]).intersect?(first_forms(person.first_name)) ||
        (parts[:middle].present? && first_forms(parts[:middle]).intersect?(first_forms(person.first_name)))
    end

    def first_forms(first)
      f = first.to_s.downcase.delete('.')
      [f, *NICKNAMES.fetch(f, []), *NICKNAMES.select { |_, v| v.include?(f) }.keys].map { |x| x.delete('.') }.to_set
    end

    def parse_name(name)
      return NAME_OVERRIDES[name].reverse_merge(middle: nil, suffix: nil) if NAME_OVERRIDES.key?(name)

      n = name.dup
      suffix = n.slice!(/\s+(Jr\.?|Sr\.?|II|III|IV)\z/i)&.strip
      tokens = n.split(/\s+/)
      { first: tokens.first, middle: tokens[1...-1].join(' ').presence, last: tokens.last, suffix: suffix }
    end

    # "Libertarian Party" -> "Libertarian"; otherwise keep the state's ballot
    # label. "No Political Party" (NV) / "No Party Affiliation" (FL) are whole
    # labels, not "<name> Party", so they're left intact.
    def party_label(raw)
      label = raw.to_s.strip
      return label.presence if label.start_with?('No ')

      label.sub(/\s+Party\z/i, '').presence
    end

    def write!
      if @results.any? { |r| %i[ambiguous error].include?(r.decision) }
        raise 'Refusing to write: resolve every ambiguous/error row first (see report)'
      end

      @results.group_by(&:state).each do |state, results|
        election = Election.find_or_create_by!(state: state, date: ELECTION_DATE, election_type: 'general', year: YEAR) do |e|
          e.name = "#{YEAR} #{state} General Election"
          @created[:elections] += 1
        end
        ballot = Ballot.find_or_create_by!(state: state, date: ELECTION_DATE, election_type: 'general', party: nil) do |b|
          b.year = YEAR
          b.name = "#{YEAR} #{state} General"
          b.election = election
          @created[:ballots] += 1
        end
        ballot.update!(election: election) if ballot.election_id.nil?

        contest = Contest.find_or_create_by!(ballot: ballot, office: results.first.office, contest_type: 'general', date: ELECTION_DATE) do
          @created[:contests] += 1
        end

        rows = results.map { |r| editor_row(r, contest) }
        outcome = ElectionEditorSave.new(election, @user).call(rows: rows, deleted_candidate_ids: [])
        outcome[:results].each do |res|
          raise "Save failed for #{res[:key]}: #{res[:errors].join('; ')}" unless res[:ok]
          (res[:warnings] || []).each { |w| puts "  ⚠ #{res[:key]}: #{w}" }
        end
        attach_parties(results)
      end
    end

    def editor_row(result, contest)
      person = result.person
      parts = result.parts
      row = result.row
      existing_candidate = person && Candidate.find_by(person: person, contest: contest)
      @created[:people] += 1 unless person
      @created[:candidates] += 1 unless existing_candidate

      {
        key: result.name,
        candidateId: existing_candidate&.id,
        personId: person&.id,
        contestId: contest.id,
        # Never rename a matched person: re-send their stored name.
        firstName: person ? person.first_name : parts[:first],
        lastName: person ? person.last_name : parts[:last],
        **(person ? {} : { middleName: parts[:middle], suffix: parts[:suffix] }),
        party: result.party,
        outcome: existing_candidate&.outcome || 'pending',
        incumbent: result.status == 'Incumbent',
        **(person&.website_campaign.present? || row['Campaign_Website'].blank? ? {} : { website: row['Campaign_Website'].strip }),
        nameSource: result.name,
        socials: socials_for(person, row)
      }
    end

    # Resolve each sheet URL to an existing account (any channel type, any
    # stored handle form) so the editor save reuses it rather than duplicating.
    def socials_for(person, row)
      SHEET_PLATFORMS.each_with_object({}) do |(column, platform), cells|
        url = row[column].to_s.strip
        next if url.blank?

        normalized = SocialHandles.normalize(platform, url)
        next unless normalized

        existing = person&.social_media_accounts&.select { |a| a.platform == platform }&.find do |a|
          # Handle-less URLs (facebook.com/profile.php?id=…) can only match by URL.
          next a.url.present? && a.url == normalized[:url] if normalized[:handle].blank?

          stored = SocialHandles.normalize(platform, a.url.presence || a.handle)&.dig(:handle) || a.handle
          SocialHandles.same?(platform, stored, normalized[:handle])
        end
        @created[existing ? :accounts_reused : :accounts_new] += 1
        cells[platform] = { accountId: existing&.id, value: existing ? (existing.url.presence || url) : url }
      end
    end

    # New people get a primary PersonParty when the label maps to a Party row.
    def attach_parties(results)
      results.each do |r|
        next if r.person # matched people keep their existing affiliations

        person = Person.where(name_source: r.name, state_of_residence: r.state).order(:id).last
        next unless person && person.person_parties.none?

        party = Party.find_by(name: r.party) || Party.find_by(name: "#{r.party} Party")
        next unless party

        person.person_parties.create!(party: party, is_primary: true)
        @created[:person_parties] += 1
      end
    end
  end
end
