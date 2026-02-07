puts '=' * 80
puts 'LINKING EXISTING OFFICES TO BODY RECORDS'
puts '=' * 80

stats = {
  offices_with_body_name: 0,
  bodies_found: 0,
  bodies_created: 0,
  offices_linked: 0,
  no_body_name: 0
}

Office.where.not(body_name: [nil, '']).find_each do |office|
  stats[:offices_with_body_name] += 1

  body = Body.find_by(name: office.body_name)
  unless body
    # Create the body if it doesn't exist
    body = Body.create!(
      name: office.body_name,
      country: office.state,
      classification: 'legislature'
    )
    stats[:bodies_created] += 1
  else
    stats[:bodies_found] += 1
  end

  if office.body_id != body.id
    office.update_column(:body_id, body.id)
    stats[:offices_linked] += 1
  end

  print '.' if stats[:offices_with_body_name] % 1000 == 0
end

stats[:no_body_name] = Office.where(body_name: [nil, '']).count

puts "\n\n" + '=' * 80
puts 'LINKING COMPLETE'
puts '=' * 80
puts "  Offices with body_name: #{stats[:offices_with_body_name]}"
puts "  Bodies found: #{stats[:bodies_found]}"
puts "  Bodies created: #{stats[:bodies_created]}"
puts "  Offices linked: #{stats[:offices_linked]}"
puts "  Offices without body_name: #{stats[:no_body_name]}"
puts ''
puts 'VERIFICATION:'
puts "  Offices with body_id: #{Office.where.not(body_id: nil).count} / #{Office.count}"
puts '=' * 80
