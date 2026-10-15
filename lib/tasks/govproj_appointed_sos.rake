# One-off: add the 12 appointed Secretary of State offices that the CTCL GovProj
# export of 2026-09-24 has but prod lacked (the original GovProj import skipped
# them), plus each current holder. The office UUID becomes offices.airtable_id
# and the person UUID people.person_uuid, matching the rest of the GovProj data.
#
# Idempotent: re-running is a no-op once applied. Dry run by default.
#
#   bin/rails govproj:add_appointed_secretaries_of_state            # dry run
#   APPLY=1 bin/rails govproj:add_appointed_secretaries_of_state    # write
namespace :govproj do
  APPOINTED_SOS_2026_09 = [
    { state: "DE", jurisdiction: "Delaware", title: "DE State Secretary of State", office_uuid: "23718d56-da20-4eae-9e52-16898329b3fe",
      person_uuid: "7ddc0364-92e6-4bce-8dcf-c3b6524c6eab", first_name: "Charuni", last_name: "Patibanda-Sanchez",
      party: "Democratic Party", website_official: "https://sos.delaware.gov/", start_date: "2025-01-28" },
    { state: "FL", jurisdiction: "Florida", title: "FL Secretary of State", office_uuid: "ec00e6c3-4308-49fc-882f-77d8ebb66af2",
      person_uuid: "94cc46ab-da2e-4a7d-9137-82a73bdcee09", first_name: "Cord", last_name: "Byrd", birth_date: "1971-04-19",
      party: "Republican Party", website_official: "https://dos.fl.gov/", start_date: "2022-05-16" },
    { state: "ME", jurisdiction: "Maine", title: "ME Secretary of State", office_uuid: "b349dbbf-ee00-4bf1-9709-9e6ec65c28a6",
      person_uuid: "d14de1d6-5702-4c30-8659-1150a207e242", first_name: "Shenna", last_name: "Bellows",
      party: "Democratic Party", website_official: "https://www.maine.gov/sos/", start_date: "2021-01-04" },
    { state: "NH", jurisdiction: "New Hampshire", title: "NH Secretary of State", office_uuid: "30334563-3f8a-4163-a955-6c4fad59e353",
      person_uuid: "0f89619d-4788-46c5-9ea3-ecef09f2590a", first_name: "David", middle_name: "M.", last_name: "Scanlan",
      party: "Republican Party", website_official: "https://www.sos.nh.gov/", start_date: "2022-12-07" },
    # Caldwell is also NJ Lt. Governor (added by govproj:apply_statewide_turnover).
    { state: "NJ", jurisdiction: "New Jersey", title: "NJ Secretary of State", office_uuid: "7b2bdd14-af58-4b02-91fc-83e7c38bdf25",
      person_uuid: "327c6739-0e3a-4d0c-9f58-93d697d53d75", first_name: "Dale", middle_name: "G.", last_name: "Caldwell", birth_date: "1960-07-06",
      party: "Democratic Party", website_official: "https://www.nj.gov/state/", start_date: "2026-01-20" },
    { state: "NY", jurisdiction: "New York", title: "NY Secretary of State", office_uuid: "8a9a358a-fa38-421c-bfb6-13bb970cb145",
      person_uuid: "99f9b8fc-509c-4993-a42c-540a427b0731", first_name: "Walter", middle_name: "T.", last_name: "Mosley",
      party: "Democratic Party", website_official: "https://dos.ny.gov/", start_date: "2024-05-22" },
    { state: "OK", jurisdiction: "Oklahoma", title: "OK Secretary of State", office_uuid: "f729e17a-d753-45e9-a315-926a43f2aa3c",
      person_uuid: "4c9f263d-8941-45c7-814d-e7e959458ca3", first_name: "Benjamin", middle_name: "M.", last_name: "Lepak",
      party: "Republican Party", website_official: "https://www.sos.ok.gov/", start_date: "2025-10-02" },
    { state: "PA", jurisdiction: "Pennsylvania", title: "Secretary of the Commonwealth of Pennsylvania", office_uuid: "5e913ac8-c43e-4ef5-a248-ba85b68c89e7",
      person_uuid: "63c080c1-1bde-40b5-9f2b-9070f1bd0c47", first_name: "Al", last_name: "Schmidt",
      party: "Republican Party", website_official: "https://www.pa.gov/agencies/dos", start_date: "2023-01-17" },
    { state: "PR", jurisdiction: "Puerto Rico", title: "PR Secretary of State", office_uuid: "c00029f2-1686-4842-9b98-939fb3056088",
      ocdid: "ocd-division/country:us/territory:pr",
      person_uuid: "1c57ce3b-bb5b-4e52-8baa-323277ea7b5e", first_name: "Rosachely", last_name: "Rivera Santana", birth_date: "1980-04-05",
      party: "Partido Nuevo Progresista", website_official: "https://www.estado.pr.gov/departamento-de-estado", start_date: "2025-06-30" },
    { state: "TN", jurisdiction: "Tennessee", title: "TN Secretary of State", office_uuid: "a09e4110-e5f1-4c1a-8ca7-58e4e3addbc1",
      person_uuid: "4e5bc904-6299-43fb-9e17-141558a0b6c8", first_name: "Tre", last_name: "Hargett",
      party: "Republican Party", website_official: "https://sos.tn.gov/", start_date: "2009-01-15" },
    { state: "TX", jurisdiction: "Texas", title: "TX Secretary of State", office_uuid: "16662317-1a3d-4040-a1f7-7a7aebf1d8d3",
      person_uuid: "0ce0e2b5-11c4-4126-8609-9e118a9af9ec", first_name: "Robert", last_name: "Howden",
      party: "Republican Party", website_official: "https://www.sos.state.tx.us/index.shtml", start_date: "2026-07-18", term_end_date: "2027-01-19" },
    { state: "VA", jurisdiction: "Virginia", title: "Secretary of the Commonwealth of Virginia", office_uuid: "66ffce39-53a3-491a-ab59-8626950d70ca",
      person_uuid: "9f09f2df-0443-4c69-bd69-551c16dc91c0", first_name: "Candi", last_name: "King",
      party: "Democratic Party", website_official: "https://www.commonwealth.virginia.gov/", start_date: "2026-01-17",
      # She left her House of Delegates seat to take this post.
      also_end_category: "State Representative" }
  ].freeze

  desc "Add the 12 appointed Secretary of State offices missing from GovProj import (APPLY=1 to write)"
  task add_appointed_secretaries_of_state: :environment do
    apply = ENV["APPLY"] == "1"
    puts apply ? "APPLYING changes" : "DRY RUN (set APPLY=1 to write)"

    APPOINTED_SOS_2026_09.each do |t|
      ActiveRecord::Base.transaction do
        puts "\n#{t[:title]}"
        ocdid = t[:ocdid] || "ocd-division/country:us/state:#{t[:state].downcase}"

        office = Office.find_by(airtable_id: t[:office_uuid])
        if office
          puts "  office exists: ##{office.id}"
        else
          puts "  create office"
          office = Office.new(
            airtable_id: t[:office_uuid], title: t[:title], level: "state", branch: "executive",
            state: t[:state], office_category: "Secretary of State", role: "governmentOfficer",
            jurisdiction: t[:jurisdiction], jurisdiction_ocdid: ocdid, ocdid: ocdid
          )
          office.save! if apply
        end

        person = Person.find_by(person_uuid: t[:person_uuid])
        if person
          puts "  person exists: ##{person.id} #{person.first_name} #{person.last_name}"
        else
          puts "  create person: #{t[:first_name]} #{t[:last_name]}"
          person = Person.new(
            person_uuid: t[:person_uuid], first_name: t[:first_name], middle_name: t[:middle_name],
            last_name: t[:last_name], birth_date: t[:birth_date] && Date.parse(t[:birth_date]),
            website_official: t[:website_official], state_of_residence: t[:state]
          )
          person.save! if apply
        end

        if office.persisted? && person.persisted? && office.officeholders.current.exists?(person_id: person.id)
          puts "  already current holder - skip"
        else
          puts "  add appointed officeholder from #{t[:start_date]}"
          if apply
            Officeholder.create!(
              person: person, office: office, appointed: true, start_date: Date.parse(t[:start_date]),
              term_end_date: t[:term_end_date] && Date.parse(t[:term_end_date])
            )
          end
        end

        if t[:also_end_category] && person.persisted?
          ended_on = Date.parse(t[:start_date]) - 1
          person.officeholders.current.joins(:office)
                .where(offices: { office_category: t[:also_end_category], state: t[:state] }).each do |h|
            puts "  end prior office: #{h.office.title} (started #{h.start_date}) -> end_date #{ended_on}"
            h.update!(end_date: ended_on) if apply
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
