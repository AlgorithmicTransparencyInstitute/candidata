namespace :import do
  GOVERNORS_GENERAL_2026_CSV = 'data/2026_general/governors/governors_general_2026_v3.csv'.freeze

  desc "2026 governor GENERAL candidates: dry-run match report (APPLY=1 to write; USER_EMAIL=… attributes entered_by)"
  task governors_general_2026: :environment do
    path = Rails.root.join(ENV.fetch('CSV', GOVERNORS_GENERAL_2026_CSV)).to_s
    apply = ENV['APPLY'] == '1'
    user = ENV['USER_EMAIL'].present? ? User.find_by!(email: ENV['USER_EMAIL']) : nil

    importer = Importers::GeneralGovernor2026Importer.new(path, apply: false, user: user).call
    results = importer.results

    puts "\n#{'Row'.ljust(4)} #{'State'.ljust(5)} #{'Candidate'.ljust(38)} #{'Party'.ljust(22)} #{'Status'.ljust(10)} Decision"
    results.each do |r|
      offices = r.person&.officeholders&.includes(:office)&.map { |oh| oh.office.title }&.uniq&.join('; ')
      who = r.person ? "#{r.person.full_name} ##{r.person.id} [#{offices.presence || 'no office on file'}]" : ''
      puts "#{r.row_num.to_s.ljust(4)} #{r.state.to_s.ljust(5)} #{r.name[0, 38].ljust(38)} #{r.party.to_s[0, 22].ljust(22)} " \
           "#{r.status.ljust(10)} #{r.decision.to_s.upcase.ljust(9)} #{who} #{r.detail}"
    end

    tally = results.map(&:decision).tally
    puts "\n#{results.size} rows, #{results.map(&:state).uniq.size} states — #{tally.map { |k, v| "#{k}: #{v}" }.join(', ')}"

    unless apply
      puts "\nDry run — nothing written. Re-run with APPLY=1 to write."
      next
    end

    applied = Importers::GeneralGovernor2026Importer.new(path, apply: true, user: user).call
    puts "\nWritten: #{applied.created.map { |k, v| "#{k}: #{v}" }.join(', ')}"
  end
end
