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

  # Add a single component (social media account) to a list
  # component_id is the handle, URL, or platform-specific identifier
  def add_component(list_id:, component_id:)
    body = { component_id: component_id }
    response = self.class.post(
      "/lists/#{list_id}/add_component",
      headers: @headers,
      body: body.to_json
    )
    handle_response(response, "add component '#{component_id}' to list #{list_id}")
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
