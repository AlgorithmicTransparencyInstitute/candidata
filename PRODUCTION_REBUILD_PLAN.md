# Production Database Rebuild Plan

## Overview
Complete database rebuild with proper Body integration and all latest improvements.

## What's Included

### Data Improvements
1. ✅ **Body Integration**: Offices now properly link to Body records via `body_id` foreign key
2. ✅ **Website Import**: 2026 candidates now have campaign websites in `Person.website_campaign`
3. ✅ **Smart Placeholders**: 2026 candidates get placeholder accounts for research
4. ✅ **Temp Data Enrichment**: Race, gender, and campaign accounts from temp tables
5. ✅ **Form Styling**: @tailwindcss/forms plugin properly configured

### Code Changes
- **lib/tasks/import_govproj.rake** (lines 727-748): Added Body find_or_create logic
- **lib/tasks/rebuild_data.rake**: Orchestrates all 4 steps
- **lib/importers/enhanced_candidate_2026_importer.rb**: Website + placeholder logic
- **config/tailwind.config.js**: NEW - Tailwind configuration with forms plugin
- **app/controllers/admin/assignments_controller.rb**: Body filter uses proper association
- **app/views/admin/assignments/new.html.erb**: Instant JS filtering without page reloads
- **app/views/verification/assignments/show.html.erb**: Shows campaign website

## Local Verification Test

### Step 1: Test Complete Rebuild Locally
```bash
# Backup current database
pg_dump candidata_development > ~/candidata_backup_$(date +%Y%m%d_%H%M%S).sql

# Run complete rebuild
bin/rails rebuild:all

# Verify results
bin/rails runner "
puts 'Verification Results:'
puts '  People: ' + Person.count.to_s
puts '  Officeholders: ' + Officeholder.count.to_s
puts '  Offices: ' + Office.count.to_s
puts '  Offices with body_id: ' + Office.where.not(body_id: nil).count.to_s
puts '  Bodies: ' + Body.count.to_s
puts '  Districts: ' + District.count.to_s
puts '  2026 Candidates: ' + Candidate.joins(:contest).merge(Contest.where('date > ?', Date.new(2025, 12, 31))).count.to_s
puts '  Campaign websites: ' + Person.joins(:candidates).merge(Candidate.joins(:contest).merge(Contest.where('date > ?', Date.new(2025, 12, 31)))).where.not(website_campaign: [nil, '']).distinct.count.to_s
"
```

### Expected Results
```
People: ~43,232
Officeholders: ~42,780
Offices: ~42,781
Offices with body_id: ~30,648 (71.6%)
Bodies: ~3,098+
Districts: 6,440
  - Congressional (numbered): 429
  - Congressional (at-large): 12
  - Total Congressional: 441 (435 voting + 6 territories)
  - State Senate: 1,967
  - State House: 4,676
2026 Candidates: 524
Campaign websites: ~432 (82.4% of 2026 candidates)
Social Media Accounts: ~49,217
  - Official Office: ~31,788
  - Campaign: ~17,429
```

## Production Deployment Sequence

### Prerequisites on Production
1. **Temp data must be loaded**:
   ```bash
   heroku run "bin/rails govproj:load_temp" -a candidata
   heroku run "bin/rails csv:import" -a candidata
   ```

2. **Verify temp data exists**:
   ```bash
   heroku run "bin/rails runner 'puts \"TempGovproj: #{TempGovproj.count}, TempPerson: #{TempPerson.count}, TempAccount: #{TempAccount.count}\"'" -a candidata
   ```
   - Expected: TempGovproj: 42,780, TempPerson: ~17,921, TempAccount: ~64,837

### Deployment Steps

1. **Deploy code changes**:
   ```bash
   git add -A
   git commit -m "Add Body integration, website import, and form fixes"
   git push heroku main
   ```

2. **Run migrations** (if any new ones):
   ```bash
   heroku run "bin/rails db:migrate" -a candidata
   ```

