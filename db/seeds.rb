# This file should ensure the existence of records required to run the application in every environment (production,
# development, test). The code here should be idempotent so that it can be executed at any point in every environment.
# The data can then be loaded with the bin/rails db:seed command (or created alongside the database with db:setup).

puts "Seeding database..."

# =============================================================================
# POLITICAL PARTIES
# =============================================================================
puts "\n=== Seeding Political Parties ==="

parties = [
  { name: "Democratic Party", abbreviation: "DEM", ideology: "Center-left" },
  { name: "Republican Party", abbreviation: "GOP", ideology: "Center-right" },
  { name: "Libertarian Party", abbreviation: "LIB", ideology: "Libertarian" },
  { name: "Green Party", abbreviation: "GRN", ideology: "Left-wing" },
  { name: "Constitution Party", abbreviation: "CST", ideology: "Right-wing" },
  { name: "Independent", abbreviation: "IND", ideology: "Various" },
  { name: "Unaffiliated", abbreviation: "UNA", ideology: "Various" },
  { name: "Peace and Freedom Party", abbreviation: "PFP", ideology: "Left-wing" },
  { name: "U.S. Taxpayers Party", abbreviation: "UST", ideology: "Right-wing" },
  { name: "Working Families Party", abbreviation: "WFP", ideology: "Progressive" },
  { name: "Reform Party", abbreviation: "REF", ideology: "Centrist" },
  { name: "Forward Party", abbreviation: "FWD", ideology: "Centrist" },
  { name: "No Labels", abbreviation: "NLB", ideology: "Centrist" }
]

parties.each do |party_data|
  party = Party.find_or_create_by!(name: party_data[:name]) do |p|
    p.abbreviation = party_data[:abbreviation]
    p.ideology = party_data[:ideology]
  end
  puts "  ✓ #{party.name}"
end

# =============================================================================
# US STATES AND TERRITORIES
# =============================================================================
puts "\n=== Seeding States Reference Data ==="

# State data with full names and abbreviations
STATES = {
  "AL" => "Alabama", "AK" => "Alaska", "AZ" => "Arizona", "AR" => "Arkansas",
  "CA" => "California", "CO" => "Colorado", "CT" => "Connecticut", "DE" => "Delaware",
  "FL" => "Florida", "GA" => "Georgia", "HI" => "Hawaii", "ID" => "Idaho",
  "IL" => "Illinois", "IN" => "Indiana", "IA" => "Iowa", "KS" => "Kansas",
  "KY" => "Kentucky", "LA" => "Louisiana", "ME" => "Maine", "MD" => "Maryland",
  "MA" => "Massachusetts", "MI" => "Michigan", "MN" => "Minnesota", "MS" => "Mississippi",
  "MO" => "Missouri", "MT" => "Montana", "NE" => "Nebraska", "NV" => "Nevada",
  "NH" => "New Hampshire", "NJ" => "New Jersey", "NM" => "New Mexico", "NY" => "New York",
  "NC" => "North Carolina", "ND" => "North Dakota", "OH" => "Ohio", "OK" => "Oklahoma",
  "OR" => "Oregon", "PA" => "Pennsylvania", "RI" => "Rhode Island", "SC" => "South Carolina",
  "SD" => "South Dakota", "TN" => "Tennessee", "TX" => "Texas", "UT" => "Utah",
  "VT" => "Vermont", "VA" => "Virginia", "WA" => "Washington", "WV" => "West Virginia",
  "WI" => "Wisconsin", "WY" => "Wyoming", "DC" => "District of Columbia"
}.freeze

TERRITORIES = {
  "PR" => "Puerto Rico", "GU" => "Guam", "VI" => "U.S. Virgin Islands",
  "AS" => "American Samoa", "MP" => "Northern Mariana Islands"
}.freeze

