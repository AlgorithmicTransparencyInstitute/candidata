class Assignment < ApplicationRecord
  has_paper_trail

  TASK_TYPES = %w[data_collection data_validation].freeze
  STATUSES = %w[pending in_progress completed].freeze

  belongs_to :user
  belongs_to :assigned_by, class_name: 'User'
  belongs_to :person

  validates :task_type, presence: true, inclusion: { in: TASK_TYPES }
  validates :status, presence: true, inclusion: { in: STATUSES }
  validates :user_id, uniqueness: { scope: [:person_id, :task_type], message: 'already has this task for this person' }

  scope :pending, -> { where(status: 'pending') }
  scope :in_progress, -> { where(status: 'in_progress') }
  scope :completed, -> { where(status: 'completed') }
  scope :data_collection, -> { where(task_type: 'data_collection') }
  scope :data_validation, -> { where(task_type: 'data_validation') }
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
end
