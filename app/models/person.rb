class Person < ApplicationRecord
  has_paper_trail on: [:create, :update, :destroy]

  # Legacy direct party link (kept for backwards compatibility during migration)
  belongs_to :party_affiliation, class_name: 'Party', optional: true
  
  # New many-to-many party relationship
  has_many :person_parties, dependent: :destroy
  has_many :parties, through: :person_parties
  
  has_many :candidates
  has_many :contests, through: :candidates
  has_many :officeholders
  has_many :offices, through: :officeholders
  has_many :social_media_accounts, dependent: :destroy
  has_many :assignments, dependent: :destroy
  has_many :assigned_researchers, through: :assignments, source: :user
  has_many :demographic_verifications, dependent: :destroy
  belongs_to :demographics_reviewed_by, class_name: 'User', optional: true

  GENDERS = DemographicField::GENDERS
  SUFFIXES = %w[Jr. Sr. II III IV V].freeze

  DEMOGRAPHICS_STATUSES = %w[not_started in_progress complete].freeze

  validates :first_name, presence: true
  validates :last_name, presence: true
  validates :person_uuid, uniqueness: true, allow_nil: true
  validates :airtable_id, uniqueness: true, allow_nil: true
  validates :gender, inclusion: { in: GENDERS, allow_blank: true }
  validates :demographics_status, inclusion: { in: DEMOGRAPHICS_STATUSES }

  # Registry-driven inclusion for the demographic selects. `race` is
  # deliberately excluded: it is a comma-joined multi-value column that already
  # holds 31 legacy free-text variants, and validating it would make every
  # legacy record unsaveable from the election editor. The new UI constrains
  # race through the registry instead.
  DemographicField::ALL.each do |field|
    next unless field.select?
    next if field.key == :gender # validated above against Person::GENDERS

    validates field.key, inclusion: { in: field.options, allow_blank: true }
  end

  validates :children_count, numericality: { only_integer: true, greater_than_or_equal_to: 0,
                                             less_than: 30, allow_nil: true }
  validates :birth_year, numericality: { only_integer: true, greater_than: 1900,
                                         less_than_or_equal_to: -> (_) { Date.current.year },
                                         allow_nil: true }

  # Scopes for filtering by political status
  scope :current_officeholders, -> { 
    joins(:officeholders).merge(Officeholder.current).distinct 
  }
  scope :former_officeholders, -> { 
    where(id: Officeholder.former.select(:person_id))
      .where.not(id: Officeholder.current.select(:person_id))
  }
  scope :officeholders_as_of, ->(date) { 
    joins(:officeholders).merge(Officeholder.as_of(date)).distinct 
  }
  scope :candidates_in_year, ->(year) { 
    joins(:candidates).merge(Candidate.for_year(year)).distinct 
  }
  scope :election_winners_in_year, ->(year) { 
    joins(:candidates).merge(Candidate.for_year(year).winners).distinct 
  }
  scope :election_losers_in_year, ->(year) { 
    joins(:candidates).merge(Candidate.for_year(year).losers).distinct 
  }
  scope :by_state, ->(state) { where(state_of_residence: state) }
  scope :by_party, ->(party) { joins(:parties).where(parties: { id: party }) }
  scope :needs_secondary_verification, -> { where(needs_secondary_verification: true) }

  # --- Demographic research ---------------------------------------------
  # Two independent axes the admin assignment finder filters on:
  #   presence   — is there a value in the column at all?
  #   validation — has a researcher made a sourced determination about it?
  # A person can have values with no review (imported data nobody checked) or
  # a review with no values (researcher looked, nothing is documented).
  scope :demographics_not_started, -> { where(demographics_status: 'not_started') }
  scope :demographics_in_progress, -> { where(demographics_status: 'in_progress') }
  scope :demographics_complete,    -> { where(demographics_status: 'complete') }
  scope :demographics_reviewed,    -> { where.not(demographics_status: 'not_started') }

  scope :missing_demographic_field, ->(key) {
    where(DemographicField.blank_value_sql(key))
  }

  scope :missing_any_core_demographic, -> {
    where(DemographicField::CORE_KEYS.map { |k| DemographicField.blank_value_sql(k) }.join(' OR '))
  }

  scope :all_core_demographics_present, -> {
    where.not(DemographicField::CORE_KEYS.map { |k| DemographicField.blank_value_sql(k) }.join(' OR '))
  }

  # Six of the eight core columns are new and NULL for every existing row, so
  # "all present" matches nobody until the feature has been worked. These two
  # are what the admin filter actually needs today: they separate people who
  # carry imported demographic data from people who have none at all.
  scope :any_core_demographic_present, -> {
    where.not(DemographicField::CORE_KEYS.map { |k| DemographicField.blank_value_sql(k) }.join(' AND '))
  }

  scope :no_core_demographics, -> {
    where(DemographicField::CORE_KEYS.map { |k| DemographicField.blank_value_sql(k) }.join(' AND '))
  }

  scope :with_disputed_demographics, -> {
    where(id: DemographicVerification.disputed.select(:person_id))
  }

  def full_name
    parts = [first_name, middle_name, last_name, suffix].compact_blank
    parts.join(' ')
  end

  def formal_name
    "#{first_name} #{last_name}#{suffix.present? ? ", #{suffix}" : ''}"
  end

  def primary_party
    person_parties.find_by(is_primary: true)&.party || party_affiliation
  end

  def primary_party=(party)
    # Clear existing primary (update_all bypasses the PersonParty touch —
    # touch explicitly on the clear-only path so updated_since stays honest)
    cleared = person_parties.where(is_primary: true).update_all(is_primary: false)

    if party
      pp = person_parties.find_or_initialize_by(party: party)
      pp.is_primary = true
      pp.save!
    elsif cleared.positive?
      touch
    end
  end

  def add_party(party, is_primary: false)
    pp = person_parties.find_or_initialize_by(party: party)
    if is_primary
      person_parties.where(is_primary: true).where.not(party: party).update_all(is_primary: false)
      pp.is_primary = true
    end
    pp.save!
    pp
  end

  # Status check methods
  def current_officeholder?
    officeholders.current.exists?
  end

  # Use this when officeholders are preloaded to avoid N+1 queries
  # Returns true if any loaded officeholder is current
  def current_officeholder_from_loaded?
    return false unless association(:officeholders).loaded?
    officeholders.any?(&:current?)
  end

  def officeholder_on?(date)
    officeholders.as_of(date).exists?
  end

  def candidate_in_year?(year)
    candidates.for_year(year).exists?
  end

  def won_election_in_year?(year)
    candidates.for_year(year).winners.exists?
  end

  def current_offices
    offices.joins(:officeholders).merge(Officeholder.current).distinct
  end

  def offices_held_on(date)
    offices.joins(:officeholders).merge(Officeholder.as_of(date)).distinct
  end

  # Check if any accounts were modified during validation and mark for secondary
  # verification. Deactivated accounts are exempt — deactivation is a terminal
  # disposition, so they don't enter the secondary-verification cycle.
  def mark_for_secondary_verification_if_needed!
    modified_accounts = social_media_accounts.active.where(modified_during_validation: true)

    if modified_accounts.any?
      # Mark the modified accounts as needing secondary verification
      modified_accounts.update_all(needs_secondary_verification: true)

      # Mark the person record
      update!(needs_secondary_verification: true)
    end
  end

  # Clear secondary verification flag after secondary verification is complete
  def clear_secondary_verification!
    update!(needs_secondary_verification: false)
    social_media_accounts.update_all(needs_secondary_verification: false, modified_during_validation: false)
  end

  # Four-eyes rule for secondary verification: the task can't go to the user
  # whose own pending entries are the reason this person is flagged, because
  # they aren't allowed to verify their own work. Lives here so every
  # assignment-creation path enforces it — it used to exist only in
  # Admin::AssignmentsController#create, leaving the per-person and bulk-assign
  # paths able to create an assignment nobody could ever complete.
  def eligible_for_assignment?(user, task_type)
    return true unless task_type == 'secondary_verification'

    !social_media_accounts.needs_secondary_verification
                          .needs_verification
                          .where(entered_by_id: user.id)
                          .exists?
  end

  # --- Demographic research ---------------------------------------------

  # Race is a comma-joined multi-value string (the convention the imported data
  # already used, e.g. "Multiracial, Hispanic or Latino, White").
  def race_values
    DemographicField::RaceValue.split(race)
  end

  def race_values=(values)
    self.race = DemographicField::RaceValue.join(values)
  end

  def demographic_value(key)
    key.to_sym == :race ? race_values : public_send(key)
  end

  def demographic_present?(key)
    value = demographic_value(key)
    value.is_a?(Array) ? value.any? : value.present?
  end

  # Fields that apply to this person (dependent detail fields drop out until
  # their parent answer makes them relevant) and still have no value.
  def missing_demographic_fields
    DemographicField.core_relevant_for(self).reject { |f| demographic_present?(f.key) }
  end

  def demographic_verification_for(key)
    demographic_verifications.detect { |v| v.field_key == key.to_s }
  end

  # Core fields still awaiting a researcher's determination. A field is settled
  # by a verified or unknown status — "we looked and it isn't documented" is a
  # finished answer, a blank column on its own is not.
  def unsettled_demographic_fields
    DemographicField.core_relevant_for(self).reject do |field|
      demographic_verification_for(field.key)&.settled?
    end
  end

  def demographics_complete?
    unsettled_demographic_fields.empty?
  end

  # Recompute the denormalized rollup the admin filters read. Called by
  # DemographicsReview whenever a determination is saved; kept here so a
  # console fix or backfill can reach it too.
  def refresh_demographics_status!(reviewer: nil)
    verifications = demographic_verifications.reload

    status = if verifications.empty?
      'not_started'
    elsif demographics_complete?
      'complete'
    else
      'in_progress'
    end

    attrs = { demographics_status: status }
    if verifications.any?
      attrs[:demographics_reviewed_at] = verifications.filter_map(&:verified_at).max || Time.current
      attrs[:demographics_reviewed_by] = reviewer if reviewer
    else
      # Back to not_started: leaving the old reviewer and timestamp behind would
      # claim someone reviewed a person who now has no determinations at all.
      attrs[:demographics_reviewed_at] = nil
      attrs[:demographics_reviewed_by] = nil
    end

    update!(attrs)
    status
  end
end
