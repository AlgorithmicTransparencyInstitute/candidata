namespace :public_api do
  desc "Backfill person_uuid for people missing one (public API stable identifier)"
  task backfill_person_uuids: :environment do
    scope = Person.where(person_uuid: nil)
    total = scope.count
    puts "Backfilling person_uuid for #{total} people..."
    scope.find_each.with_index do |person, i|
      person.update_columns(person_uuid: SecureRandom.uuid)
      puts "  #{i + 1}/#{total}" if ((i + 1) % 500).zero?
    end
    puts "Done. Remaining nil: #{Person.where(person_uuid: nil).count}"
  end
end
