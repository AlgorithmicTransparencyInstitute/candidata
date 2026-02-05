namespace :merge do
  desc "Merge temp_people into People table (creates new + updates existing)"
  task people: :environment do
    puts "=" * 70
    puts "MERGING TEMP_PEOPLE INTO PEOPLE"
    puts "=" * 70

    stats = {
      created: 0,
      updated: 0,
      skipped: 0,
      party_links: 0,
      errors: []
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

    total = TempPerson.where.not(person_uuid: [nil, '']).count
    puts "Processing #{total} temp_people records with person_uuid..."

    processed = 0
    TempPerson.where.not(person_uuid: [nil, '']).find_each do |tp|
      begin
        person = Person.find_by(person_uuid: tp.person_uuid)

        if person
          # Update existing person with new data (only if temp has data and person doesn't)
          updates = {}
          updates[:race] = tp.race if tp.race.present? && person.race.blank?
          updates[:gender] = tp.gender if tp.gender.present? && person.gender.blank?
          updates[:photo_url] = tp.photo_url if tp.photo_url.present? && person.photo_url.blank?
          updates[:website_official] = tp.website_official if tp.website_official.present? && person.website_official.blank?
          updates[:website_campaign] = tp.website_campaign if tp.website_campaign.present? && person.website_campaign.blank?
          updates[:website_personal] = tp.website_personal if tp.website_personal.present? && person.website_personal.blank?

          if updates.any?
            person.update!(updates)
            stats[:updated] += 1
          else
            stats[:skipped] += 1
          end
        else
          # Create new person
          np = parse_name.call(tp.official_name)
          person = Person.create!(
            person_uuid: tp.person_uuid,
            first_name: np[:first_name],
            last_name: np[:last_name],
            middle_name: np[:middle_name],
            suffix: np[:suffix],
            race: tp.race.presence,
            gender: tp.gender.presence,
            photo_url: tp.photo_url.presence,
            website_official: tp.website_official.presence,
            website_campaign: tp.website_campaign.presence,
            website_personal: tp.website_personal.presence,
            state_of_residence: tp.state.presence
          )
          stats[:created] += 1
        end

        # Link party if present
        if tp.party_roll_up.present?
          party = Party.find_by(name: tp.party_roll_up)
          if party && !person.parties.include?(party)
            person.add_party(party, is_primary: person.parties.empty?)
            stats[:party_links] += 1
          end
        end

        processed += 1
        print "." if processed % 500 == 0

      rescue => e
        stats[:errors] << "#{tp.official_name} (#{tp.person_uuid}): #{e.message}"
      end
    end

    puts "\n\n" + "=" * 70
    puts "PEOPLE MERGE COMPLETE"
    puts "=" * 70
    puts "  Created: #{stats[:created]}"
    puts "  Updated: #{stats[:updated]}"
    puts "  Skipped (no new data): #{stats[:skipped]}"
    puts "  Party links added: #{stats[:party_links]}"
    puts "  Errors: #{stats[:errors].length}"
    stats[:errors].first(10).each { |e| puts "    - #{e}" } if stats[:errors].any?
    puts "\n  Total People now: #{Person.count}"
    puts "=" * 70
  end

  desc "Merge temp_accounts into SocialMediaAccounts table"
  task accounts: :environment do
    puts "=" * 70
    puts "MERGING TEMP_ACCOUNTS INTO SOCIAL_MEDIA_ACCOUNTS"
    puts "=" * 70

    stats = {
      created: 0,
      skipped_no_url: 0,
      skipped_exists: 0,
      skipped_no_person: 0,
      errors: []
    }

    # Build a lookup of people by name for matching
    # Since temp_accounts uses people_name, we need to match to Person records
    puts "Building person lookup..."
    
    total = TempAccount.where.not(url: [nil, '']).count
    puts "Processing #{total} temp_accounts with URLs..."

    processed = 0
    TempAccount.where.not(url: [nil, '']).find_each do |ta|
      begin
        if ta.url.blank?
          stats[:skipped_no_url] += 1
          next
        end

        # Normalize URL for comparison
        url = ta.url.strip
        handle = extract_handle(url, ta.platform)

        # Check if account already exists (by URL or handle+platform)
        existing = SocialMediaAccount.find_by(url: url)
        existing ||= SocialMediaAccount.find_by(handle: handle, platform: ta.platform) if handle.present?
        
        if existing
          stats[:skipped_exists] += 1
          next
        end

        # Find the person by name match
        person = find_person_by_name(ta.people_name)
        
        unless person
          stats[:skipped_no_person] += 1
          next
        end

        # Map channel_type
        channel_type = case ta.channel_type
                       when /Official Office/i then 'Official Office'
                       when /Campaign/i then 'Campaign'
                       when /Personal/i then 'Personal'
                       else 'Official Office'
                       end

        SocialMediaAccount.create!(
          person: person,
          platform: ta.platform,
          handle: handle,
          url: url,
          channel_type: channel_type,
          verified: ta.verified == true || ta.status&.include?('complete')
        )
        stats[:created] += 1

        processed += 1
        print "." if processed % 500 == 0

      rescue => e
        stats[:errors] << "#{ta.people_name} - #{ta.url}: #{e.message}"
      end
    end

    puts "\n\n" + "=" * 70
    puts "ACCOUNTS MERGE COMPLETE"
    puts "=" * 70
    puts "  Created: #{stats[:created]}"
    puts "  Skipped (no URL): #{stats[:skipped_no_url]}"
    puts "  Skipped (exists): #{stats[:skipped_exists]}"
    puts "  Skipped (no person match): #{stats[:skipped_no_person]}"
    puts "  Errors: #{stats[:errors].length}"
    stats[:errors].first(10).each { |e| puts "    - #{e}" } if stats[:errors].any?
    puts "\n  Total SocialMediaAccounts now: #{SocialMediaAccount.count}"
    puts "=" * 70
  end

  desc "Full merge: people first, then accounts"
  task all: [:people, :accounts]

  private

  def extract_handle(url, platform)
    return nil if url.blank?
    
    case platform
    when 'Twitter'
      url.match(%r{twitter\.com/(@?[\w]+)|x\.com/(@?[\w]+)})&.captures&.compact&.first&.delete('@')
    when 'Facebook'
      url.match(%r{facebook\.com/([\w.]+)})&.captures&.first
    when 'Instagram'
      url.match(%r{instagram\.com/([\w.]+)})&.captures&.first
    when 'YouTube'
      url.match(%r{youtube\.com/(@?[\w]+)|youtube\.com/channel/([\w]+)})&.captures&.compact&.first
    when 'TikTok'
      url.match(%r{tiktok\.com/@?([\w.]+)})&.captures&.first
    else
      url.split('/').last&.delete('@')
    end
  end

  def find_person_by_name(name)
    return nil if name.blank?
    
    # Try exact full name match first
    parts = name.strip.split(/\s+/)
    return nil if parts.length < 2
    
    first_name = parts.first
    last_name = parts.last
    
    # Try exact match
    person = Person.where("LOWER(first_name) = ? AND LOWER(last_name) = ?", 
                          first_name.downcase, last_name.downcase).first
    return person if person
    
    # Try with middle name variations
    if parts.length > 2
      person = Person.where("LOWER(first_name) = ? AND LOWER(last_name) = ?",
                            first_name.downcase, last_name.downcase).first
    end
    
    person
  end
end

# Make helper methods available at module level
def extract_handle(url, platform)
  return nil if url.blank?
  
  case platform
  when 'Twitter'
    url.match(%r{twitter\.com/(@?[\w]+)|x\.com/(@?[\w]+)})&.captures&.compact&.first&.delete('@')
  when 'Facebook'
    url.match(%r{facebook\.com/([\w.]+)})&.captures&.first
  when 'Instagram'
    url.match(%r{instagram\.com/([\w.]+)})&.captures&.first
  when 'YouTube'
    url.match(%r{youtube\.com/(@?[\w]+)|youtube\.com/channel/([\w]+)})&.captures&.compact&.first
  when 'TikTok'
    url.match(%r{tiktok\.com/@?([\w.]+)})&.captures&.first
  else
    url.split('/').last&.delete('@')
  end
end

def find_person_by_name(name)
  return nil if name.blank?
  
  # Try exact full name match first
  parts = name.strip.split(/\s+/)
  return nil if parts.length < 2
  
  first_name = parts.first
  last_name = parts.last
  
  # Try exact match
  person = Person.where("LOWER(first_name) = ? AND LOWER(last_name) = ?", 
                        first_name.downcase, last_name.downcase).first
  return person if person
  
  # Try with middle name variations
  if parts.length > 2
    person = Person.where("LOWER(first_name) = ? AND LOWER(last_name) = ?",
                          first_name.downcase, last_name.downcase).first
  end
  
  person
end
