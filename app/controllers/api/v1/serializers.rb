module Api
  module V1
    # Hand-rolled JSON shapes for the public API. This is the public contract:
    # change shapes here only additively (docs/PUBLIC_API.md documents them).
    # Workflow fields (research_status, verified_by, junkipedia_*, etc.) must
    # never appear here. Socials: verified + active + has a URL.
    module Serializers
      def person_core_json(person)
        {
          id: person.id,
          person_uuid: person.person_uuid,
          first_name: person.first_name,
          middle_name: person.middle_name,
          last_name: person.last_name,
          suffix: person.suffix,
          full_name: person.full_name,
          state_of_residence: person.state_of_residence,
          gender: person.gender,
          race: person.race,
          photo_url: person.photo_url,
          wikipedia_id: person.wikipedia_id,
          websites: {
            official: person.website_official,
            campaign: person.website_campaign,
            personal: person.website_personal
          },
          party: party_ref(primary_party_of(person)),
          parties: person.person_parties.map { |pp|
            party_ref(pp.party).merge(is_primary: pp.is_primary == true)
          },
          social_media_accounts: verified_socials(person).map { |a| social_json(a) },
          updated_at: person.updated_at&.iso8601
        }
      end

      def person_full_json(person)
        person_core_json(person).merge(
          current_offices: person.officeholders.select(&:current?).map { |oh|
            office_json(oh.office).merge(start_date: oh.start_date, elected_year: oh.elected_year)
          },
          candidacies: person.candidates.map { |c|
            {
              id: c.id,
              outcome: c.outcome,
              winner: c.winner?,
              incumbent: c.incumbent == true,
              party_at_time: c.party_at_time,
              tally: c.tally,
              contest: {
                id: c.contest.id,
                name: c.contest.full_name,
                contest_type: c.contest.contest_type,
                party: c.contest.party,
                date: c.contest.date
              }
            }
          }
        )
      end

      # Loaded-association-safe primary party (avoids N+1 in index actions),
      # with the legacy party_affiliation fallback Person#primary_party uses.
      def primary_party_of(person)
        person.person_parties.find { |pp| pp.is_primary }&.party || person.party_affiliation
      end

      # A verified account with no URL is a confirmed *absence* — a verifier
      # attesting the candidate has no account on that platform. It is a real
      # research finding, but it is not a channel, so it never ships to consumers.
      def verified_socials(person)
        person.social_media_accounts.select { |a| a.verified && !a.account_inactive && a.url.present? }
      end

      def social_json(account)
        {
          platform: account.platform,
          handle: account.handle,
          url: account.url,
          channel_type: account.channel_type
        }
      end

      def party_ref(party)
        return nil unless party

        { name: party.name, abbreviation: party.abbreviation }
      end

      def office_json(office)
        {
          id: office.id,
          title: office.title,
          level: office.level,
          branch: office.branch,
          role: office.role,
          office_category: office.office_category,
          body_name: office.body_name,
          state: office.state,
          seat: office.seat,
          county: office.county,
          jurisdiction: office.jurisdiction,
          ocdid: office.ocdid,
          district: district_json(office.district)
        }
      end

      def district_json(district)
        return nil unless district

        {
          state: district.state,
          district_number: district.district_number,
          chamber: district.chamber,
          level: district.level,
          ocdid: district.ocdid
        }
      end

      def contest_json(contest)
        ballot = contest.ballot
        {
          id: contest.id,
          name: contest.full_name,
          contest_type: contest.contest_type,
          party: contest.party,
          date: contest.date,
          office: office_json(contest.office),
          ballot: ballot && {
            id: ballot.id,
            state: ballot.state,
            date: ballot.date,
            election_type: ballot.election_type,
            party: ballot.party,
            year: ballot.year,
            election: ballot.election && {
              id: ballot.election.id,
              state: ballot.election.state,
              date: ballot.election.date,
              election_type: ballot.election.election_type,
              year: ballot.election.year
            }
          }
        }
      end
    end
  end
end
