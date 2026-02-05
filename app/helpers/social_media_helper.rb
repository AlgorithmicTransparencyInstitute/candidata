module SocialMediaHelper
  def platform_icon(platform)
    case platform&.downcase
    when 'facebook' then '📘'
    when 'twitter' then '🐦'
    when 'instagram' then '📷'
    when 'youtube' then '▶️'
    when 'tiktok' then '🎵'
    when 'bluesky' then '🦋'
    when 'truthsocial' then '🇺🇸'
    when 'gettr' then '🔴'
    when 'rumble' then '📺'
    when 'telegram' then '✈️'
    when 'threads' then '🧵'
    else '🔗'
    end
  end

  def research_status_badge(status)
    case status
    when 'not_started'
      content_tag(:span, 'Not Started', class: 'px-2 py-1 text-xs rounded-full bg-gray-100 text-gray-800')
    when 'entered'
      content_tag(:span, 'Entered', class: 'px-2 py-1 text-xs rounded-full bg-green-100 text-green-800')
    when 'not_found'
      content_tag(:span, 'Not Found', class: 'px-2 py-1 text-xs rounded-full bg-yellow-100 text-yellow-800')
    when 'verified'
      content_tag(:span, 'Verified', class: 'px-2 py-1 text-xs rounded-full bg-blue-100 text-blue-800')
    when 'rejected'
      content_tag(:span, 'Rejected', class: 'px-2 py-1 text-xs rounded-full bg-red-100 text-red-800')
    else
      content_tag(:span, status&.humanize || 'Unknown', class: 'px-2 py-1 text-xs rounded-full bg-gray-100 text-gray-800')
    end
  end

  def assignment_status_badge(status)
    case status
    when 'pending'
      content_tag(:span, 'Pending', class: 'px-2 py-1 text-xs rounded-full bg-blue-100 text-blue-800')
    when 'in_progress'
      content_tag(:span, 'In Progress', class: 'px-2 py-1 text-xs rounded-full bg-yellow-100 text-yellow-800')
    when 'completed'
      content_tag(:span, 'Completed', class: 'px-2 py-1 text-xs rounded-full bg-green-100 text-green-800')
    else
      content_tag(:span, status&.humanize || 'Unknown', class: 'px-2 py-1 text-xs rounded-full bg-gray-100 text-gray-800')
    end
  end
end
