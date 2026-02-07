module ApplicationHelper
  # Displays user avatar or fallback to initial circle
  # Options:
  #   size: CSS classes for sizing (default: "w-8 h-8")
  #   text_size: CSS class for text size (default: "text-sm")
  #   additional_classes: Extra CSS classes to add
  def user_avatar(user, size: "w-8 h-8", text_size: "text-sm", additional_classes: "")
    base_classes = "rounded-full object-cover #{size} #{additional_classes}"

    if user.avatar.attached?
      image_tag user.avatar, alt: user.name || user.email, class: base_classes
    else
      # Show circle with initial
      initial = (user.name.presence || user.email).first.upcase
      content_tag :div, class: "#{base_classes.gsub('object-cover', '')} bg-gray-900 flex items-center justify-center" do
        content_tag :span, initial, class: "#{text_size} font-semibold text-white"
      end
    end
  end
end
