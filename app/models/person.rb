class Person < ApplicationRecord
  has_paper_trail

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

  GENDERS = %w[Male Female Other].freeze
  SUFFIXES = %w[Jr. Sr. II III IV V].freeze
  
  validates :first_name, presence: true
  validates :last_name, presence: true
  validates :person_uuid, uniqueness: true, allow_nil: true
  validates :airtable_id, uniqueness: true, allow_nil: true
  validates :gender, inclusion: { in: GENDERS, allow_blank: true }

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
    # Clear existing primary
    person_parties.where(is_primary: true).update_all(is_primary: false)
    
    # Set new primary
    if party
      pp = person_parties.find_or_initialize_by(party: party)
      pp.is_primary = true
      pp.save!
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

  # Check if any accounts were modified during validation and mark for secondary verification
  def mark_for_secondary_verification_if_needed!
    modified_accounts = social_media_accounts.where(modified_during_validation: true)

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
end
