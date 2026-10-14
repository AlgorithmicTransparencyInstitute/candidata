# One-off: apply statewide-office turnover found by reconciling prod against the
# CTCL GovProj export of 2026-09-24 (data/govproj/2026-09-24). For each office,
# ends the outgoing holder's term the day before the successor took office and
# adds the successor (creating the Person from CTCL data if needed).
#
# Idempotent: re-running is a no-op once applied. Dry run by default.
#
#   bin/rails govproj:apply_statewide_turnover            # dry run
#   APPLY=1 bin/rails govproj:apply_statewide_turnover    # write
namespace :govproj do
  STATEWIDE_TURNOVER_2026_09 = [
    { office_uuid: "4475b8b6-d37a-41f6-bfab-f01ae2c684b8", label: "VA Governor",
      person_uuid: "0f3e6a71-e8ee-41ab-98d6-1d7ea8cc38f8", first_name: "Abigail", last_name: "Spanberger",
      birth_date: "1979-08-07", website_official: "https://www.governor.virginia.gov/", party: "Democratic Party",
      start_date: "2026-01-17", term_end_date: "2030-01-12", next_election_date: "2029-11-06" },
    { office_uuid: "b35182a5-2e7e-4976-9ba7-7a62d7b49665", label: "VA Lieutenant Governor",
      person_uuid: "fcae7077-fbb2-4e42-9188-65d4aaa38508", first_name: "Ghazala", middle_name: "F.", last_name: "Hashmi",
      birth_date: "1964-07-05", website_official: "https://www.ltgov.virginia.gov/", party: "Democratic Party",
      start_date: "2026-01-17", term_end_date: "2030-01-12", next_election_date: "2029-11-06",
      # She vacated her state senate seat on becoming Lt. Gov.
      also_end_category: "State Senator" },
    { office_uuid: "016b238e-71b1-4d51-a71e-7c3453c7361b", label: "VA Attorney General",
      person_uuid: "6c1eb78a-417b-4819-a9ff-6dc2a1c30a97", first_name: "Jay", last_name: "Jones",
      birth_date: "1989-03-14", website_official: "https://www.oag.state.va.us/", party: "Democratic Party",
      start_date: "2026-01-17", term_end_date: "2030-01-12", next_election_date: "2029-11-06" },
    # CTCL has no start date for Caldwell; 2026-01-20 is the Sherrill/Caldwell inauguration.
    { office_uuid: "6b4264fb-d074-4bde-9f92-37c2faf0efb8", label: "NJ Lieutenant Governor",
      person_uuid: "327c6739-0e3a-4d0c-9f58-93d697d53d75", first_name: "Dale", middle_name: "G.", last_name: "Caldwell",
      birth_date: "1960-07-06", website_official: "https://www.nj.gov/governor/", party: "Democratic Party",
      start_date: "2026-01-20", term_end_date: "2030-01-15", next_election_date: "2029-11-06" },
    { office_uuid: "02d294ef-22d8-4f31-a2c0-19f8711c504c", label: "OH Attorney General",
      person_uuid: "9166a901-5ed1-4629-b92a-bf8882600f54", first_name: "Andy", last_name: "Wilson",
      website_official: "https://www.ohioattorneygeneral.gov/", party: "Republican Party",
      start_date: "2026-06-07", term_end_date: "2027-01-12", next_election_date: "2026-11-03" }
  ].freeze

  desc "Apply 2026-09 statewide officeholder turnover from CTCL (APPLY=1 to write)"
  task apply_statewide_turnover: :environment do
    apply = ENV["APPLY"] == "1"
    puts apply ? "APPLYING changes" : "DRY RUN (set APPLY=1 to write)"

    STATEWIDE_TURNOVER_2026_09.each do |t|
      ActiveRecord::Base.transaction do
        office = Office.find_by!(airtable_id: t[:office_uuid])
        start  = Date.parse(t[:start_date])
        ended_on = start - 1
        puts "\n#{t[:label]} (office ##{office.id})"

        person = Person.find_by(person_uuid: t[:person_uuid])
        if person
          puts "  person exists: ##{person.id} #{person.first_name} #{person.last_name}"
        else
          puts "  create person: #{t[:first_name]} #{t[:last_name]}"
          person = Person.create!(
            person_uuid: t[:person_uuid], first_name: t[:first_name], middle_name: t[:middle_name],
            last_name: t[:last_name], birth_date: t[:birth_date] && Date.parse(t[:birth_date]),
            website_official: t[:website_official], state_of_residence: office.state
          ) if apply
        end

        office.officeholders.current.where.not(person_id: person&.id).includes(:person).each do |h|
          puts "  end term: #{h.person.first_name} #{h.person.last_name} (started #{h.start_date}) -> end_date #{ended_on}"
          h.update!(end_date: ended_on) if apply
        end

        if t[:also_end_category] && person&.persisted?
          person.officeholders.current.joins(:office)
                .where(offices: { office_category: t[:also_end_category], state: office.state }).each do |h|
            puts "  end prior office: #{h.office.title} (started #{h.start_date}) -> end_date #{ended_on}"
            h.update!(end_date: ended_on) if apply
          end
        end

        if person&.persisted? && office.officeholders.current.exists?(person_id: person.id)
          puts "  already current holder - skip"
        else
          puts "  add officeholder from #{start} (term ends #{t[:term_end_date]})"
          if apply
            Officeholder.create!(
              person: person, office: office, start_date: start,
              term_end_date: Date.parse(t[:term_end_date]), next_election_date: Date.parse(t[:next_election_date])
            )
          end
        end

        party = Party.find_by!(name: t[:party])
        if apply && !person.parties.include?(party)
          person.add_party(party, is_primary: person.parties.empty?)
          puts "  linked party: #{party.name}"
        end
      end
    end
  end
end
