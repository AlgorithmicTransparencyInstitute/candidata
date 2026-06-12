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

  # Create (or fetch) a channel by URL. POST /channels expects `channel_url`
  # (not `url`) and creates in real time, returning the channel record — the
  # existing one if it's already known. Failures can come back as HTTP 200
  # with an `errors` array in the body (e.g. the org lacks channel-creation
  # permission or hit its daily limit), so a 2xx alone is not success.
  def enqueue_channel(url:, retries: 3)
    body = { channel_url: url }
    attempts = 0
    begin
      attempts += 1
      response = self.class.post(
        "/channels",
        headers: @headers,
        body: body.to_json,
        timeout: 30
      )
      parsed = handle_response(response, "enqueue channel '#{url}'")
      if parsed.is_a?(Hash) && parsed["errors"].present?
        details = Array(parsed["errors"]).filter_map { |err| err["detail"] }.join("; ")
        raise JunkipediaError, "Failed to enqueue channel '#{url}': #{details.presence || parsed['errors'].inspect}"
      end
      parsed
    rescue Net::OpenTimeout, Net::ReadTimeout, Errno::ECONNRESET, Errno::ECONNREFUSED => e
      if attempts <= retries
        sleep(2 ** attempts)
        retry
      end
      raise JunkipediaError, "Network error enqueuing '#{url}' after #{retries} retries: #{e.message}"
    end
  end

  # Search channels by handle (+ optional platform to disambiguate).
  # Junkipedia's /channels/search accepts handle, platform, uid, or channel_ids
  # — NOT url. Returns the parsed JSON:API response; use .first_channel_id to
  # pull the id out.
  def search_channel(handle:, platform: nil, retries: 3)
    raise ArgumentError, "handle is required" if handle.blank?
    query = { handle: handle }
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

  # Derive a Junkipedia-style handle from a SocialMediaAccount. Returns nil
  # when we can't extract one (e.g. Facebook profile.php?id=... — those need
  # uid lookup, not handle search, and are skipped by the bulk match path).
  def self.handle_from(account)
    if account.handle.present? && !looks_like_url?(account.handle)
      return account.handle.to_s.strip.sub(/\A@/, '')
    end
    extract_handle_from_url(account.url, account.platform)
  end

  def self.extract_handle_from_url(url, platform)
    return nil if url.blank?
    s = url.to_s.strip
    case platform
    when 'Twitter'
      s[%r{(?:twitter|x)\.com/(?:#!/)?@?([A-Za-z0-9_]{1,15})}, 1]
    when 'Facebook'
      m = s[%r{facebook\.com/([^/?#]+)}, 1]
      m && m != 'profile.php' ? m : nil
    when 'Instagram'
      s[%r{instagram\.com/([A-Za-z0-9_.]+?)(?:/|\?|$)}, 1]
    when 'YouTube'
      s[%r{youtube\.com/(?:@|channel/|c/|user/)([A-Za-z0-9_\-]+)}, 1]
    when 'TikTok'
      s[%r{tiktok\.com/@?([A-Za-z0-9_.]+)}, 1]
    when 'BlueSky'
      s[%r{bsky\.app/profile/([A-Za-z0-9_.\-]+)}, 1]
    when 'TruthSocial'
      s[%r{truthsocial\.com/@?([A-Za-z0-9_.]+)}, 1]
    when 'Telegram'
      s[%r{t\.me/([A-Za-z0-9_]+)}, 1]
    when 'Threads'
      s[%r{threads\.net/@?([A-Za-z0-9_.]+)}, 1]
    when 'Rumble'
      s[%r{rumble\.com/(?:user/|c/)?([A-Za-z0-9_.\-]+)}, 1]
    when 'Gettr'
      s[%r{gettr\.com/(?:user/)?([A-Za-z0-9_.]+)}, 1]
    end
  end

  def self.looks_like_url?(s)
    s.to_s =~ %r{\Ahttps?://|\Awww\.} ? true : false
  end

  # Map Candidata platform name to Junkipedia platform name
  def self.junkipedia_platform(platform)
    PLATFORM_MAP[platform]
  end

  private

  def handle_response(response, action)
    JunkipediaService.record_rate_limit(response)
    if response.success?
      response.parsed_response
    elsif response.code == 429
      retry_after = (response.headers['retry-after'] || response.headers['Retry-After']).to_s
      reset_at    = response.headers['x-ratelimit-reset']
      raise RateLimitError.new(
        "Rate limited on #{action}: #{response.parsed_response.inspect}",
        retry_after: retry_after,
        reset_at: reset_at
      )
    else
      error_body = response.parsed_response rescue response.body
      raise JunkipediaError, "Failed to #{action}: HTTP #{response.code} - #{error_body}"
    end
  end

  # Cache of the most recent rate-limit headers so callers (esp. the bulk
  # rake tasks) can pace themselves without re-parsing responses.
  @rate_limit_remaining = nil
  @rate_limit_reset     = nil
  class << self
    attr_reader :rate_limit_remaining, :rate_limit_reset

    def record_rate_limit(response)
      remaining = response.headers['x-ratelimit-remaining']
      reset_at  = response.headers['x-ratelimit-reset']
      @rate_limit_remaining = remaining.to_i if remaining
      @rate_limit_reset     = reset_at.to_i  if reset_at
    end
  end

  class JunkipediaError < StandardError; end

  class RateLimitError < JunkipediaError
    attr_reader :retry_after_seconds, :reset_at_unix
    def initialize(message, retry_after: nil, reset_at: nil)
      super(message)
      @retry_after_seconds = retry_after.to_s.to_i if retry_after.present?
      @reset_at_unix       = reset_at.to_s.to_i    if reset_at.present?
    end

    def seconds_until_reset(now = Time.now)
      return retry_after_seconds if retry_after_seconds&.positive?
      return [reset_at_unix - now.to_i, 0].max if reset_at_unix&.positive?
      60
    end
  end
end
