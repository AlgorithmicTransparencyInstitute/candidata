class AddRequiredDemographicFieldsToAssignments < ActiveRecord::Migration[8.0]
  def change
    # Which demographic fields THIS assignment must settle before it can be
    # completed. Empty means "every core field", which is both the historic
    # behaviour and the sensible default, so existing rows need no backfill.
    add_column :assignments, :required_demographic_fields, :string, array: true, default: []
  end
end
