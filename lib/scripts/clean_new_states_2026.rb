#!/usr/bin/env ruby
require 'csv'
require 'fileutils'

class NewStatesCleaner
  INPUT_DIR = Rails.root.join('data', '2026_states', 'new states csv')
  OUTPUT_DIR = Rails.root.join('data', '2026_states', 'cleaned')

  # Map filenames to state codes
  STATE_MAP = {
    'Alabama'      => 'AL',
    'Indiana'      => 'IN',
    'Louisiana'    => 'LA',
    'Maryland'     => 'MD',
    'NewMexico'    => 'NM',
    'Ohio'         => 'OH',
    'WestVirginia' => 'WV'
  }

  OUTPUT_HEADERS = %w[
    state candidate_name is_incumbent withdrew party office district
    race gender website twitter facebook instagram youtube tiktok bluesky notes
  ]

  def initialize
    @stats = Hash.new { |h, k| h[k] = Hash.new(0) }
  end

  def run
    puts "Cleaning 7 new state CSVs..."
    puts "Input:  #{INPUT_DIR}"
    puts "Output: #{OUTPUT_DIR}"
    FileUtils.mkdir_p(OUTPUT_DIR)

    STATE_MAP.each do |state_name, state_code|
      process_state(state_name, state_code)
    end

    print_summary
  end

  private

  def process_state(state_name, state_code)
    pattern = INPUT_DIR.join("#{state_name}*.csv")
    files = Dir.glob(pattern)

    if files.empty?
      puts "  WARNING: No file found for #{state_name}"
      return
    end

    file = files.reject { |f| f.include?('(1)') }.first || files.first
    puts "\n  Processing #{File.basename(file)} -> #{state_code}"

    rows = []
    csv = CSV.read(file, headers: true, encoding: 'UTF-8')

    csv.each do |row|
      next if row['CandidateName'].nil? || row['CandidateName'].strip.empty?

      cleaned = clean_row(row, state_code)
      rows << cleaned
      @stats[state_code][:total] += 1
      @stats[state_code][:incumbents] += 1 if cleaned[:is_incumbent] == 'true'
      @stats[state_code][:withdrew] += 1 if cleaned[:withdrew] == 'true'
    end

    output_path = OUTPUT_DIR.join("#{state_code}_candidates_cleaned.csv")
    CSV.open(output_path, 'w') do |out|
      out << OUTPUT_HEADERS
      rows.each { |r| out << OUTPUT_HEADERS.map { |h| r[h.to_sym] } }
    end

    puts "    Wrote #{rows.size} candidates to #{File.basename(output_path)}"
  end

  def clean_row(row, state_code)
    {
      state:          state_code,
      candidate_name: clean_name(row['CandidateName']),
      is_incumbent:   parse_incumbent(row),
      withdrew:       parse_withdrew(row),
      party:          standardize_party(row['Party']),
      office:         standardize_office(row['Office']),
      district:       clean_district(row['District']),
      race:           standardize_race(row['Race']),
      gender:         standardize_gender(row['Gender']),
      website:        clean_url(row['Website']),
      twitter:        clean_url(row['Twitter']),
      facebook:       clean_url(row['Facebook']),
      instagram:      clean_url(row['Instagram']),
      youtube:        clean_url(row['YouTube']),
      tiktok:         clean_url(row['TikTok']),
      bluesky:        clean_url(row['BlueSky'] || row['BlueSkye']),
      notes:          clean_notes(row['Notes'])
    }
  end

  def clean_name(name)
    return nil if name.nil?
    name = name.gsub(/\s*\(Incumbent\)\s*/, '')
    name = name.gsub(/^["']|["']$/, '')
    name.strip
  end

  # The new files use "X" in the Incumbent column (or it's at the end for Ohio)
  def parse_incumbent(row)
    val = row['Incumbent']
    return 'false' if val.nil?
    val.strip.upcase == 'X' ? 'true' : 'false'
  end

  def parse_withdrew(row)
    val = row['Withdrew']
    return 'false' if val.nil?
    val.strip.upcase == 'X' ? 'true' : 'false'
  end

  def standardize_party(party)
    return nil if party.nil? || party.strip.empty? || party.strip == '99'

    case party.strip.downcase
    when 'd', 'democrat', 'democratic'  then 'Democratic'
    when 'r', 'republican'             then 'Republican'
    when 'l', 'libertarian'            then 'Libertarian'
    when 'i', 'independent', 'independent/write in' then 'Independent'
    when 'working class'               then 'Working Class'
    else party.strip
    end
  end

  def standardize_office(office)
    return nil if office.nil? || office.strip.empty?

    case office.strip.downcase
    when 's', 'senate', 'u.s. senate'  then 'U.S. Senate'
    when 'h', 'house', 'u.s. house'    then 'U.S. House'
    else office.strip
    end
  end

  def clean_district(district)
    return nil if district.nil? || district.strip.empty? || district.strip == '99'
    d = district.strip
    return nil if d.match?(/^[A-Za-z]+$/) # state name in wrong column
    d
  end

  def standardize_race(race)
    return nil if race.nil? || race.strip.empty?
    r = race.strip
    return nil if r == '99' || r.downcase == 'not sure'

    case r.downcase
    when 'white, non-hispanic', 'white'              then 'White'
    when 'black'                                      then 'Black'
    when 'hispanic'                                   then 'Hispanic'
    when 'asian', 'asian american'                    then 'Asian'
    when 'middle eastern'                             then 'Middle Eastern'
    when 'other', 'mixed'                             then 'Other'
    else r
    end
  end

  def standardize_gender(gender)
    return nil if gender.nil? || gender.strip.empty? || gender.strip == '99'

    case gender.strip.downcase
    when 'm', 'male'    then 'Male'
    when 'f', 'female'  then 'Female'
    when 'i'            then 'Non-binary'
    when 'other'        then 'Other'
    else nil
    end
  end

  def clean_url(url)
    return nil if url.nil? || url.strip.empty? || url.strip == '99'
    u = url.strip
    return nil if u.downcase.include?('see notes')
    u
  end

  def clean_notes(notes)
    return nil if notes.nil? || notes.strip.empty?
    n = notes.strip
    return nil if n.downcase == 'n/a' || n == 'Incumbent'
    n
  end

  def print_summary
    puts "\n" + "=" * 60
    puts "CLEANING SUMMARY"
    puts "=" * 60

    total = 0
    STATE_MAP.each do |_, code|
      s = @stats[code]
      next if s[:total] == 0
      puts "  #{code}: #{s[:total]} candidates (#{s[:incumbents]} incumbents, #{s[:withdrew]} withdrew)"
      total += s[:total]
    end

    puts "-" * 60
    puts "  TOTAL: #{total} candidates"
    puts "=" * 60
    puts "\nCleaned files written to: #{OUTPUT_DIR}"
  end
end

cleaner = NewStatesCleaner.new
cleaner.run