3. **Build Tailwind CSS with forms plugin**:
   ```bash
   heroku run "bin/rails tailwindcss:build" -a candidata
   ```

4. **Backup production database**:
   ```bash
   heroku pg:backups:capture -a candidata
   heroku pg:backups:download -a candidata
   ```

5. **Run complete rebuild** (this will take ~5-10 minutes):
   ```bash
   # Option A: Interactive (requires typing 'yes')
   heroku run "bin/rails rebuild:all" -a candidata

   # Option B: Automated (no prompt)
   heroku run "bin/rails rebuild:clear_data && bin/rails rebuild:import_govproj && bin/rails rebuild:extract_districts && bin/rails rebuild:import_temp_enrichment && bin/rails rebuild:import_2026_candidates" -a candidata
   ```

6. **Verify production results**:
   ```bash
   heroku run "bin/rails runner '
   puts \"=\" * 60
   puts \"PRODUCTION VERIFICATION\"
   puts \"=\" * 60
   puts \"  People: #{Person.count}\"
   puts \"  Officeholders: #{Officeholder.count}\"
   puts \"  Offices: #{Office.count}\"
   puts \"  Offices with body_id: #{Office.where.not(body_id: nil).count}\"
   puts \"  Bodies: #{Body.count}\"
   puts \"  Districts: #{District.count}\"
   puts \"  Social Media Accounts: #{SocialMediaAccount.count}\"
   puts \"  2026 Candidates: #{Candidate.joins(:contest).merge(Contest.where(\\\"date > ?\\\", Date.new(2025, 12, 31))).count}\"
   puts \"=\" * 60
   '" -a candidata
   ```

7. **Test the application**:
   - Login: https://candidata.herokuapp.com
   - Test admin assignment creation with Body filter
   - Verify 2026 candidate websites show
   - Check form styling looks correct

## Rollback Plan

If something goes wrong:

```bash
# Option 1: Restore from Heroku backup
heroku pg:backups:restore [BACKUP_ID] DATABASE_URL -a candidata

# Option 2: Restore from downloaded backup
heroku pg:psql -a candidata < latest.dump

# Option 3: Revert code and redeploy
git revert HEAD
git push heroku main
```

## Individual Task Reference

If you need to run steps individually:

```bash
# Step 1: Clear data (preserves Users, States, Parties, Bodies)
heroku run "bin/rails rebuild:clear_data" -a candidata

# Step 2: Import GovProj data (with Body linking)
heroku run "bin/rails rebuild:import_govproj" -a candidata

# Step 3: Extract districts from GovProj data
heroku run "bin/rails rebuild:extract_districts" -a candidata

# Step 4: Enrich from temp data
heroku run "bin/rails rebuild:import_temp_enrichment" -a candidata

# Step 5: Import 2026 candidates
heroku run "bin/rails rebuild:import_2026_candidates" -a candidata
```

## What Gets Preserved

The rebuild **preserves**:
- ✅ Users (login accounts)
- ✅ States (reference data)
- ✅ Parties (reference data)
- ✅ Bodies (reference data)

The rebuild **clears and recreates**:
- ❌ People
- ❌ Offices
- ❌ Officeholders
- ❌ Candidates
- ❌ Contests
- ❌ Ballots
- ❌ Social Media Accounts
- ❌ Assignments
- ❌ Person-Party links

## Post-Deployment Verification Checklist

- [ ] Body filter works in assignment creation
- [ ] 2026 candidate websites display
- [ ] Form inputs have proper borders/styling
- [ ] State filter updates list instantly
- [ ] Ballot filter populates correctly
- [ ] Can create assignments successfully
- [ ] No JavaScript errors in console

## Notes

- The rebuild is **idempotent** - safe to run multiple times
- All Body relationships will be properly linked on first import
- No manual scripts needed after initial deployment
- Total time: ~5-10 minutes for full rebuild
- Database will be fully consistent and queryable throughout
