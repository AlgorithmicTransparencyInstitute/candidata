require 'httparty'

class AirtableService
  include HTTParty
  
  base_uri "https://api.airtable.com/v0"
  
  def initialize(api_key, base_id)
    @api_key = api_key
    @base_id = base_id
    @headers = {
      "Authorization" => "Bearer #{@api_key}",
      "Content-Type" => "application/json"
    }
  end
  
  def fetch_table(table_name)
    response = self.class.get(
      "/#{@base_id}/#{table_name}",
      headers: @headers
    )
    
    if response.success?
      response.parsed_response
    else
      raise "Airtable API Error: #{response.code} - #{response.message}"
    end
  end
  
  def fetch_records(table_name, options = {})
    params = {}
    params[:view] = options[:view] if options[:view]
    params[:filterByFormula] = options[:filter] if options[:filter]
    params[:sort] = build_sort_params(options[:sort]) if options[:sort]
    params[:maxRecords] = options[:limit] if options[:limit]
    
    response = self.class.get(
      "/#{@base_id}/#{table_name}",
      headers: @headers,
      query: params
    )
    
    if response.success?
      response.parsed_response
    else
      raise "Airtable API Error: #{response.code} - #{response.message}"
    end
  end
  
  def create_record(table_name, fields)
    response = self.class.post(
      "/#{@base_id}/#{table_name}",
      headers: @headers,
      body: {
        records: [{ fields: fields }]
      }.to_json
    )
    
    if response.success?
      response.parsed_response
    else
      raise "Airtable API Error: #{response.code} - #{response.message}"
    end
  end
  
  def update_record(table_name, record_id, fields)
    response = self.class.patch(
      "/#{@base_id}/#{table_name}/#{record_id}",
      headers: @headers,
      body: {
        fields: fields
      }.to_json
    )
    
    if response.success?
      response.parsed_response
    else
      raise "Airtable API Error: #{response.code} - #{response.message}"
    end
  end
  
  def delete_record(table_name, record_id)
    response = self.class.delete(
      "/#{@base_id}/#{table_name}/#{record_id}",
      headers: @headers
    )
    
    if response.success?
      response.parsed_response
    else
      raise "Airtable API Error: #{response.code} - #{response.message}"
    end
  end
  
  def all_records(table_name, options = {})
    all_records = []
    offset = nil
    batch_size = options[:batch_size] || 50
    
    loop do
      params = options.dup
      params[:offset] = offset if offset
      params[:limit] = batch_size
      
      response = fetch_records(table_name, params)
      
      records = response['records'] || []
      all_records.concat(records)
      
      puts "Fetched #{records.length} records (total: #{all_records.length})" if Rails.env.development?
      
      offset = response['offset']
      break unless offset
    end
    
    all_records
  end
  
  private
  
  def build_sort_params(sort_options)
    if sort_options.is_a?(Array)
      sort_options.map { |sort| { field: sort[:field], direction: sort[:direction] || 'asc' } }
    else
      [{ field: sort_options[:field], direction: sort_options[:direction] || 'asc' }]
    end
  end
  
  class << self
    def instance
      @instance ||= new(
        ENV['AIRTABLE_API_KEY'],
        ENV['AIRTABLE_BASE_ID']
      )
    end
  end
end
