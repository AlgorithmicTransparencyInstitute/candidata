namespace :examine do
  desc "Examine Airtable table structure"
  task table: :environment do
    table_name = ENV['TABLE'] || 'People'
    
    unless ENV['AIRTABLE_API_KEY'] && ENV['AIRTABLE_BASE_ID']
      puts "Error: AIRTABLE_API_KEY and AIRTABLE_BASE_ID environment variables are required"
      exit 1
    end
    
    puts "Examining table: #{table_name}"
    puts "=" * 50
    
    begin
      airtable = AirtableService.instance
      response = airtable.fetch_records(table_name, limit: 5)
      
      if response['records'] && !response['records'].empty?
        # Show field structure from first record
        first_record = response['records'].first
        fields = first_record['fields']
        
        puts "Fields found in #{table_name}:"
        puts "-" * 30
        fields.each do |field_name, field_value|
          puts "#{field_name}: #{field_value.class.name} (#{field_value.inspect[0..100]}#{'...' if field_value.inspect.length > 100})"
        end
        
        puts "\nSample records:"
        puts "-" * 30
        response['records'].each_with_index do |record, index|
          puts "\nRecord #{index + 1} (ID: #{record['id']}):"
          record['fields'].each do |field_name, field_value|
            puts "  #{field_name}: #{field_value}"
          end
        end
        
        puts "\nTotal records: #{response['records'].length}"
        
      else
        puts "No records found in table: #{table_name}"
      end
      
    rescue => e
      puts "Error examining table: #{e.message}"
      puts e.backtrace.join("\n") if Rails.env.development?
    end
  end
end
