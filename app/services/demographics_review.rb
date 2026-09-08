# Applies one submission of the demographic research form: writes the values
# onto the Person, records the per-field evidence trail in
# DemographicVerification, and refreshes the rollup the admin filters read.
#
# The whole submission is one transaction — a person is never left with values
# saved but their evidence lost, which would look like verified data nobody
# can trace.
class DemographicsReview
  Result = Struct.new(:success?, :errors, :settled_count, keyword_init: true)

  # A determination that asserts a fact has to say where the fact came from.
  # `unknown` is exempt: there is nothing to cite when the answer simply isn't
  # publicly documented.
  EVIDENCE_REQUIRED_STATUSES = %w[verified disputed].freeze

  def initialize(person:, user:, assignment: nil)
    @person = person
    @user = user
    @assignment = assignment
    @errors = {}
  end

  # values:   { gender: "Male", race: ["White"], birth_date: "1970-01-02", ... }
  # evidence: { gender: { status:, source_url:, notes: }, ... }
  def save(values: {}, evidence: {})
    values = (values || {}).to_h.symbolize_keys
    evidence = (evidence || {}).to_h.symbolize_keys

    ActiveRecord::Base.transaction do
      apply_values(values)
      validate_evidence(evidence)

      raise ActiveRecord::Rollback if @errors.any?

      unless @person.save
        @person.errors.each { |e| @errors[e.attribute] = e.message }
        raise ActiveRecord::Rollback
      end

      apply_evidence(evidence)
      @person.refresh_demographics_status!(reviewer: @user)
    end

    Result.new(
      success?: @errors.empty?,
      errors: @errors,
      settled_count: @person.demographic_verifications.reload.count(&:settled?)
    )
  end

  private

  def apply_values(values)
    DemographicField::ALL.each do |field|
      next unless values.key?(field.key)

      raw = values[field.key]

      if field.multi_select?
        # race is the one multi-value field; it round-trips through the
        # comma-joined convention already present in the imported data.
        @person.race_values = Array(raw).reject(&:blank?)
        next
      end

      @person.public_send("#{field.key}=", raw.is_a?(String) ? raw.strip.presence : raw)
    end

    clear_irrelevant_dependents
  end

  # If the answer that made a detail field relevant changes ("Veteran" →
  # "Never served"), the stale detail must not linger on the record.
  def clear_irrelevant_dependents
    DemographicField::ALL.each do |field|
      next if field.depends_on.blank?
      next if field.relevant_for?(@person)

      @person.public_send("#{field.key}=", nil)
      @person.demographic_verifications.where(field_key: field.key.to_s).destroy_all
    end
  end

  def validate_evidence(evidence)
    evidence.each do |key, attrs|
      next unless DemographicField.key?(key)
      # The form echoes back a determination for every rendered row. If this
      # submission just made the field irrelevant ("Veteran" → "Never served"),
      # its stale determination must be dropped, not validated — otherwise the
      # researcher gets a blocking error on a row the page no longer shows.
      next unless relevant?(key)

      attrs = attrs.to_h.symbolize_keys
      status = attrs[:status].presence
      next if status.nil?

      unless DemographicVerification::STATUSES.include?(status)
        @errors[key] = "is not a valid determination"
        next
      end

      if EVIDENCE_REQUIRED_STATUSES.include?(status) &&
         attrs[:source_url].blank? && attrs[:notes].blank?
        @errors[key] = "needs a source link or a note explaining the determination"
        next
      end

      if status == 'verified' && !@person.demographic_present?(key)
        @errors[key] = "can't be marked verified without a value — use \"Not publicly documented\" instead"
        next
      end

      # Mirrors DemographicVerification's format validation, so the researcher
      # gets a field-level message instead of a raised RecordInvalid from
      # apply_evidence.
      if attrs[:source_url].present? && !attrs[:source_url].match?(%r{\Ahttps?://}i)
        @errors[key] = "source must be a http:// or https:// link"
      end
    end
  end

  def apply_evidence(evidence)
    evidence.each do |key, attrs|
      next unless DemographicField.key?(key)
      # Without this, the row clear_irrelevant_dependents just destroyed would
      # be recreated from the echoed-back form state, leaving a determination
      # attached to a field that no longer applies to this person.
      next unless relevant?(key)

      attrs = attrs.to_h.symbolize_keys
      status = attrs[:status].presence

      # A blank determination leaves any existing row alone: the researcher
      # simply hasn't ruled on this field in this pass.
      next if status.nil?

      record = @person.demographic_verifications.find_or_initialize_by(field_key: key.to_s)
      record.assign_attributes(
        status: status,
        value_snapshot: snapshot_for(key),
        source_url: attrs[:source_url].presence,
        notes: attrs[:notes].presence,
        verified_by: @user,
        verified_at: Time.current,
        assignment: @assignment
      )
      record.save!
    end
  end

  # Relevance is judged against the person as this submission leaves them, not
  # as they were loaded.
  def relevant?(key)
    DemographicField.find(key)&.relevant_for?(@person)
  end

  def snapshot_for(key)
    value = @person.demographic_value(key)
    value.is_a?(Array) ? DemographicField::RaceValue.join(value) : value&.to_s
  end
end
