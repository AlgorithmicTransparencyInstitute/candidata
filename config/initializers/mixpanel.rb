# frozen_string_literal: true

if ENV['MIXPANEL_TOKEN'].present?
  MIXPANEL_TRACKER = Mixpanel::Tracker.new(ENV['MIXPANEL_TOKEN'])
else
  # Stub tracker for development/test
  MIXPANEL_TRACKER = Struct.new(:token) do
    def track(*args); end
    def people; self; end
    def set(*args); end
    def increment(*args); end
  end.new(nil)
end
