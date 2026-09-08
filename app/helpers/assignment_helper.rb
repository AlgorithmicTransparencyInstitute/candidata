# One place that knows how a task type is named, coloured and routed.
#
# This used to be inlined at every call site — eight copies, four of them
# two-way ternaries that quietly labelled secondary_verification tasks as
# "Data Validation" (including in reminder emails). Anything that renders a
# task type should come through here.
#
# Class strings are written out in full rather than interpolated from a colour
# name: Tailwind scans this file for literal class names, so "bg-#{color}-100"
# would compile to nothing.
module AssignmentHelper
  TASK_TYPE_BADGE_CLASSES = {
    'data_collection'        => 'bg-blue-100 text-blue-800',
    'data_validation'        => 'bg-purple-100 text-purple-800',
    'secondary_verification' => 'bg-red-100 text-red-800',
    'demographic_research'   => 'bg-teal-100 text-teal-800'
  }.freeze

  TASK_TYPE_SOLID_CLASSES = {
    'data_collection'        => 'bg-blue-600 hover:bg-blue-700',
    'data_validation'        => 'bg-purple-600 hover:bg-purple-700',
    'secondary_verification' => 'bg-red-600 hover:bg-red-700',
    'demographic_research'   => 'bg-teal-600 hover:bg-teal-700'
  }.freeze

  TASK_TYPE_PILL_CLASSES = {
    'data_collection'        => 'bg-blue-600',
    'data_validation'        => 'bg-purple-600',
    'secondary_verification' => 'bg-red-500',
    'demographic_research'   => 'bg-teal-600'
  }.freeze

  TASK_TYPE_ACCENT_CLASSES = {
    'data_collection'        => 'border-blue-500 bg-blue-50',
    'data_validation'        => 'border-purple-500 bg-purple-50',
    'secondary_verification' => 'border-red-500 bg-red-50',
    'demographic_research'   => 'border-teal-500 bg-teal-50'
  }.freeze

  TASK_TYPE_TEXT_CLASSES = {
    'data_collection'        => 'text-blue-600',
    'data_validation'        => 'text-purple-600',
    'secondary_verification' => 'text-red-600',
    'demographic_research'   => 'text-teal-600'
  }.freeze

  TASK_TYPE_RADIO_CLASSES = {
    'data_collection'        => 'text-blue-600 focus:ring-blue-500',
    'data_validation'        => 'text-purple-600 focus:ring-purple-500',
    'secondary_verification' => 'text-red-600 focus:ring-red-500',
    'demographic_research'   => 'text-teal-600 focus:ring-teal-500'
  }.freeze

  TASK_TYPE_DESCRIPTIONS = {
    'data_collection'        => 'Find and enter social media accounts',
    'data_validation'        => 'Check and verify entered accounts',
    'secondary_verification' => 'Re-review accounts changed during validation',
    'demographic_research'   => 'Research and source candidate demographics'
  }.freeze

  # Options for a task-type <select>. Driven off Assignment::TASK_TYPES so a
  # new type can never be missing from a dropdown — which is how
  # secondary_verification ended up unselectable in three admin screens.
  def task_type_options(include_all: false, describe: false)
    options = Assignment::TASK_TYPES.map do |type|
      label = Assignment::TASK_TYPE_LABELS.fetch(type, type.humanize)
      label = "#{label} — #{TASK_TYPE_DESCRIPTIONS[type]}" if describe && TASK_TYPE_DESCRIPTIONS[type].present?
      [label, type]
    end
    include_all ? [['All', '']] + options : options
  end

  def task_type_key(assignment_or_type)
    assignment_or_type.respond_to?(:task_type) ? assignment_or_type.task_type : assignment_or_type.to_s
  end

  def task_type_label(assignment_or_type)
    key = task_type_key(assignment_or_type)
    Assignment::TASK_TYPE_LABELS.fetch(key, key.humanize)
  end

  def task_type_short_label(assignment_or_type)
    key = task_type_key(assignment_or_type)
    Assignment::TASK_TYPE_SHORT_LABELS.fetch(key, key.humanize)
  end

  def task_type_abbreviation(assignment_or_type)
    Assignment::TASK_TYPE_ABBREVIATIONS.fetch(task_type_key(assignment_or_type), 'UN')
  end

  def task_type_description(assignment_or_type)
    TASK_TYPE_DESCRIPTIONS.fetch(task_type_key(assignment_or_type), '')
  end

  def task_type_badge_class(assignment_or_type)
    TASK_TYPE_BADGE_CLASSES.fetch(task_type_key(assignment_or_type), 'bg-gray-100 text-gray-800')
  end

  def task_type_solid_class(assignment_or_type)
    TASK_TYPE_SOLID_CLASSES.fetch(task_type_key(assignment_or_type), 'bg-gray-600 hover:bg-gray-700')
  end

  def task_type_pill_class(assignment_or_type)
    TASK_TYPE_PILL_CLASSES.fetch(task_type_key(assignment_or_type), 'bg-gray-500')
  end

  def task_type_accent_class(assignment_or_type)
    TASK_TYPE_ACCENT_CLASSES.fetch(task_type_key(assignment_or_type), 'border-gray-400 bg-gray-50')
  end

  def task_type_radio_class(assignment_or_type)
    TASK_TYPE_RADIO_CLASSES.fetch(task_type_key(assignment_or_type), 'text-gray-600 focus:ring-gray-500')
  end

  def task_type_text_class(assignment_or_type)
    TASK_TYPE_TEXT_CLASSES.fetch(task_type_key(assignment_or_type), 'text-gray-600')
  end

  # Which workspace owns this assignment. The three social-account task types
  # split across /researcher and /verification; demographic research has its
  # own workspace because it works person metadata, not accounts.
  def assignment_workspace(assignment_or_type)
    case task_type_key(assignment_or_type)
    when 'data_collection'      then :researcher
    when 'demographic_research' then :demographics
    else :verification
    end
  end

  def assignment_path_for(assignment)
    case assignment_workspace(assignment)
    when :researcher   then researcher_assignment_path(assignment)
    when :demographics then demographics_assignment_path(assignment)
    else verification_assignment_path(assignment)
    end
  end

  def start_assignment_path_for(assignment)
    case assignment_workspace(assignment)
    when :researcher   then start_researcher_assignment_path(assignment)
    when :demographics then start_demographics_assignment_path(assignment)
    else start_verification_assignment_path(assignment)
    end
  end

  def assignment_queue_path_for(assignment_or_type)
    case assignment_workspace(assignment_or_type)
    when :researcher   then researcher_queue_path
    when :demographics then demographics_assignments_path
    else verification_queue_path
    end
  end

  # Badge used in admin lists: "DC" / "DV" / "SV" / "DR".
  def task_type_badge(assignment_or_type, extra_classes: '')
    tag.span(task_type_abbreviation(assignment_or_type),
             class: "px-2 py-0.5 text-xs font-semibold rounded #{task_type_badge_class(assignment_or_type)} #{extra_classes}".strip,
             title: task_type_label(assignment_or_type))
  end
end
