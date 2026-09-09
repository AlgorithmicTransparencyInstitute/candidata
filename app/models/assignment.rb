class Assignment < ApplicationRecord
  has_paper_trail

  TASK_TYPES = %w[data_collection data_validation secondary_verification demographic_research].freeze
  STATUSES = %w[pending in_progress completed].freeze

  # Presentation is centralised here rather than re-derived at each call site.
  # Before this existed the mapping was inlined in eight places, several of
  # them two-way ternaries that silently mislabelled secondary_verification.
  TASK_TYPE_LABELS = {
    'data_collection'       => 'Data Collection',
    'data_validation'       => 'Data Validation',
    'secondary_verification' => 'Secondary Verification',
    'demographic_research'  => 'Demographic Research'
  }.freeze

  # The single word used in the researcher sidebar and queue headings.
  TASK_TYPE_SHORT_LABELS = {
    'data_collection'       => 'Collection',
    'data_validation'       => 'Validation',
    'secondary_verification' => 'Verification',
    'demographic_research'  => 'Demographics'
  }.freeze

  TASK_TYPE_COLORS = {
    'data_collection'       => 'blue',
    'data_validation'       => 'purple',
    'secondary_verification' => 'red',
    'demographic_research'  => 'teal'
  }.freeze

  TASK_TYPE_ABBREVIATIONS = {
    'data_collection'       => 'DC',
    'data_validation'       => 'DV',
    'secondary_verification' => 'SV',
    'demographic_research'  => 'DR'
  }.freeze

  belongs_to :user
  belongs_to :assigned_by, class_name: 'User'
  belongs_to :person

  # Nullify, not destroy: the evidence behind a demographic determination should
  # outlive the work ticket that produced it. Without this the DB foreign key
  # (NO ACTION) makes an assignment undeletable once any determination has been
  # recorded against it.
  has_many :demographic_verifications, dependent: :nullify

  validates :task_type, presence: true, inclusion: { in: TASK_TYPES }
  validates :status, presence: true, inclusion: { in: STATUSES }
  validates :user_id, uniqueness: { scope: [:person_id, :task_type], message: 'already has this task for this person' }
  validate :required_demographic_fields_are_known

  # An unknown key would silently drop out of the gate and let the assignment
  # complete without the work being done.
  def required_demographic_fields_are_known
    return if required_demographic_fields.blank?

    unknown = required_demographic_fields.map(&:to_s) - DemographicField::KEYS.map(&:to_s)
    return if unknown.empty?

    errors.add(:required_demographic_fields, "contains unknown field(s): #{unknown.join(', ')}")
  end

  scope :pending, -> { where(status: 'pending') }
  scope :in_progress, -> { where(status: 'in_progress') }
  scope :completed, -> { where(status: 'completed') }
  scope :data_collection, -> { where(task_type: 'data_collection') }
  scope :data_validation, -> { where(task_type: 'data_validation') }
  scope :secondary_verification, -> { where(task_type: 'secondary_verification') }
  scope :demographic_research, -> { where(task_type: 'demographic_research') }
  # Both task types worked in the Verification workspace. Demographic research
  # is deliberately outside this scope — it works person metadata rather than
  # social accounts, and lives in its own /demographics workspace.
  scope :verification_tasks, -> { where(task_type: %w[data_validation secondary_verification]) }
  scope :for_user, ->(user) { where(user: user) }
  scope :active, -> { where(status: %w[pending in_progress]) }

  def start!
    update!(status: 'in_progress')
  end

  def complete!
    update!(status: 'completed', completed_at: Time.current)
  end

  def reopen!
    update!(status: 'in_progress', completed_at: nil)
  end

  def has_validation_assignment?
    Assignment.where(person_id: person_id, task_type: 'data_validation')
              .where.not(status: 'completed')
              .exists?
  end

  def pending?
    status == 'pending'
  end

  def in_progress?
    status == 'in_progress'
  end

  def completed?
    status == 'completed'
  end

  def label
    TASK_TYPE_LABELS.fetch(task_type, task_type.to_s.humanize)
  end

  def short_label
    TASK_TYPE_SHORT_LABELS.fetch(task_type, task_type.to_s.humanize)
  end

  def color
    TASK_TYPE_COLORS.fetch(task_type, 'gray')
  end

  def abbreviation
    TASK_TYPE_ABBREVIATIONS.fetch(task_type, 'UN')
  end

  def demographic_research?
    task_type == 'demographic_research'
  end

  # --- Scoped demographic research --------------------------------------
  #
  # An assigner can narrow a demographic task to a subset of fields ("just get
  # me race and gender for these 500 people"). The subset gates completion of
  # THIS assignment only.
  #
  # It deliberately does NOT feed `people.demographics_status`: a person whose
  # race and gender were sourced is not demographically complete, and letting a
  # narrow task claim otherwise would quietly break the admin filters that
  # depend on that rollup meaning "all core fields settled". Person-level
  # completeness stays person-level; see Person#demographics_complete?.

  # Blank means every core field — the historic behaviour, and what an assigner
  # gets if they don't narrow the task.
  def scoped_demographics?
    required_demographic_fields.present?
  end

  def demographic_fields_required
    return DemographicField::ALL.select(&:core) unless scoped_demographics?

    keys = required_demographic_fields.map(&:to_s)
    DemographicField::ALL.select { |field| keys.include?(field.key.to_s) }
  end

  # Dependent detail fields still drop out when the parent answer makes them
  # irrelevant, exactly as they do for an unscoped task.
  def demographic_fields_required_for(target = person)
    demographic_fields_required.select { |field| field.relevant_for?(target) }
  end

  def unsettled_demographic_fields(target = person)
    demographic_fields_required_for(target).reject do |field|
      target.demographic_verification_for(field.key)&.settled?
    end
  end

  def demographic_fields_complete?(target = person)
    unsettled_demographic_fields(target).empty?
  end

  def required_demographic_field?(key)
    demographic_fields_required.any? { |field| field.key.to_s == key.to_s }
  end

  def demographic_scope_summary
    return 'All demographic fields' unless scoped_demographics?

    demographic_fields_required.map(&:label).to_sentence
  end
end