# Congressional districts per state (based on 2020 census)
CONGRESSIONAL_DISTRICTS = {
  "AL" => 7, "AK" => 1, "AZ" => 9, "AR" => 4, "CA" => 52, "CO" => 8, "CT" => 5,
  "DE" => 1, "FL" => 28, "GA" => 14, "HI" => 2, "ID" => 2, "IL" => 17, "IN" => 9,
  "IA" => 4, "KS" => 4, "KY" => 6, "LA" => 6, "ME" => 2, "MD" => 8, "MA" => 9,
  "MI" => 13, "MN" => 8, "MS" => 4, "MO" => 8, "MT" => 2, "NE" => 3, "NV" => 4,
  "NH" => 2, "NJ" => 12, "NM" => 3, "NY" => 26, "NC" => 14, "ND" => 1, "OH" => 15,
  "OK" => 5, "OR" => 6, "PA" => 17, "RI" => 2, "SC" => 7, "SD" => 1, "TN" => 9,
  "TX" => 38, "UT" => 4, "VT" => 1, "VA" => 11, "WA" => 10, "WV" => 2, "WI" => 8,
  "WY" => 1
}.freeze

puts "  States: #{STATES.keys.length}"
puts "  Territories: #{TERRITORIES.keys.length}"

# =============================================================================
# CONGRESSIONAL DISTRICTS
# =============================================================================
puts "\n=== Seeding Congressional Districts ==="

district_count = 0
CONGRESSIONAL_DISTRICTS.each do |state, num_districts|
  (1..num_districts).each do |district_num|
    District.find_or_create_by!(
      state: state,
      district_number: district_num,
      level: "federal"
    )
    district_count += 1
  end
end

# At-large districts for single-district states (district 0 or 1)
puts "  ✓ Created #{district_count} congressional districts"

# =============================================================================
# FEDERAL OFFICES
# =============================================================================
puts "\n=== Seeding Federal Offices ==="

# Executive branch
Office.find_or_create_by!(
  title: "President of the United States",
  level: "federal",
  branch: "executive",
  state: nil,
  district: nil
)
puts "  ✓ President of the United States"

Office.find_or_create_by!(
  title: "Vice President of the United States",
  level: "federal",
  branch: "executive",
  state: nil,
  district: nil
)
puts "  ✓ Vice President of the United States"

# U.S. Senate (2 per state)
STATES.keys.each do |state|
  Office.find_or_create_by!(
    title: "U.S. Senator",
    level: "federal",
    branch: "legislative",
    state: state,
    district: nil
  )
end
puts "  ✓ U.S. Senator offices for #{STATES.keys.length} states"

# U.S. House of Representatives
CONGRESSIONAL_DISTRICTS.each do |state, num_districts|
  (1..num_districts).each do |district_num|
    district = District.find_by(state: state, district_number: district_num, level: "federal")
    Office.find_or_create_by!(
      title: "U.S. Representative",
      level: "federal",
      branch: "legislative",
      state: state,
      district: district
    )
  end
end
puts "  ✓ U.S. Representative offices for #{district_count} districts"

# Territorial delegates
TERRITORIES.each do |abbr, name|
  case abbr
  when "PR"
    Office.find_or_create_by!(
      title: "Resident Commissioner",
      level: "federal",
      branch: "legislative",
      state: abbr,
      district: nil
    )
    puts "  ✓ Puerto Rico Resident Commissioner"
  else
    Office.find_or_create_by!(
      title: "Delegate to the U.S. House of Representatives",
      level: "federal",
      branch: "legislative",
      state: abbr,
      district: nil
    )
    puts "  ✓ #{name} Delegate"
  end
end

# =============================================================================
# DEFAULT ADMIN USER
# =============================================================================
puts "\n=== Seeding Default Admin User ==="

admin_email = ENV.fetch('ADMIN_EMAIL', 'admin@candidata.space')
if User.find_by(email: admin_email).nil?
  User.create!(
    email: admin_email,
    password: SecureRandom.hex(16),
    name: "Admin",
    role: "admin"
  )
  puts "  ✓ Created admin user: #{admin_email}"
  puts "    (Password must be set via Google OAuth or password reset)"
else
  puts "  ✓ Admin user already exists: #{admin_email}"
end

# =============================================================================
# SUMMARY
# =============================================================================
puts "\n" + "=" * 60
puts "SEED COMPLETE"
puts "=" * 60
puts "  Parties: #{Party.count}"
puts "  Districts: #{District.count}"
puts "  Offices: #{Office.count}"
puts "  Users: #{User.count}"
puts "=" * 60
