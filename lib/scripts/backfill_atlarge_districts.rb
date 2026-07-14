# One-off data backfill: link each at-large district (federal, district_number 0)
# to the U.S. Representative office in that state that has a BLANK seat and no
# district yet. At-large states have a single, un-numbered House seat; the
# blank-seat filter disambiguates ND/SD, which also carry a mis-encoded
# "District 1" duplicate office. Idempotent — only touches offices whose
# district_id is currently nil, so it is safe to re-run.
#
#   bin/rails runner lib/scripts/backfill_atlarge_districts.rb
PaperTrail.request(whodunnit: 'console:atlarge-district-backfill') do
  linked = []
  skipped = []

  District.at_large.order(:state).each do |district|
    candidates = Office.where(state: district.state, level: 'federal', district_id: nil)
                       .where("office_category ILIKE '%Representative%'")
                       .where("seat IS NULL OR seat = ''")

    case candidates.count
    when 1
      office = candidates.first
      office.update!(district_id: district.id)
      linked << "#{district.state}: office##{office.id} (#{office.office_category}) -> district##{district.id} (#{district.full_name})"
    when 0
      existing = Office.where(state: district.state, level: 'federal', district_id: district.id).count
      skipped << "#{district.state}: nothing to link (already linked: #{existing})"
    else
      skipped << "#{district.state}: #{candidates.count} blank-seat unlinked offices — AMBIGUOUS, skipped"
    end
  end

  puts "LINKED #{linked.size}:"
  linked.each { |line| puts "  #{line}" }
  puts "SKIPPED #{skipped.size}:"
  skipped.each { |line| puts "  #{line}" }
  puts "\nAt-large districts with an office: #{District.at_large.joins(:offices).distinct.count} / #{District.at_large.count}"
end
