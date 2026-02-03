namespace :extract do
  desc "Analyze office types and categories from temp_people data"
  task analyze_offices: :environment do
    puts "=" * 70
    puts "OFFICE ANALYSIS FROM TEMP DATA"
    puts "=" * 70

    puts "\n=== OFFICE CATEGORIES (#{TempPerson.distinct.count(:office_category)}) ==="
    TempPerson.where.not(office_category: [nil, ''])
              .group(:office_category)
              .count
              .sort_by { |k, v| -v }
              .each do |cat, count|
      puts "  #{count.to_s.rjust(5)} | #{cat}"
    end

    puts "\n=== ROLES (#{TempPerson.distinct.count(:role)}) ==="
    TempPerson.where.not(role: [nil, ''])
              .group(:role)
              .count
              .sort_by { |k, v| -v }
              .each do |role, count|
      level_map = map_role_to_branch(role)
      puts "  #{count.to_s.rjust(5)} | #{role} → branch: #{level_map}"
    end

    puts "\n=== LEVELS (#{TempPerson.distinct.count(:level)}) ==="
    TempPerson.where.not(level: [nil, ''])
              .group(:level)
              .count
              .sort_by { |k, v| -v }
              .each do |level, count|
      mapped = map_level(level)
      puts "  #{count.to_s.rjust(5)} | #{level} → #{mapped}"
    end

    puts "\n=== UNIQUE BODY NAMES (#{TempPerson.distinct.count(:body_name)}) ==="
    puts "  (showing top 30)"
    TempPerson.where.not(body_name: [nil, ''])
              .group(:body_name)
              .count
              .sort_by { |k, v| -v }
              .first(30)
              .each do |body, count|
      puts "  #{count.to_s.rjust(5)} | #{body}"
    end

    puts "\n=== OFFICE CATEGORY + ROLE COMBINATIONS ==="
    TempPerson.where.not(office_category: [nil, ''])
              .where.not(role: [nil, ''])
              .group(:office_category, :role)
              .count
              .sort_by { |k, v| -v }
              .first(25)
              .each do |(cat, role), count|
      puts "  #{count.to_s.rjust(5)} | #{cat} (#{role})"
    end

    puts "\n" + "=" * 70
  end

  desc "Show level mapping for import"
  task level_mapping: :environment do
    puts "Level Mapping (Airtable → Candidata):"
    puts "  country → federal"
    puts "  administrativeArea1 → state"
    puts "  administrativeArea2 → local (county)"
    puts "  locality → local"
    puts
    puts "Role → Branch Mapping:"
    puts "  legislatorLowerBody → legislative"
    puts "  legislatorUpperBody → legislative"
    puts "  headOfGovernment → executive"
    puts "  deputyHeadOfGovernment → executive"
    puts "  governmentOfficer → executive"
    puts "  highestCourtJudge → judicial"
    puts "  schoolBoard → executive (local)"
  end
end

def map_level(airtable_level)
  case airtable_level
  when 'country' then 'federal'
  when 'administrativeArea1' then 'state'
  when 'administrativeArea2' then 'local'
  when 'locality' then 'local'
  else 'unknown'
  end
end

def map_role_to_branch(role)
  case role
  when 'legislatorLowerBody', 'legislatorUpperBody'
    'legislative'
  when 'headOfGovernment', 'deputyHeadOfGovernment', 'governmentOfficer', 'schoolBoard'
    'executive'
  when 'highestCourtJudge'
    'judicial'
  else
    'unknown'
  end
end
