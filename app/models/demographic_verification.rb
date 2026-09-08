# The evidence trail behind one demographic claim about one person.
#
# A row exists once a researcher has made a determination about a field —
# including the determination that the answer is not publicly documented
# (`unknown`) or that sources conflict (`disputed`). No row means nobody has
# looked yet, which is a different thing and is why "Unknown" is not offered
# as a *value* in DemographicField's option lists.
class DemographicVerification < ApplicationRecord
  has_paper_trail on: [:create, :update, :destroy]

  belongs_to :person
  belongs_to :verified_by, class_name: 'User', optional: true
  belongs_to :assignment, optional: true

  STATUSES = %w[verified unknown disputed].freeze

  STATUS_LABELS = {
    'verified' => 'Verified',
    'unknown'  => 'Not publicly documented',
    'disputed' => 'Sources conflict'
  }.freeze

  # A field is settled once someone has made a determination they stand behind.
  # `disputed` deliberately does not settle it — it is a request for a second
  # opinion, and keeps the person short of "complete".
  SETTLED_STATUSES = %w[verified unknown].freeze

  validates :field_key, presence: true,
                        inclusion: { in: DemographicField::KEYS.map(&:to_s) },
                        uniqueness: { scope: :person_id }
  validates :status, presence: true, inclusion: { in: STATUSES }

  # source_url is researcher-supplied and gets rendered into an href that an
  # admin clicks on the person page. Restrict it to http(s) at the boundary so a
  # "javascript:" or "data:" URL can never be stored in the first place.
  validates :source_url, format: { with: %r{\Ahttps?://}i, allow_blank: true,
                                   message: 'must be a http:// or https:// link' }

  scope :settled,  -> { where(status: SETTLED_STATUSES) }
  scope :disputed, -> { where(status: 'disputed') }
  scope :for_field, ->(key) { where(field_key: key.to_s) }

  def field
    DemographicField.find(field_key)
  end

  def label
    DemographicField.label_for(field_key)
  end

  def status_label
    STATUS_LABELS.fetch(status, status.to_s.humanize)
  end

  def settled?
    status.in?(SETTLED_STATUSES)
  end

  # Evidence is optional for `unknown` (there is nothing to cite when the
  # answer isn't documented) but a verified claim should say where it came from.
  def evidence?
    source_url.present? || notes.present?
  end
end
