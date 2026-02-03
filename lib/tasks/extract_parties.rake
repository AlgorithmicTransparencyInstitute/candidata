namespace :extract do
  desc "Extract unique individual parties from temp_people data"
  task parties: :environment do
    puts "Extracting unique parties from temp_people data..."
    
    # Get all unique party strings from temp_people
    party_strings = TempPerson.where.not(registered_political_party: [nil, ''])
                              .distinct
                              .pluck(:registered_political_party)
    
    puts "Found #{party_strings.length} unique party strings"
    
    # Split combo parties and collect all individual parties
    individual_parties = Set.new
    
    party_strings.each do |party_string|
      # Split on comma, but be careful with party names that might have commas
      # Most combos use ", " as separator
      parts = party_string.split(/,\s*/)
      parts.each do |part|
        cleaned = part.strip
        individual_parties.add(cleaned) if cleaned.present?
      end
    end
    
    puts "\n" + "=" * 60
    puts "EXTRACTED #{individual_parties.length} UNIQUE INDIVIDUAL PARTIES"
    puts "=" * 60
    
    # Sort alphabetically for display
    sorted_parties = individual_parties.to_a.sort
    
    sorted_parties.each_with_index do |party, idx|
      puts "  #{idx + 1}. #{party}"
    end
    
    puts "\n" + "=" * 60
  end

  desc "Create Party records from extracted unique parties"
  task create_parties: :environment do
    puts "Creating Party records from temp_people data..."
    
    # Get all unique party strings
    party_strings = TempPerson.where.not(registered_political_party: [nil, ''])
                              .distinct
                              .pluck(:registered_political_party)
    
    # Split and collect individual parties
    individual_parties = Set.new
    party_strings.each do |party_string|
      parts = party_string.split(/,\s*/)
      parts.each do |part|
        cleaned = part.strip
        individual_parties.add(cleaned) if cleaned.present?
      end
    end
    
    puts "Processing #{individual_parties.length} unique parties..."
    
    created = 0
    existing = 0
    
    individual_parties.to_a.sort.each do |party_name|
      abbreviation = generate_abbreviation(party_name)
      ideology = infer_ideology(party_name)
      
      party = Party.find_by(name: party_name)
      if party
        existing += 1
        puts "  EXISTS: #{party_name} (#{party.abbreviation})"
      else
        party = Party.create!(
          name: party_name,
          abbreviation: abbreviation,
          ideology: ideology
        )
        created += 1
        puts "  CREATED: #{party_name} (#{abbreviation}) - #{ideology}"
      end
    end
    
    puts "\n" + "=" * 60
    puts "PARTY CREATION COMPLETE"
    puts "=" * 60
    puts "  Created: #{created}"
    puts "  Already existed: #{existing}"
    puts "  Total parties: #{Party.count}"
    puts "=" * 60
  end
end

def generate_abbreviation(party_name)
  # Known abbreviations
  known = {
    'Democratic Party' => 'DEM',
    'Republican Party' => 'REP',
    'Libertarian Party' => 'LIB',
    'Green Party' => 'GRN',
    'Constitution Party' => 'CST',
    'Independent' => 'IND',
    'Unaffiliated' => 'UNA',
    'Nonpartisan' => 'NPT',
    'Working Families Party' => 'WFP',
    'Conservative Party' => 'CNS',
    'Independence Party' => 'IDP',
    'Reform Party' => 'REF',
    'Peace and Freedom Party' => 'PFP',
    'American Independent Party' => 'AIP',
    'Progressive Party' => 'PRG',
    'Forward Party' => 'FWD',
    'Unity Party' => 'UNI',
    'Mountain Party' => 'MTN',
    'Legal Marijuana Now' => 'LMN',
    'No Labels' => 'NL',
    # Puerto Rico parties
    'Partido Nuevo Progresista' => 'PNP',
    'Partido Popular Democrático' => 'PPD',
    'Partido Independentista Puertorriqueño' => 'PIP',
    'Proyecto Dignidad' => 'PD',
    'Movimiento Victoria Ciudadana' => 'MVC',
    # State-specific
    'Democratic-Farmer-Labor Party' => 'DFL',
    'Democratic-NPL Party' => 'DNP',
    'Alaskan Independence Party' => 'AKI',
    'United Utah Party' => 'UUP',
    'Vermont Progressive Party' => 'VPP',
    'Working Class Party' => 'WCP',
    'U.S. Taxpayers Party' => 'UST',
    'Pacific Green Party' => 'PGP',
    'Oregon Progressive Party' => 'OPP',
    'Independent Party of Oregon' => 'IPO',
    'Alliance Party' => 'ALL',
    'Common Sense Party' => 'CSP',
    'Better Party' => 'BET',
    'Epic Party' => 'EPC',
    'We The People' => 'WTP',
    'We The People Party' => 'WPP',
    'We the People Party' => 'WPY',
    'Workers Party' => 'WRK',
    'Natural Law Party' => 'NLP',
    'Liberty Union Party' => 'LUP',
    'Green Mountain Peace and Justice Party' => 'GMP',
    'Approval Voting Party' => 'AVP',
    'Independent American Party' => 'IAM',
    'Independent American Party of Nevada' => 'IAN',
    'United Citizens Party' => 'UCP',
    'United Kansas Party' => 'UKP',
    'Colorado Center Party' => 'CCP',
    'Colorado Forward Party' => 'CFP',
    'DC Statehood Green Party' => 'DSG',
    'American Constitution Party' => 'ACP',
    'Independent Citizens Movement of the Virgin Islands' => 'ICM',
    'Independence-Alliance Party' => 'IAP',
    'Independence-Alliance' => 'IAL',
    'Independent Party' => 'IPT',
    'Independent Party of Delaware' => 'IPD',
    'Wisconsin Green Party' => 'WGP',
    'Unknown' => 'UNK',
    'Gettr' => 'GET',
    'Rumble' => 'RMB',
    'Telegram' => 'TEL',
    'Threads' => 'THR',
    'TruthSocial' => 'TRS',
  }
  
  return known[party_name] if known[party_name]
  
  # Generate from name - take first letter of each word, max 3-4 chars
  words = party_name.split(/\s+/).reject { |w| %w[of the and].include?(w.downcase) }
  if words.length >= 3
    words.first(3).map { |w| w[0] }.join.upcase
  elsif words.length == 2
    (words[0][0..1] + words[1][0]).upcase
  else
    words[0][0..2].upcase
  end
end

def infer_ideology(party_name)
  case party_name
  when /Democratic|DFL|NPL|Working Families|Progressive|Green|Peace and Freedom|Labor/i
    'Left/Center-left'
  when /Republican|Conservative|Constitution|Taxpayers|American Independent/i
    'Right/Center-right'
  when /Libertarian/i
    'Libertarian'
  when /Independent|Unaffiliated|Nonpartisan|Unity|Forward|No Labels|Center/i
    'Centrist/Independent'
  when /Partido Nuevo Progresista/i
    'Center-right (PR statehood)'
  when /Partido Popular Democrático|PPD/i
    'Center-left (PR commonwealth)'
  when /Partido Independentista|PIP/i
    'Left (PR independence)'
  when /Proyecto Dignidad/i
    'Conservative (PR)'
  when /Movimiento Victoria Ciudadana/i
    'Progressive (PR)'
  else
    'Other/Unknown'
  end
end
