class PopulateBodiesFromOffices < ActiveRecord::Migration[7.2]
  def up
    # Create bodies from distinct body_name values in offices
    execute <<-SQL
      INSERT INTO bodies (name, level, branch, state, country, created_at, updated_at)
      SELECT DISTINCT 
        body_name,
        MAX(level),
        MAX(branch),
        MAX(state),
        'US',
        NOW(),
        NOW()
      FROM offices
      WHERE body_name IS NOT NULL AND body_name != ''
      GROUP BY body_name
      ON CONFLICT (name, country) DO NOTHING
    SQL

    # Link offices to their bodies
    execute <<-SQL
      UPDATE offices
      SET body_id = bodies.id
      FROM bodies
      WHERE offices.body_name = bodies.name
        AND offices.body_name IS NOT NULL
        AND offices.body_name != ''
    SQL

    # Update seats_count on bodies
    execute <<-SQL
      UPDATE bodies
      SET seats_count = subquery.cnt
      FROM (
        SELECT body_id, COUNT(*) as cnt
        FROM offices
        WHERE body_id IS NOT NULL
        GROUP BY body_id
      ) AS subquery
      WHERE bodies.id = subquery.body_id
    SQL
  end

  def down
    execute "UPDATE offices SET body_id = NULL"
    execute "DELETE FROM bodies"
  end
end
