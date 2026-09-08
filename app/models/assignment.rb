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
end
