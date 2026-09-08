class AddDemographicFieldsToPeople < ActiveRecord::Migration[8.0]
  def change
    # Demographic values live on `people` alongside the race/gender/birth_date
    # columns that were already here, so the election editor, admin person form
    # and public API keep reading one place. See DemographicField for the
    # registry that defines the vocabulary for each of these.
    change_table :people, bulk: true do |t|
      t.integer :birth_year
      t.string  :marital_status
      t.string  :children_status
      t.integer :children_count
      t.string  :education_level
      t.string  :education_type
      t.string  :education_institution
      t.string  :military_service
      t.string  :military_branch

      # Rollup maintained by DemographicsReview so the admin assignment
      # filters can select on review state without a join per row.
      t.string   :demographics_status, null: false, default: 'not_started'
      t.datetime :demographics_reviewed_at
      t.references :demographics_reviewed_by, foreign_key: { to_table: :users }
    end

    add_index :people, :demographics_status
    add_index :people, :marital_status
    add_index :people, :education_level
    add_index :people, :military_service
  end
end
