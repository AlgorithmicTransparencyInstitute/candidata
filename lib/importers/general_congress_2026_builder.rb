require 'csv'

module Importers
  # Builds the 2026 GENERAL election records for every U.S. House seat (435)
  # and U.S. Senate race (35) from the 2026 PRIMARY data already in the
  # database:
  #
  #   Election (general, 2026-11-03) -> Ballot (general, no party)
  #   -> Contest (general, one per seat) -> Candidate (each primary nominee)
  #
  # A primary nominee is a candidate whose outcome is in
  # Candidate::WINNING_OUTCOMES (won / advanced). Nominees are carried into
  # the seat's general contest only when the party picture is unambiguous:
  #
  # - pending/unknown primary outcomes are never carried (result not entered)
  # - two or more nominees from the same party are HELD for review, except
  #   where that is legitimate: top-two (CA, WA), Alaska's top-four, and
  #   independent-type labels (several independents can qualify)
  #
  # Every held/unresolved/empty seat is written to the review CSV so it can be
  # researched; resolutions go in SEAT_RESOLUTIONS and the builder is re-run.
  #
  # DRY RUN BY DEFAULT. Pass apply: true to write. Idempotent (find-or-create
  # throughout), so it can be re-run after resolving seats.
  class GeneralCongress2026Builder
    ELECTION_DATE = Date.new(2026, 11, 3)
    YEAR = 2026

    HOUSE = 'U.S. Representative'.freeze
    SENATE = 'U.S. Senator'.freeze

    # Primary contests attached to the wrong office record. Senate offices are
    # per-seat (one per sitting senator); the seat up in 2026 is the class II
    # seat (or the FL/OH specials).
    SENATE_SEAT_UP = {
      'WY' => 108_258, # Lummis seat; the R primary was attached to Barrasso's (108259)
      'MA' => 81_434   # Markey seat; the Independent/PSL entries were attached to Warren's (81433)
    }.freeze
    # District-less duplicate House offices -> the real at-large office.
    HOUSE_OFFICE_FIX = { 108_563 => 89_144, 108_564 => 97_398 }.freeze # ND, SD
    # A district-less IL House office with an empty Democratic primary contest
    # (no candidates); nothing to carry.
    IGNORED_OFFICES = [108_558].freeze

    TOP_TWO_STATES = %w[CA WA].freeze
    TOP_FOUR_STATES = %w[AK].freeze
    MULTI_OK_LABELS = ['Independent', 'Independence', 'Nonpartisan', 'Unaffiliated', 'No Party Preference',
                       'Undeclared', 'No Party Affiliation', 'No Political Party'].freeze

    # Researched resolutions for held seats: seat label ("TX-8", "MI-Sen") ->
    # { include: [person_id, ...] } (exactly who goes on the general ballot for
    # the held parties). Empty until the review CSV is worked.
    SEAT_RESOLUTIONS = {}.freeze

    Seat = Struct.new(:chamber, :state, :office, :label, :primaries, :nominees, :held, :unresolved, keyword_init: true)

    attr_reader :seats, :created

    def initialize(apply: false)
      @apply = apply
      @created = Hash.new(0)
    end

    def call
      @seats = build_seats
      @seats.each { |seat| classify(seat) }
      write! if @apply
      self
    end

    def review_rows
      @seats.select { |s| s.held.any? || s.unresolved.any? || s.nominees.empty? }.map do |s|
        {
          seat: s.label,
          issue: [('no nominee carried' if s.nominees.empty?),
                  ("held: #{s.held.keys.join(', ')}" if s.held.any?),
                  ('unresolved primary result' if s.unresolved.any?)].compact.join('; '),
          carried: s.nominees.map { |n| "#{n[:person].full_name} (#{n[:party]}) ##{n[:person].id}" }.join('; '),
          held: s.held.flat_map { |party, ns| ns.map { |n| "#{n[:person].full_name} (#{party}, #{n[:outcome]}) ##{n[:person].id}" } }.join('; '),
          unresolved: s.unresolved.map { |n| "#{n[:person].full_name} (#{n[:party]}, #{n[:outcome]}) ##{n[:person].id}" }.join('; '),
          primary_contests: s.primaries.map { |c| "#{c.party}:#{c.id}" }.join(' ')
        }
      end
    end

    private

    def build_seats
      primaries = Contest.joins(:ballot, :office)
                         .where(ballots: { year: YEAR }, contest_type: 'primary')
                         .where(offices: { level: 'federal', title: [HOUSE, SENATE] })
                         .where.not(office_id: IGNORED_OFFICES)
                         .includes(:office, :ballot, candidates: :person)

      grouped = primaries.group_by do |c|
        state = c.ballot.state
        office_id = if c.office.title == SENATE
                      SENATE_SEAT_UP[state] || c.office_id
                    else
                      HOUSE_OFFICE_FIX[c.office_id] || c.office_id
                    end
        [state, office_id]
      end

      grouped.map do |(state, office_id), contests|
        office = Office.includes(:district).find(office_id)
        chamber = office.title == SENATE ? :senate : :house
        label = chamber == :senate ? "#{state}-Sen" : "#{state}-#{office.district&.district_number}"
        Seat.new(chamber: chamber, state: state, office: office, label: label, primaries: contests,
                 nominees: [], held: {}, unresolved: [])
      end.sort_by { |s| [s.state, s.chamber == :senate ? -1 : s.label.split('-').last.to_i] }
    end

    def classify(seat)
      entries = seat.primaries.flat_map do |c|
        c.candidates.map do |x|
          { person: x.person, candidate: x, party: c.party.presence || x.party_at_time,
            outcome: x.outcome, incumbent: x.incumbent }
        end
      end

      seat.unresolved = entries.select { |e| %w[pending unknown].include?(e[:outcome]) }
      winners = entries.select { |e| Candidate::WINNING_OUTCOMES.include?(e[:outcome]) }

      # Fusion (NY: same person on e.g. Republican + Conservative lines) is one
      # general candidacy; label it with the major party when there is one.
      by_person = winners.group_by { |e| e[:person].id }.map do |_, es|
        major = es.find { |e| %w[Democratic Republican].include?(e[:party]) }
        (major || es.first).merge(incumbent: es.any? { |e| e[:incumbent] })
      end

      if (resolution = SEAT_RESOLUTIONS[seat.label])
        ids = resolution.fetch(:include)
        seat.nominees = ids.map do |id|
          by_person.find { |e| e[:person].id == id } ||
            entries.find { |e| e[:person].id == id } ||
            raise("#{seat.label}: resolution person ##{id} has no 2026 primary candidacy for this seat")
        end
        seat.unresolved = []
        return
      end

      multi_ok = TOP_TWO_STATES.include?(seat.state) || TOP_FOUR_STATES.include?(seat.state)
      by_person.group_by { |e| e[:party] }.each do |party, es|
        if es.size > 1 && !multi_ok && !MULTI_OK_LABELS.include?(party)
          seat.held[party] = es
        else
          seat.nominees.concat(es)
        end
      end
    end

    def write!
      Election.transaction do
        repair_primary_offices!

        @seats.group_by(&:state).each do |state, seats|
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

          seats.each do |seat|
            contest = Contest.find_or_create_by!(ballot: ballot, office: seat.office, contest_type: 'general', date: ELECTION_DATE) do
              @created[:contests] += 1
            end
            seat.nominees.each do |n|
              Candidate.find_or_create_by!(person: n[:person], contest: contest) do |c|
                c.party_at_time = n[:party]
                c.incumbent = n[:incumbent] || false
                c.outcome = 'pending'
                @created[:candidates] += 1
              end
            end
          end
        end
      end
    end

    # Point the mis-attached 2026 primary contests at the seat they were for,
    # so the primary records agree with the general ones.
    def repair_primary_offices!
      primary_2026 = Contest.joins(:ballot).where(ballots: { year: YEAR }, contest_type: 'primary')

      SENATE_SEAT_UP.each do |state, office_id|
        primary_2026.joins(:office).where(ballots: { state: state }, offices: { title: SENATE })
                    .where.not(office_id: office_id).find_each do |c|
          repoint!(c, office_id)
          @created[:primary_contests_repointed] += 1
        end
      end
      HOUSE_OFFICE_FIX.each do |from, to|
        primary_2026.where(office_id: from).find_each do |c|
          repoint!(c, to)
          @created[:primary_contests_repointed] += 1
        end
      end
    end

    # Only office_id changes. Skip validation: some of these contests carry a
    # pre-existing party label outside Party.ballot_vocabulary (e.g. MA's
    # "Party of Socialism and Liberation"), which would block the move.
    # save (not update_column) so PaperTrail still records the change.
    def repoint!(contest, office_id)
      contest.office_id = office_id
      contest.save!(validate: false)
    end
  end
end
