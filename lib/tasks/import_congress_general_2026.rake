namespace :import do
  desc "2026 House + Senate GENERAL contests from primary nominees: dry run + review CSV (APPLY=1 to write)"
  task congress_general_2026: :environment do
    apply = ENV['APPLY'] == '1'
    builder = Importers::GeneralCongress2026Builder.new(apply: apply).call
    seats = builder.seats

    house = seats.count { |s| s.chamber == :house }
    senate = seats.count { |s| s.chamber == :senate }
    puts "Seats: #{house} House + #{senate} Senate"
    puts "Nominees carried: #{seats.sum { |s| s.nominees.size }}"
    puts "Seats needing review: #{builder.review_rows.size} " \
         "(no nominee: #{seats.count { |s| s.nominees.empty? }}, held same-party: #{seats.count { |s| s.held.any? }}, " \
         "unresolved results: #{seats.count { |s| s.unresolved.any? }})"

    path = Rails.root.join('tmp', 'congress_general_2026_review.csv')
    rows = builder.review_rows
    CSV.open(path, 'w') do |csv|
      csv << rows.first&.keys || []
      rows.each { |r| csv << r.values }
    end
    puts "Review CSV: #{path}"

    if apply
      puts "Written: #{builder.created.map { |k, v| "#{k}: #{v}" }.join(', ').presence || 'nothing (already up to date)'}"
    else
      puts 'Dry run — nothing written. Re-run with APPLY=1 to write.'
    end
  end
end
