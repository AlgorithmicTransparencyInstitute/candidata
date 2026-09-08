# Rendering for the demographic research form. The controls are driven off
# DemographicField, so a new entry in that registry shows up here with no
# change to the views.
module DemographicsHelper
  INPUT_CLASSES = 'w-full rounded-lg border-gray-300 text-sm shadow-sm focus:border-teal-500 focus:ring-teal-500'.freeze
  INPUT_ERROR_CLASSES = 'w-full rounded-lg border-red-400 text-sm shadow-sm focus:border-red-500 focus:ring-red-500'.freeze

  STATUS_BADGE_CLASSES = {
    'verified' => 'bg-green-100 text-green-800',
    'unknown'  => 'bg-slate-100 text-slate-700',
    'disputed' => 'bg-amber-100 text-amber-800'
  }.freeze

  STATUS_ROW_CLASSES = {
    'verified' => 'border-green-200 bg-green-50/40',
    'unknown'  => 'border-slate-200 bg-slate-50/60',
    'disputed' => 'border-amber-300 bg-amber-50'
  }.freeze

  DETERMINATION_OPTIONS = [
    ['— No determination yet —', ''],
    ['Verified', 'verified'],
    ['Not publicly documented', 'unknown'],
    ['Sources conflict', 'disputed']
  ].freeze

  def demographic_input_classes(error: false)
    error ? INPUT_ERROR_CLASSES : INPUT_CLASSES
  end

  # Defence in depth on the render side: the model rejects non-http(s) source
  # URLs on write, but rows predating that validation (or written by console or
  # import) must never become a clickable "javascript:" link in an admin's
  # session. Returns nil for anything that isn't a plain web link.
  def safe_source_url(url)
    url.presence&.match?(%r{\Ahttps?://}i) ? url : nil
  end

  def demographic_status_badge_class(status)
    STATUS_BADGE_CLASSES.fetch(status.to_s, 'bg-gray-100 text-gray-600')
  end

  def demographic_row_class(status, error: false)
    return 'border-red-300 bg-red-50' if error

    STATUS_ROW_CLASSES.fetch(status.to_s, 'border-gray-200 bg-white')
  end

  def demographic_status_label(status)
    DemographicVerification::STATUS_LABELS.fetch(status.to_s, 'Not reviewed')
  end

  # The value control for one field. Name is always values[<key>] so the
  # controller can permit the whole set off the registry.
  def demographic_value_input(field, person, error: false)
    name = "values[#{field.key}]"
    classes = demographic_input_classes(error: error)
    current = person.public_send(field.key)

    case field.kind
    when :select
      # A stored value outside the vocabulary is carried as its own option, so
      # re-saving the form can't silently blank it.
      options = field.options.map { |o| [o, o] }
      if current.present? && !field.options.include?(current)
        options << ["#{current} (not in standard list)", current]
      end

      safe_join([
        select_tag(name, options_for_select([['— Select —', '']] + options, current), class: classes),
        legacy_value_notice(field, Array(current.presence))
      ].compact)
    when :multi_select
      render_multi_select(field, person)
    when :date
      date_field_tag name, current, class: classes
    when :integer
      number_field_tag name, current, class: classes, min: 0
    else
      text_field_tag name, current, class: classes
    end
  end

  private

  # Race is multi-value: a hidden empty entry keeps "cleared everything" a real
  # submission rather than a missing key the controller would ignore.
  #
  # Any stored value outside the vocabulary gets its own CHECKED box rather than
  # being dropped. 462 people in production carry a legacy race token
  # ("white, non-Hispanic", "Black", "WHhite"); without this, saving the form to
  # record something unrelated — a gender, say — would silently blank their race,
  # because the hidden entry means `values[race]` is submitted on every save.
  # Now the form round-trips losslessly and removing a legacy value is an
  # explicit untick.
  def render_multi_select(field, person)
    selected = person.demographic_value(field.key)
    legacy = Array(selected) - field.options

    boxes = field.options.map { |option| multi_select_box(field, option, selected.include?(option)) }
    legacy_boxes = legacy.map { |option| multi_select_box(field, option, true, legacy: true) }

    safe_join([
      hidden_field_tag("values[#{field.key}][]", '', id: nil),
      tag.div(class: 'grid grid-cols-1 sm:grid-cols-2 gap-x-4 gap-y-1.5') { safe_join(boxes + legacy_boxes) },
      legacy_value_notice(field, selected)
    ].compact)
  end

  def multi_select_box(field, option, checked, legacy: false)
    label_class = legacy ? 'flex items-center gap-2 text-sm text-amber-900 cursor-pointer' :
                           'flex items-center gap-2 text-sm text-gray-700 cursor-pointer'
    box_class = legacy ? 'rounded border-amber-400 text-amber-600 focus:ring-amber-500' :
                         'rounded border-gray-300 text-teal-600 focus:ring-teal-500'

    tag.label(class: label_class) do
      safe_join([
        check_box_tag("values[#{field.key}][]", option, checked,
                      id: "#{field.key}_#{option.parameterize.underscore}",
                      class: box_class),
        tag.span(option),
        legacy ? tag.span('(non-standard)', class: 'text-xs text-amber-600') : nil
      ].compact)
    end
  end

  # Imported data holds 31 free-text race variants ("white, non-Hispanic",
  # "WHhite", "Not sure") that aren't in the controlled list. They are preserved
  # and pre-ticked; this explains what the researcher is looking at.
  def legacy_value_notice(field, selected)
    unrecognized = Array(selected) - field.options
    return if unrecognized.empty?

    tag.p(class: 'mt-2 text-xs text-amber-800 bg-amber-50 border border-amber-200 rounded px-2 py-1.5') do
      safe_join([
        'Currently recorded as ',
        tag.strong(unrecognized.join(', ')),
        ', which is not in the standard list. It is kept as-is unless you change it — ',
        'tick the standard categories that apply and untick the old value.'
      ])
    end
  end
end
