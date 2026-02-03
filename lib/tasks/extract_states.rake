namespace :extract do
  desc "Create all US states, territories, and DC"
  task states: :environment do
    puts "Creating states and territories..."

    states_data = [
      # States
      { name: 'Alabama', abbreviation: 'AL', fips_code: '01', state_type: 'state' },
      { name: 'Alaska', abbreviation: 'AK', fips_code: '02', state_type: 'state' },
      { name: 'Arizona', abbreviation: 'AZ', fips_code: '04', state_type: 'state' },
      { name: 'Arkansas', abbreviation: 'AR', fips_code: '05', state_type: 'state' },
      { name: 'California', abbreviation: 'CA', fips_code: '06', state_type: 'state' },
      { name: 'Colorado', abbreviation: 'CO', fips_code: '08', state_type: 'state' },
      { name: 'Connecticut', abbreviation: 'CT', fips_code: '09', state_type: 'state' },
      { name: 'Delaware', abbreviation: 'DE', fips_code: '10', state_type: 'state' },
      { name: 'Florida', abbreviation: 'FL', fips_code: '12', state_type: 'state' },
      { name: 'Georgia', abbreviation: 'GA', fips_code: '13', state_type: 'state' },
      { name: 'Hawaii', abbreviation: 'HI', fips_code: '15', state_type: 'state' },
      { name: 'Idaho', abbreviation: 'ID', fips_code: '16', state_type: 'state' },
      { name: 'Illinois', abbreviation: 'IL', fips_code: '17', state_type: 'state' },
      { name: 'Indiana', abbreviation: 'IN', fips_code: '18', state_type: 'state' },
      { name: 'Iowa', abbreviation: 'IA', fips_code: '19', state_type: 'state' },
      { name: 'Kansas', abbreviation: 'KS', fips_code: '20', state_type: 'state' },
      { name: 'Kentucky', abbreviation: 'KY', fips_code: '21', state_type: 'state' },
      { name: 'Louisiana', abbreviation: 'LA', fips_code: '22', state_type: 'state' },
      { name: 'Maine', abbreviation: 'ME', fips_code: '23', state_type: 'state' },
      { name: 'Maryland', abbreviation: 'MD', fips_code: '24', state_type: 'state' },
      { name: 'Massachusetts', abbreviation: 'MA', fips_code: '25', state_type: 'state' },
      { name: 'Michigan', abbreviation: 'MI', fips_code: '26', state_type: 'state' },
      { name: 'Minnesota', abbreviation: 'MN', fips_code: '27', state_type: 'state' },
      { name: 'Mississippi', abbreviation: 'MS', fips_code: '28', state_type: 'state' },
      { name: 'Missouri', abbreviation: 'MO', fips_code: '29', state_type: 'state' },
      { name: 'Montana', abbreviation: 'MT', fips_code: '30', state_type: 'state' },
      { name: 'Nebraska', abbreviation: 'NE', fips_code: '31', state_type: 'state' },
      { name: 'Nevada', abbreviation: 'NV', fips_code: '32', state_type: 'state' },
      { name: 'New Hampshire', abbreviation: 'NH', fips_code: '33', state_type: 'state' },
      { name: 'New Jersey', abbreviation: 'NJ', fips_code: '34', state_type: 'state' },
      { name: 'New Mexico', abbreviation: 'NM', fips_code: '35', state_type: 'state' },
      { name: 'New York', abbreviation: 'NY', fips_code: '36', state_type: 'state' },
      { name: 'North Carolina', abbreviation: 'NC', fips_code: '37', state_type: 'state' },
      { name: 'North Dakota', abbreviation: 'ND', fips_code: '38', state_type: 'state' },
      { name: 'Ohio', abbreviation: 'OH', fips_code: '39', state_type: 'state' },
      { name: 'Oklahoma', abbreviation: 'OK', fips_code: '40', state_type: 'state' },
      { name: 'Oregon', abbreviation: 'OR', fips_code: '41', state_type: 'state' },
      { name: 'Pennsylvania', abbreviation: 'PA', fips_code: '42', state_type: 'state' },
      { name: 'Rhode Island', abbreviation: 'RI', fips_code: '44', state_type: 'state' },
      { name: 'South Carolina', abbreviation: 'SC', fips_code: '45', state_type: 'state' },
      { name: 'South Dakota', abbreviation: 'SD', fips_code: '46', state_type: 'state' },
      { name: 'Tennessee', abbreviation: 'TN', fips_code: '47', state_type: 'state' },
      { name: 'Texas', abbreviation: 'TX', fips_code: '48', state_type: 'state' },
      { name: 'Utah', abbreviation: 'UT', fips_code: '49', state_type: 'state' },
      { name: 'Vermont', abbreviation: 'VT', fips_code: '50', state_type: 'state' },
      { name: 'Virginia', abbreviation: 'VA', fips_code: '51', state_type: 'state' },
      { name: 'Washington', abbreviation: 'WA', fips_code: '53', state_type: 'state' },
      { name: 'West Virginia', abbreviation: 'WV', fips_code: '54', state_type: 'state' },
      { name: 'Wisconsin', abbreviation: 'WI', fips_code: '55', state_type: 'state' },
      { name: 'Wyoming', abbreviation: 'WY', fips_code: '56', state_type: 'state' },
      # Federal District
      { name: 'District of Columbia', abbreviation: 'DC', fips_code: '11', state_type: 'federal_district' },
      # Territories
      { name: 'American Samoa', abbreviation: 'AS', fips_code: '60', state_type: 'territory' },
      { name: 'Guam', abbreviation: 'GU', fips_code: '66', state_type: 'territory' },
      { name: 'Northern Mariana Islands', abbreviation: 'MP', fips_code: '69', state_type: 'territory' },
      { name: 'Puerto Rico', abbreviation: 'PR', fips_code: '72', state_type: 'territory' },
      { name: 'U.S. Virgin Islands', abbreviation: 'VI', fips_code: '78', state_type: 'territory' },
    ]

    created = 0
    existing = 0

    states_data.each do |data|
      state = State.find_by(abbreviation: data[:abbreviation])
      if state
        existing += 1
        puts "  EXISTS: #{data[:name]} (#{data[:abbreviation]})"
      else
        State.create!(data)
        created += 1
        puts "  CREATED: #{data[:name]} (#{data[:abbreviation]}) - #{data[:state_type]}"
      end
    end

    puts "\n" + "=" * 60
    puts "STATE CREATION COMPLETE"
    puts "=" * 60
    puts "  Created: #{created}"
    puts "  Already existed: #{existing}"
    puts "  Total: #{State.count}"
    puts "    States: #{State.states.count}"
    puts "    Territories: #{State.territories.count}"
    puts "    Federal District: #{State.federal_district.count}"
    puts "=" * 60
  end
end
