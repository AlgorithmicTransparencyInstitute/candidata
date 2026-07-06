# Shared handle/URL logic for social media account values, used by
# ElectionEditorSave (grid saves) and ElectionEditorCsvImport (CSV staging).
module SocialHandles
  URL_TEMPLATES = {
    'Facebook'    => 'https://www.facebook.com/%s',
    'Twitter'     => 'https://twitter.com/%s',
    'Instagram'   => 'https://www.instagram.com/%s',
    'YouTube'     => 'https://www.youtube.com/@%s',
    'TikTok'      => 'https://www.tiktok.com/@%s',
    'BlueSky'     => 'https://bsky.app/profile/%s',
    'TruthSocial' => 'https://truthsocial.com/@%s',
    'Gettr'       => 'https://gettr.com/user/%s',
    'Rumble'      => 'https://rumble.com/c/%s',
    'Telegram'    => 'https://t.me/%s',
    'Threads'     => 'https://www.threads.net/@%s'
  }.freeze

  module_function

  # Accepts "@handle", "handle", or a full profile URL; returns {handle:, url:}.
  def normalize(platform, raw)
    value = raw.to_s.strip
    return nil if value.blank?

    if value.match?(%r{\Ahttps?://}i)
      { handle: handle_from_url(platform, value), url: value }
    else
      handle = value.delete_prefix('@').strip
      { handle: handle, url: format(URL_TEMPLATES[platform], handle) }
    end
  end

  # Real profile URLs often carry extra path segments ("/jayfeely/reels/",
  # "/@handle/videos", "/user/markeypress") — prefer an "@segment" anywhere in
  # the path, then platform-specific markers, then the FIRST segment (the last
  # one is usually a subpage, not the handle). facebook.com/profile.php?id=…
  # URLs have no handle at all.
  def handle_from_url(platform, url)
    path = URI.parse(url).path.to_s
    segments = path.split('/').reject(&:blank?)
    return nil if segments.empty?

    segment =
      if (at = segments.find { |s| s.start_with?('@') })
        at
      else
        case platform
        when 'BlueSky' then segments[segments.index('profile').to_i + 1] || segments.last
        when 'Gettr'   then segments[segments.index('user').to_i + 1] || segments.last
        when 'Rumble'  then segments[(segments.index('c') || segments.index('user')).to_i + 1] || segments.last
        when 'YouTube'
          marker = %w[user c channel].filter_map { |m| segments.index(m) }.min
          marker ? segments[marker + 1] : segments.first
        else segments.first
        end
      end
    segment = nil if segment.to_s.casecmp?('profile.php')
    segment.to_s.delete_prefix('@').presence
  rescue URI::InvalidURIError
    nil
  end

  # A stored handle in comparable form. Legacy imports sometimes stored the
  # whole profile URL in the handle column — extract the real handle first.
  def comparable(platform, handle)
    value = handle.to_s.strip
    value = handle_from_url(platform, value).to_s if value.match?(%r{\Ahttps?://}i)
    value.delete_prefix('@').downcase
  end

  # Do two raw handle values refer to the same account? (case-, @- and
  # URL-form-insensitive; blank never matches)
  def same?(platform, a, b)
    ca = comparable(platform, a)
    ca.present? && ca == comparable(platform, b)
  end
end
