module MixpanelHelper
  # Track an event with Mixpanel
  #
  # @param event_name [String] The name of the event
  # @param properties [Hash] Additional properties to track
  # @param user [User] Optional user to track event for (defaults to current_user if available)
  def track_event(event_name, properties = {}, user: nil)
    return unless ENV['MIXPANEL_TOKEN'].present?

    user ||= current_user if respond_to?(:current_user)

    distinct_id = user&.id || 'anonymous'

    # Add user properties if available
    if user
      properties[:user_email] = user.email
      properties[:user_name] = user.name if user.name.present?
      properties[:user_role] = user.role
    end

    # Add request context if available
    if respond_to?(:request) && request
      properties[:ip] = request.remote_ip
      properties[:user_agent] = request.user_agent
    end

    MIXPANEL_TRACKER.track(distinct_id, event_name, properties)
  end

  # Update user properties in Mixpanel
  def update_mixpanel_user(user)
    return unless ENV['MIXPANEL_TOKEN'].present?
    return unless user

    MIXPANEL_TRACKER.people.set(user.id, {
      '$email' => user.email,
      '$name' => user.name || user.email,
      'role' => user.role,
      'created_at' => user.created_at.iso8601,
      'last_sign_in_at' => user.last_sign_in_at&.iso8601
    })
  end

  # Increment a counter for a user
  def increment_mixpanel_counter(user, counter_name, increment_by = 1)
    return unless ENV['MIXPANEL_TOKEN'].present?
    return unless user

    MIXPANEL_TRACKER.people.increment(user.id, { counter_name => increment_by })
  end
end
