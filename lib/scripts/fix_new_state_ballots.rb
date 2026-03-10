# Link new state ballots to their elections and fix dates
fixes = {
  'AL' => { election_id: 11, date: Date.new(2026, 5, 19) },
  'IN' => { election_id: 6,  date: Date.new(2026, 5, 5) },
  'LA' => { election_id: 10, date: Date.new(2026, 5, 16) },
  'MD' => { election_id: 29, date: Date.new(2026, 6, 23) },
  'NM' => { election_id: 21, date: Date.new(2026, 6, 2) },
  'OH' => { election_id: 7,  date: Date.new(2026, 5, 5) },
  'WV' => { election_id: 9,  date: Date.new(2026, 5, 12) }
}

fixes.each do |state, attrs|
  ballots = Ballot.where(state: state, election_id: nil)
  ballots.each do |b|
    b.update!(election_id: attrs[:election_id], date: attrs[:date])
    b.contests.update_all(date: attrs[:date])
    puts "Fixed #{b.name}: election_id=#{attrs[:election_id]}, date=#{attrs[:date]}"
  end
end

puts
puts "Verification:"
Ballot.where(state: %w[AL IN LA MD NM OH WV]).each do |b|
  puts "  #{b.name} | election_id: #{b.election_id} | date: #{b.date} | contests: #{b.contests.count}"
end
