# Single source of truth for the demographic metadata researchers collect,
# confirm and annotate on a Person.
#
# Everything downstream derives from this registry: the researcher form, the
# admin "who still needs demographics" filters, the completeness rollup on
# Person, the permitted params, and the specs. Adding a new field is a single
# entry here plus a column on `people` — there is no second list to update.
#
# Values live on `people` (race/gender/birth_date were already there, so the
# election editor, admin person form and public API keep working unchanged).
# The evidence trail lives in `demographic_verifications`, one row per
# person+field.
class DemographicField
  Field = Struct.new(
    :key,          # Symbol — must match a column on `people`
    :label,        # Human label shown to researchers and admins
    :kind,         # :select, :multi_select, :date, :integer, :string
    :options,      # Array of allowed values for (multi_)select
    :hint,         # One-line guidance shown under the control
    :group,        # Form section
    :depends_on,   # { field_key => [values that make this field relevant] }
    :core,         # Counts toward "complete" — dependent detail fields do not
    keyword_init: true
  ) do
    def select?       = kind == :select
    def multi_select? = kind == :multi_select
    def options?      = select? || multi_select?

    # Is this field relevant given the person's current values? Dependent
    # fields (children_count, military_branch) stay hidden and are never
    # counted as missing until their parent answer makes them meaningful.
    def relevant_for?(person)
      return true if depends_on.blank?

      depends_on.all? do |parent_key, trigger_values|
        Array(trigger_values).include?(person.public_send(parent_key))
      end
    end
  end

  RACES = [
    'American Indian or Alaska Native',
    'Asian',
    'Black or African American',
    'Hispanic or Latino',
    'Middle Eastern or North African',
    'Native Hawaiian or Other Pacific Islander',
    'White',
    'Other'
  ].freeze

  GENDERS = ['Male', 'Female', 'Non-binary', 'Other'].freeze

  MARITAL_STATUSES = [
    'Single (never married)',
    'Married',
    'Divorced',
    'Widowed',
    'Separated',
    'Domestic partnership'
  ].freeze

  CHILDREN_STATUSES = ['Has children', 'No children'].freeze

  EDUCATION_LEVELS = [
    'No high school diploma',
    'High school diploma or GED',
    'Some college (no degree)',
    'Associate degree',
    "Bachelor's degree",
    "Master's degree",
    'Professional degree (JD, MD, DDS, etc.)',
    'Doctorate (PhD, EdD, etc.)'
  ].freeze

  EDUCATION_TYPES = [
    'Public university or college',
    'Private university or college (non-religious)',
    'Religious college or university',
    'Community or technical college',
    'Military academy',
    'For-profit institution',
    'No post-secondary institution'
  ].freeze

  MILITARY_SERVICE_STATUSES = [
    'Never served',
    'Veteran',
    'Active duty',
    'Reserve or National Guard'
  ].freeze

  MILITARY_BRANCHES = [
    'Army',
    'Navy',
    'Air Force',
    'Marine Corps',
    'Coast Guard',
    'Space Force',
    'National Guard'
  ].freeze

  SERVED_STATUSES = (MILITARY_SERVICE_STATUSES - ['Never served']).freeze

  # NOTE: option lists deliberately contain no "Unknown" entry. A researcher who
  # looked and could not determine an answer records that as a field *status*
  # (`unknown`), which carries their notes and sources — an "Unknown" value
  # would lose that distinction between "nobody looked" and "we looked, it
  # isn't publicly documented".
  ALL = [
    Field.new(
      key: :gender, label: 'Gender', kind: :select, options: GENDERS, group: 'Identity',
      hint: 'How the person is publicly described. Prefer their own self-description.',
      core: true
    ),
    Field.new(
      key: :race, label: 'Race / ethnicity', kind: :multi_select, options: RACES, group: 'Identity',
      hint: 'Select every category that applies. Prefer self-identification over inference from a photo or surname.',
      core: true
    ),
    Field.new(
      key: :birth_date, label: 'Date of birth', kind: :date, group: 'Identity',
      hint: 'Full date when you can source it.',
      core: true
    ),
    Field.new(
      key: :birth_year, label: 'Birth year', kind: :integer, group: 'Identity',
      hint: 'Use when only the year (or a reported age) is documented.',
      core: false
    ),
    Field.new(
      key: :marital_status, label: 'Marital status', kind: :select, options: MARITAL_STATUSES,
      group: 'Family', hint: 'Current status, not history.',
      core: true
    ),
    Field.new(
      key: :children_status, label: 'Children', kind: :select, options: CHILDREN_STATUSES,
      group: 'Family', core: true
    ),
    Field.new(
      key: :children_count, label: 'Number of children', kind: :integer, group: 'Family',
      depends_on: { children_status: ['Has children'] },
      hint: 'Only if a source states a count.',
      core: false
    ),
    Field.new(
      key: :education_level, label: 'Highest education level', kind: :select,
      options: EDUCATION_LEVELS, group: 'Education', core: true
    ),
    Field.new(
      key: :education_type, label: 'Institution type', kind: :select, options: EDUCATION_TYPES,
      group: 'Education', hint: 'Type of institution granting the highest degree.',
      core: true
    ),
    Field.new(
      key: :education_institution, label: 'Institution name', kind: :string, group: 'Education',
      hint: 'School granting the highest degree, e.g. "University of Texas at Austin".',
      core: false
    ),
    Field.new(
      key: :military_service, label: 'Military service', kind: :select,
      options: MILITARY_SERVICE_STATUSES, group: 'Service', core: true
    ),
    Field.new(
      key: :military_branch, label: 'Branch', kind: :select, options: MILITARY_BRANCHES,
      group: 'Service', depends_on: { military_service: SERVED_STATUSES },
      core: false
    )
  ].freeze

  KEYS      = ALL.map(&:key).freeze
  CORE_KEYS = ALL.select(&:core).map(&:key).freeze
  GROUPS    = ALL.map(&:group).uniq.freeze

  BY_KEY = ALL.index_by(&:key).freeze

  class << self
    def all = ALL

    def find(key)
      BY_KEY[key.to_sym]
    end

    def key?(key)
      BY_KEY.key?(key.to_s.to_sym)
    end

    def grouped
      ALL.group_by(&:group)
    end

    def label_for(key)
      find(key)&.label || key.to_s.humanize
    end

    # Fields that actually apply to this person right now — dependent detail
    # fields drop out until their parent answer makes them relevant.
    def relevant_for(person)
      ALL.select { |field| field.relevant_for?(person) }
    end

    def core_relevant_for(person)
      relevant_for(person).select(&:core)
    end

    # SQL fragment for "this field has no value", used to build the admin
    # presence filters. String columns treat '' as absent; date and integer
    # columns only have NULL.
    def blank_value_sql(key)
      field = find(key)
      raise ArgumentError, "unknown demographic field: #{key.inspect}" unless field

      column = "people.#{field.key}"
      if Person.columns_hash[field.key.to_s]&.type == :string
        "(#{column} IS NULL OR #{column} = '')"
      else
        "#{column} IS NULL"
      end
    end
  end

  # Race is stored in the existing free-text `people.race` column as a
  # comma-joined list, matching the convention already in the data
  # ("Multiracial, Hispanic or Latino, White"). These helpers are the only
  # place that convention is encoded.
  module RaceValue
    SEPARATOR = ', '.freeze

    module_function

    def split(value)
      value.to_s.split(',').map(&:strip).reject(&:blank?)
    end

    def join(values)
      Array(values).map { |v| v.to_s.strip }.reject(&:blank?).uniq.join(SEPARATOR).presence
    end
  end
end
