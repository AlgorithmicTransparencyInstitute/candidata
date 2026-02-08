namespace :govproj do
  desc "Fast bulk import from temp_govproj using batching and preloading"
  task import_from_temp_fast: :environment do
    puts "=" * 70
    puts "FAST BULK IMPORT FROM TEMP_GOVPROJ"
    puts "=" * 70
    puts "Records to process: #{TempGovproj.count}"
    puts "Using bulk inserts and preloading for performance"
    puts "=" * 70

    stats = {
      offices_created: 0, offices_skipped: 0,
      people_created: 0, people_found: 0,
      officeholders_created: 0, officeholders_skipped: 0,
      social_accounts: 0, party_links: 0,
      errors: []
    }

    # Helper functions
    map_level = ->(level) {
      case level
      when 'country' then 'federal'
      when 'administrativeArea1' then 'state'
      when 'administrativeArea2', 'locality', 'regional' then 'local'
      else 'local'
      end
    }

    map_branch = ->(role) {
      case role
      when 'legislatorLowerBody', 'legislatorUpperBody' then 'legislative'
      when 'headOfGovernment', 'deputyHeadOfGovernment', 'governmentOfficer', 'executiveCouncil', 'schoolBoard' then 'executive'
      when 'highestCourtJudge', 'judge' then 'judicial'
      else 'executive'
      end
    }

    parse_name = ->(full_name) {
      return { first_name: 'Unknown', last_name: 'Unknown' } if full_name.blank?
      name = full_name.dup
      suffixes = ['Jr.', 'Jr', 'Sr.', 'Sr', 'II', 'III', 'IV', 'V']
      suffix = nil
      suffixes.each do |s|
        pattern = Regexp.new('[,\s]\s*' + Regexp.escape(s) + '\.?\s*$', Regexp::IGNORECASE)
        if name.match?(pattern)
          suffix = s.sub(/\.$/, '')
          suffix = suffix + '.' if ['Jr', 'Sr'].include?(suffix)
          name = name.sub(pattern, '').strip
          break
        end
      end
      parts = name.split(/\s+/)
      if parts.length == 1
        { first_name: parts[0], last_name: 'Unknown', suffix: suffix }
      elsif parts.length == 2
        { first_name: parts[0], last_name: parts[1], suffix: suffix }
      else
        { first_name: parts[0], middle_name: parts[1..-2].join(' '), last_name: parts[-1], suffix: suffix }
      end
    }

    parse_date = ->(str) {
      return nil if str.blank?
      Date.parse(str) rescue nil
    }

    # Preload all existing data into memory hashes
    puts "\nPreloading existing data..."
    existing_offices = Office.pluck(:airtable_id, :id).to_h
    existing_people = Person.pluck(:person_uuid, :id).to_h
    parties_by_name = Party.pluck(:name, :id).to_h
    bodies_by_name = Body.pluck(:name, :id).to_h
    puts "Loaded: #{existing_offices.size} offices, #{existing_people.size} people, #{parties_by_name.size} parties, #{bodies_by_name.size} bodies"

    # Batch insert arrays
    offices_to_insert = []
    people_to_insert = []
    officeholders_to_insert = []
    social_accounts_to_insert = []
    person_parties_to_insert = []

    processed = 0
    total_records = TempGovproj.count
    batch_size = 1000

    # Process records in batches
    TempGovproj.find_in_batches(batch_size: batch_size) do |batch|
      batch.each do |row|
        office_uuid = row.office_uuid
        person_uuid = row.person_uuid
        next if office_uuid.blank? || person_uuid.blank?

        # Prepare office data
        unless existing_offices[office_uuid]
          # Check if body exists, otherwise queue it for creation
          body_id = nil
          if row.body_name.present?
            body_id = bodies_by_name[row.body_name]
            unless body_id
              # Create body immediately (these are rare)
              body = Body.create!(
                name: row.body_name,
                country: row.state,
                classification: 'legislature'
              )
              body_id = body.id
              bodies_by_name[row.body_name] = body_id
            end
          end

          offices_to_insert << {
            airtable_id: office_uuid,
            title: row.office_name || 'Unknown Office',
            level: map_level.call(row.level),
            branch: map_branch.call(row.role),
            role: row.role,
            state: row.state,
            office_category: row.office_category,
            body_name: row.body_name,
            body_id: body_id,
            seat: row.seat.presence,
            jurisdiction: row.jurisdiction,
            jurisdiction_ocdid: row.jurisdiction_ocdid,
            ocdid: row.electoral_district_ocdid,
            county: row.county.presence,
            created_at: Time.current,
            updated_at: Time.current
          }
          stats[:offices_created] += 1
        else
          stats[:offices_skipped] += 1
        end

        # Prepare person data
        unless existing_people[person_uuid]
          np = parse_name.call(row.official_name)
          people_to_insert << {
            person_uuid: person_uuid,
            first_name: np[:first_name],
            last_name: np[:last_name],
            middle_name: np[:middle_name],
            suffix: np[:suffix],
            birth_date: parse_date.call(row.dob),
            photo_url: row.photo_url.presence,
            website_official: row.website_official.presence,
            wikipedia_id: row.wiki_word.presence,
            state_of_residence: row.state,
            created_at: Time.current,
            updated_at: Time.current
          }
          stats[:people_created] += 1
        else
          stats[:people_found] += 1
        end

        processed += 1
      end

      # Bulk insert offices every batch
      if offices_to_insert.any?
        Office.insert_all(offices_to_insert)
        # Reload office IDs
        new_office_ids = Office.where(airtable_id: offices_to_insert.map { |o| o[:airtable_id] }).pluck(:airtable_id, :id).to_h
        existing_offices.merge!(new_office_ids)
        offices_to_insert = []
      end

      # Bulk insert people every batch
      if people_to_insert.any?
        Person.insert_all(people_to_insert)
        # Reload person IDs
        new_person_ids = Person.where(person_uuid: people_to_insert.map { |p| p[:person_uuid] }).pluck(:person_uuid, :id).to_h
        existing_people.merge!(new_person_ids)
        people_to_insert = []
      end

      # Now prepare officeholders and social accounts for this batch
      batch.each do |row|
        office_uuid = row.office_uuid
        person_uuid = row.person_uuid
        next if office_uuid.blank? || person_uuid.blank?

        office_id = existing_offices[office_uuid]
        person_id = existing_people[person_uuid]
        next unless office_id && person_id

        # Prepare officeholder
        start_date = parse_date.call(row.officeholder_start) || Date.current
        officeholders_to_insert << {
          person_id: person_id,
          office_id: office_id,
          start_date: start_date,
          term_end_date: parse_date.call(row.term_end),
          next_election_date: parse_date.call(row.next_election_date),
          official_email: row.gov_email.presence,
          official_phone: row.gov_phone.presence,
          official_address: row.gov_mailing_address.presence,
          contact_form_url: row.gov_email_form.presence,
          created_at: Time.current,
          updated_at: Time.current
        }
        stats[:officeholders_created] += 1

        # Prepare party link
        party_name = row.party_roll_up
        if party_name.present?
          party_id = parties_by_name[party_name]
          if party_id
            person_parties_to_insert << {
              person_id: person_id,
              party_id: party_id,
              is_primary: false, # Will update primaries later
              created_at: Time.current,
              updated_at: Time.current
            }
            stats[:party_links] += 1
          end
        end

        # Prepare social accounts
        social_data = {
          'Twitter' => row.twitter_name_gov,
          'Facebook' => row.facebook_url_gov,
          'Instagram' => row.instagram_url_gov,
          'YouTube' => row.youtube_gov,
          'TikTok' => row.tiktok_gov,
          'Threads' => row.threads_gov
        }
        social_data.each do |platform, handle_or_url|
          next if handle_or_url.blank?

          social_accounts_to_insert << {
            person_id: person_id,
            platform: platform,
            handle: handle_or_url,
            url: handle_or_url.start_with?('http') ? handle_or_url : nil,
            channel_type: 'Official Office',
            verified: true,
            created_at: Time.current,
            updated_at: Time.current
          }
          stats[:social_accounts] += 1
        end
      end

      # Bulk insert officeholders, party links, and social accounts
      Officeholder.insert_all(officeholders_to_insert) if officeholders_to_insert.any?

      # Use insert_all with on_duplicate for person_parties to avoid unique constraint errors
      if person_parties_to_insert.any?
        PersonParty.insert_all(person_parties_to_insert, unique_by: [:person_id, :party_id])
      end

      if social_accounts_to_insert.any?
        SocialMediaAccount.insert_all(social_accounts_to_insert, unique_by: [:person_id, :platform, :handle])
      end

      # Clear arrays
      officeholders_to_insert = []
      person_parties_to_insert = []
      social_accounts_to_insert = []

      percent = ((processed.to_f / total_records) * 100).round(1)
      puts "Processed #{processed}/#{total_records} (#{percent}%) - People: #{stats[:people_created]}, Offices: #{stats[:offices_created]}, Officeholders: #{stats[:officeholders_created]}"
    end

    puts "\n\n" + "=" * 70
    puts "IMPORT COMPLETE"
    puts "=" * 70
    puts "  Processed: #{processed}"
    puts "  Offices: #{stats[:offices_created]} created, #{stats[:offices_skipped]} existed"
    puts "  People: #{stats[:people_created]} created, #{stats[:people_found]} existed"
    puts "  Officeholders: #{stats[:officeholders_created]} created"
    puts "  Party links: #{stats[:party_links]}"
    puts "  Social accounts: #{stats[:social_accounts]}"
    puts "\nDB Totals:"
    puts "  People: #{Person.count}"
    puts "  Offices: #{Office.count}"
    puts "  Officeholders: #{Officeholder.count}"
    puts "  SocialMediaAccounts: #{SocialMediaAccount.count}"
    puts "=" * 70
  end
end
