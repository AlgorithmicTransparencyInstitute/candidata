# Fast fuzzy name search for the public site (/search, /people?q=). A GIN
# trigram index on the full display name serves ILIKE '%…%' and similarity()
# lookups without scanning every row. Additive only.
class AddTrigramNameSearchToPeople < ActiveRecord::Migration[8.0]
  disable_ddl_transaction!

  def up
    enable_extension 'pg_trgm'
    execute <<~SQL
      CREATE INDEX CONCURRENTLY IF NOT EXISTS index_people_on_search_name_trgm
      ON people USING gin (
        lower(coalesce(first_name, '') || ' ' || coalesce(last_name, '')) gin_trgm_ops
      )
    SQL
  end

  def down
    execute 'DROP INDEX CONCURRENTLY IF EXISTS index_people_on_search_name_trgm'
  end
end
