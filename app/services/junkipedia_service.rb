require 'httparty'

class JunkipediaService
  include HTTParty
  base_uri "https://www.junkipedia.org/api/v2"

  # Candidata platform names → Junkipedia platform names
  PLATFORM_MAP = {
    'Facebook'    => 'Facebook',
    'Twitter'     => 'Twitter',
    'Instagram'   => 'Instagram',
    'YouTube'     => 'YouTube',
    'TikTok'      => 'TikTok',
    'BlueSky'     => 'Bluesky',
    'TruthSocial' => 'TruthSocial',
    'Gettr'       => 'GETTR',
    'Rumble'      => 'Rumble',
    'Telegram'    => 'Telegram',
    'Threads'     => 'Threads'
  }.freeze

  SUPPORTED_PLATFORMS = PLATFORM_MAP.keys.freeze

  def initialize(api_token = nil)
    @api_token = api_token || ENV.fetch('JUNKIPEDIA_API_TOKEN')
    @headers = {
      "Authorization" => "Bearer #{@api_token}",
      "Content-Type" => "application/json"
    }
  end

  # Create a new multi-platform list
  def create_list(name:, description: nil)
    body = {
      name: name,
      multi_platform: true,
      list_type: 'LIST',
      enabled: true,
      public: false,
      shared_with_my_organization: true
    }
    body[:description] = description if description

    response = self.class.post('/lists', headers: @headers, body: body.to_json)
    handle_response(response, "create list '#{name}'")
  end

  # Get details of a list
  def get_list(list_id)
    response = self.class.get("/lists/#{list_id}", headers: @headers)
    handle_response(response, "get list #{list_id}")
  end

  # Get all lists
  def get_lists
    response = self.class.get('/lists', headers: @headers)
    handle_response(response, "get lists")
  end

  # Get channels already in a list
  def get_channels(list_id)
    response = self.class.get("/lists/#{list_id}/get_channels", headers: @headers)
    handle_response(response, "get channels for list #{list_id}")
  end

  # Enqueue a channel for ingestion by URL. Junkipedia processes asynchronously;
  # the channel_id may not be available in the response and must be resolved later
  # via search_channel.
  def enqueue_channel(url:, retries: 3)
    body = { url: url }
    attempts = 0
    begin
      attempts += 1
      response = self.class.post(
        "/channels",
        headers: @headers,
        body: body.to_json,
        timeout: 30
      )
      handle_response(response, "enqueue channel '#{url}'")
    rescue Net::OpenTimeout, Net::ReadTimeout, Errno::ECONNRESET, Errno::ECONNREFUSED => e
      if attempts <= retries
        sleep(2 ** attempts)
        retry
      end
      raise JunkipediaError, "Network error enqueuing '#{url}' after #{retries} retries: #{e.message}"
    end
  end

  # Search channels by URL, handle, or platform/UID. Returns matching channels;
  # used to resolve a channel_id after enqueue_channel has had time to process.
  def search_channel(url: nil, handle: nil, platform: nil, retries: 3)
    query = {}
    query[:url] = url if url.present?
    query[:handle] = handle if handle.present?
    query[:platform] = platform if platform.present?

    attempts = 0
    begin
      attempts += 1
      response = self.class.get(
        "/channels/search",
        headers: @headers,
        query: query,
        timeout: 30
      )
      handle_response(response, "search channels (#{query.inspect})")
    rescue Net::OpenTimeout, Net::ReadTimeout, Errno::ECONNRESET, Errno::ECONNREFUSED => e
      if attempts <= retries
        sleep(2 ** attempts)
        retry
      end
      raise JunkipediaError, "Network error searching channels (#{query.inspect}) after #{retries} retries: #{e.message}"
    end
  end

  # Bulk-add channels (by id) to an existing list.
  def add_channels_to_list(list_id:, channel_ids:, retries: 3)
    body = { channel_ids: Array(channel_ids) }
    attempts = 0
    begin
      attempts += 1
      response = self.class.post(
        "/lists/#{list_id}/add_channels",
        headers: @headers,
        body: body.to_json,
        timeout: 30
      )
      handle_response(response, "add channels #{body[:channel_ids].inspect} to list #{list_id}")
    rescue Net::OpenTimeout, Net::ReadTimeout, Errno::ECONNRESET, Errno::ECONNREFUSED => e
      if attempts <= retries
        sleep(2 ** attempts)
        retry
      end
      raise JunkipediaError, "Network error adding channels to list #{list_id} after #{retries} retries: #{e.message}"
    end
  end

  # Add a single component (social media account) to a list
  # component_id is the handle, URL, or platform-specific identifier
  # Retries on transient network errors
  def add_component(list_id:, component_id:, retries: 3)
    body = { component_id: component_id }
    attempts = 0
    begin
      attempts += 1
      response = self.class.post(
        "/lists/#{list_id}/add_component",
        headers: @headers,
        body: body.to_json,
        timeout: 30
      )
      handle_response(response, "add component '#{component_id}' to list #{list_id}")
    rescue Net::OpenTimeout, Net::ReadTimeout, Errno::ECONNRESET, Errno::ECONNREFUSED => e
      if attempts <= retries
        sleep(2 ** attempts)
        retry
      end
      raise JunkipediaError, "Network error adding '#{component_id}' to list #{list_id} after #{retries} retries: #{e.message}"
    end
  end

  # Remove a component from a list
  def remove_component(list_id:, component_id:)
    body = { component_id: component_id }
    response = self.class.delete(
      "/lists/#{list_id}/remove_component",
      headers: @headers,
      body: body.to_json
    )
    handle_response(response, "remove component '#{component_id}' from list #{list_id}")
  end

  # Determine the best component_id for a social media account
  def self.component_id_for(account)
    # Prefer URL for most platforms as it's the most reliable identifier
    # For Twitter, the handle alone works well
    case account.platform
    when 'Twitter'
      account.handle.presence || account.url
    else
      account.url.presence || account.handle
    end
  end

  # Check if a platform is supported by Junkipedia
  def self.supported_platform?(platform)
    SUPPORTED_PLATFORMS.include?(platform)
  end

  # Extract a channel id from a single-record response. Junkipedia returns
  # JSON:API ({ "data" => { "id" => ..., "attributes" => {...} } }) in most
  # cases, but we also tolerate flat shapes for robustness.
  def self.extract_channel_id(response)
    return nil unless response.is_a?(Hash)
    if response['data'].is_a?(Hash)
      data = response['data']
      return data['id'].to_s if data['id'].present?
      attrs = data['attributes']
      if attrs.is_a?(Hash)
        return (attrs['channel_id'] || attrs['id']).to_s if (attrs['channel_id'] || attrs['id']).present?
      end
    end
    return response['channel_id'].to_s if response['channel_id'].present?
    return response['id'].to_s if response['id'].present?
    nil
  end

  # Extract the first channel id from a search response (an array of records).
  def self.first_channel_id(response)
    return nil unless response.is_a?(Hash)
    records = response['data'] || response['channels']
    return nil unless records.is_a?(Array) && records.first.is_a?(Hash)
    extract_channel_id('data' => records.first)
  end

  # Map Candidata platform name to Junkipedia platform name
  def self.junkipedia_platform(platform)
    PLATFORM_MAP[platform]
  end

  private

  def handle_response(response, action)
    if response.success?
      response.parsed_response
    else
      error_body = response.parsed_response rescue response.body
      raise JunkipediaError, "Failed to #{action}: HTTP #{response.code} - #{error_body}"
    end
  end

  class JunkipediaError < StandardError; end
end
