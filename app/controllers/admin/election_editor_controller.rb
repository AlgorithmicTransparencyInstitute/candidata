module Admin
  # Spreadsheet-style bulk candidate entry for a single election.
  # show           — full-page grid, all data embedded as JSON (no fetch on load)
  # save           — bulk upsert of rows (person + candidate + social accounts)
  # people_search  — typeahead for linking rows to existing Person records
  # offices_search — typeahead for the "new contest" dialog
  # create_contest — find-or-create ballot + contest for this election
  class ElectionEditorController < Admin::BaseController
    layout 'election_editor'

    before_action :set_election

    def show
      @payload = editor_payload
    end

    def save
      rows = (params[:rows] || []).map { |r| r.to_unsafe_h.with_indifferent_access }
      result = ElectionEditorSave.new(@election, current_user).call(
        rows: rows,
        deleted_candidate_ids: Array(params[:deletedCandidateIds])
      )
      render json: result
    end

    def people_search
      q = params[:q].to_s.strip
      return render json: { people: [] } if q.length < 2

      terms = q.split(/\s+/)
      scope = Person.all
      terms.each do |term|
        pattern = "%#{ActiveRecord::Base.sanitize_sql_like(term)}%"
        scope = scope.where(
          "first_name ILIKE :p OR last_name ILIKE :p OR middle_name ILIKE :p", p: pattern
        )
      end

      election_contest_ids = Contest.joins(:ballot).where(ballots: { election_id: @election.id }).pluck(:id)
      people = scope.includes(:social_media_accounts, :candidates, person_parties: :party)
                    .order(:last_name, :first_name).limit(8)

      render json: {
        people: people.map { |person|
          {
            id: person.id,
            firstName: person.first_name,
            lastName: person.last_name,
            fullName: person.full_name,
            state: person.state_of_residence,
            party: person.primary_party&.name&.sub(/ Party\z/, ""),
            gender: person.gender,
            race: person.race,
            inThisElection: person.candidates.any? { |c| election_contest_ids.include?(c.contest_id) },
            socials: socials_map(person)
          }
        }
      }
    end

    def offices_search
      q = params[:q].to_s.strip
      return render json: { offices: [] } if q.length < 2

      pattern = "%#{ActiveRecord::Base.sanitize_sql_like(q)}%"
      offices = Office.where(state: @election.state)
                      .where("title ILIKE :p OR seat ILIKE :p OR body_name ILIKE :p", p: pattern)
                      .order(:title, :seat).limit(12)

      render json: {
        offices: offices.map { |o|
          { id: o.id, label: o.display_name, level: o.level, branch: o.branch, body: o.body_name }
        }
      }
    end

    def create_contest
      office = Office.find(params[:office_id])
      party = params[:party].presence

      if @election.election_type == 'primary' && party.blank?
        return render json: { error: 'Party is required for primary contests' }, status: :unprocessable_entity
      end

      ballot = Ballot.find_or_create_by!(
        state: @election.state,
        date: @election.date,
        election_type: @election.election_type,
        party: party
      ) do |b|
        b.year = @election.year
        b.election_id = @election.id
      end
      ballot.update!(election_id: @election.id) if ballot.election_id.nil?

      contest = Contest.find_or_create_by!(office: office, ballot: ballot, date: ballot.date) do |c|
        c.party = ballot.party
        c.contest_type = ballot.election_type
      end

      render json: { contest: contest_json(contest) }
    rescue ActiveRecord::RecordInvalid => e
      render json: { error: e.record.errors.full_messages.join(', ') }, status: :unprocessable_entity
    end

    private

    def set_election
      @election = Election.find(params[:id])
    end

    def editor_payload
      contests = Contest.joins(:ballot)
                        .where(ballots: { election_id: @election.id })
                        .includes(:office, :ballot)
                        .sort_by { |c| [c.ballot.party.to_s, c.office.display_name] }

      candidates = Candidate.where(contest_id: contests.map(&:id))
                            .includes(person: :social_media_accounts)
                            .sort_by { |c| [c.contest_id, c.person.last_name, c.person.first_name] }

      {
        election: {
          id: @election.id,
          label: @election.full_name,
          state: @election.state,
          year: @election.year,
          type: @election.election_type,
          date: @election.date
        },
        urls: {
          save: admin_election_editor_save_path(@election),
          people: admin_election_editor_people_path(@election),
          offices: admin_election_editor_offices_path(@election),
          contests: admin_election_editor_contests_path(@election),
          back: admin_election_path(@election)
        },
        contests: contests.map { |c| contest_json(c) },
        # Party column uses the candidate vocabulary (party_at_time strings like
        # "Democratic"), NOT the parties table's org names ("Democratic Party").
        parties: party_options,
        contestParties: Contest::PARTIES.sort,
        platforms: SocialMediaAccount::PLATFORMS,
        outcomes: Candidate::OUTCOMES,
        genders: Person::GENDERS,
        races: Person.distinct.where.not(race: [nil, '']).pluck(:race).sort,
        rows: candidates.map { |c| candidate_row(c) }
      }
    end

    # Short display codes for the candidate party vocabulary; the full value is
    # what gets stored in candidates.party_at_time.
    PARTY_CODES = {
      "Democratic" => "DEM", "Republican" => "REP", "Libertarian" => "LIB",
      "Independent" => "IND", "Independent American" => "IAP",
      "Constitution" => "CST", "Forward" => "FWD", "Legal Marijuana NOW" => "LMN",
      "No Party Preference" => "NPP", "Nonpartisan" => "NON",
      "Peace and Freedom" => "PFP", "Unaffiliated" => "UNA", "Working Class" => "WCP"
    }.freeze

    def party_code(name)
      return nil if name.blank?

      PARTY_CODES[name] || name[0, 3].upcase
    end

    def party_options
      values = (Contest::PARTIES + Candidate.distinct.pluck(:party_at_time).compact).uniq.sort
      values.map { |value| { value: value, code: party_code(value) } }
    end

    def contest_json(contest)
      {
        id: contest.id,
        label: contest.office.display_name,
        ballotLabel: contest.ballot.full_name,
        party: contest.party,
        partyCode: party_code(contest.party)
      }
    end

    def candidate_row(candidate)
      person = candidate.person
      {
        candidateId: candidate.id,
        personId: person.id,
        contestId: candidate.contest_id,
        firstName: person.first_name,
        lastName: person.last_name,
        party: candidate.party_at_time,
        outcome: candidate.outcome,
        incumbent: candidate.incumbent,
        gender: person.gender,
        race: person.race,
        socials: socials_map(person)
      }
    end

    # One account per platform for grid display: prefer Campaign accounts,
    # then any with a handle or URL. Loaded associations only — no extra queries.
    CHANNEL_PRIORITY = ['Campaign', 'Official Office', 'Personal', nil].freeze

    def socials_map(person)
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
end
