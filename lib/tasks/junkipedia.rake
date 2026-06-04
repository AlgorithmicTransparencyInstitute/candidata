namespace :junkipedia do
  desc "Create a new multi-platform list in Junkipedia and print the list ID"
  task :create_list, [:name, :description] => :environment do |_t, args|
    name = args[:name] || "Candidata Officials #{Date.today}"
    description = args[:description] || "Social media accounts exported from Candidata"

    service = JunkipediaService.new
    result = service.create_list(name: name, description: description)
    list_id = result['id']

    puts "Created Junkipedia list: #{name}"
    puts "List ID: #{list_id}"
    puts ""
    puts "To push accounts to this list, run:"
    puts "  bin/rails junkipedia:push_accounts[#{list_id}]"
  end

  desc "Push active social media accounts to a Junkipedia list"
  task :push_accounts, [:list_id] => :environment do |_t, args|
    list_id = args[:list_id]
    abort "Usage: bin/rails junkipedia:push_accounts[LIST_ID]" unless list_id.present?

    service = JunkipediaService.new
    dry_run = ENV['DRY_RUN'] == '1'

    # Query active accounts with a URL or handle, on supported platforms, excluding BlueSky
    accounts = SocialMediaAccount
      .active
      .where.not(url: [nil, ''])
      .where(platform: JunkipediaService::SUPPORTED_PLATFORMS)

    total = accounts.count
    puts "Found #{total} active accounts on supported platforms with URLs"
    puts "Mode: #{dry_run ? 'DRY RUN (no API calls)' : 'LIVE'}"
    puts ""

    # Platform breakdown
    platform_counts = accounts.group(:platform).count
    platform_counts.sort_by { |_, v| -v }.each do |platform, count|
      junkipedia_name = JunkipediaService.junkipedia_platform(platform)
      puts "  #{platform} (→ #{junkipedia_name}): #{count}"
    end
    puts ""

    succeeded = 0
    failed = 0
    skipped = 0
    errors = []

    accounts.find_each.with_index do |account, index|
      component_id = JunkipediaService.component_id_for(account)

      if component_id.blank?
        skipped += 1
        next
      end

      person_name = account.person&.name || "Unknown"
      platform = account.platform
      progress = "[#{index + 1}/#{total}]"

      if dry_run
        puts "#{progress} Would add #{platform} #{component_id} (#{person_name})"
        succeeded += 1
        next
      end

      begin
        result = service.add_component(list_id: list_id, component_id: component_id)
        channel_id = result['channel_id']
        succeeded += 1
        puts "#{progress} Added #{platform} #{component_id} (#{person_name}) → channel_id: #{channel_id}"
      rescue JunkipediaService::JunkipediaError => e
        failed += 1
        error_msg = "#{progress} FAILED #{platform} #{component_id} (#{person_name}): #{e.message}"
        errors << error_msg
        puts error_msg
      end

      # Rate limit: small delay between API calls
      sleep(0.25) unless dry_run
    end

    puts ""
    puts "=== Summary ==="
    puts "Total:     #{total}"
    puts "Succeeded: #{succeeded}"
    puts "Failed:    #{failed}"
    puts "Skipped:   #{skipped} (no URL or handle)"

    if errors.any?
      puts ""
      puts "=== Errors ==="
      errors.each { |e| puts e }
    end
  end

  desc "Push accounts for a specific platform only"
  task :push_platform, [:list_id, :platform] => :environment do |_t, args|
    list_id = args[:list_id]
    platform = args[:platform]
    abort "Usage: bin/rails junkipedia:push_platform[LIST_ID,Platform]" unless list_id.present? && platform.present?
    abort "Unsupported platform: #{platform}" unless JunkipediaService.supported_platform?(platform)

    service = JunkipediaService.new
    dry_run = ENV['DRY_RUN'] == '1'

    accounts = SocialMediaAccount
      .active
      .where.not(url: [nil, ''])
      .where(platform: platform)

    total = accounts.count
    puts "Found #{total} active #{platform} accounts with URLs"
    puts "Mode: #{dry_run ? 'DRY RUN' : 'LIVE'}"
    puts ""

    succeeded = 0
    failed = 0

    accounts.find_each.with_index do |account, index|
      component_id = JunkipediaService.component_id_for(account)
      next if component_id.blank?

      person_name = account.person&.name || "Unknown"
      progress = "[#{index + 1}/#{total}]"

      if dry_run
        puts "#{progress} Would add #{component_id} (#{person_name})"
        succeeded += 1
        next
      end

      begin
        result = service.add_component(list_id: list_id, component_id: component_id)
        channel_id = result['channel_id']
        succeeded += 1
        puts "#{progress} Added #{component_id} (#{person_name}) → channel_id: #{channel_id}"
      rescue JunkipediaService::JunkipediaError => e
        failed += 1
        puts "#{progress} FAILED #{component_id} (#{person_name}): #{e.message}"
      end

      sleep(0.25) unless dry_run
    end

    puts ""
    puts "Succeeded: #{succeeded} | Failed: #{failed}"
  end

  desc "Create a list for a state and push all its accounts. Usage: bin/rails junkipedia:push_state[TX]"
  task :push_state, [:state_abbrev] => :environment do |_t, args|
    abbrev = args[:state_abbrev]&.upcase
    abort "Usage: bin/rails junkipedia:push_state[TX]" unless abbrev.present?

    state = State.find_by(abbreviation: abbrev)
    abort "Unknown state abbreviation: #{abbrev}" unless state

    service = JunkipediaService.new
    dry_run = ENV['DRY_RUN'] == '1'

    people = Person.where(state_of_residence: abbrev)
    accounts = SocialMediaAccount.active
      .where.not(url: [nil, ''])
      .where(person: people)
      .where(platform: JunkipediaService::SUPPORTED_PLATFORMS)
      .includes(:person)

    total = accounts.count
    abort "No accounts found for #{state.name} (#{abbrev})" if total == 0

    # Create the list unless a list_id is provided via env var
    list_id = ENV['LIST_ID']
    unless list_id
      list_name = "Candidata - #{state.name} Officials"
      if dry_run
        puts "DRY RUN: Would create list '#{list_name}'"
        list_id = 'DRY_RUN'
      else
        result = service.create_list(
          name: list_name,
          description: "Social media accounts for #{state.name} elected officials and candidates, exported from Candidata"
        )
        list_id = result['id']
        puts "Created list '#{list_name}' → ID: #{list_id}"
      end
    end

    puts "Pushing #{total} #{abbrev} accounts to list #{list_id}"
    puts "Mode: #{dry_run ? 'DRY RUN' : 'LIVE'}"
    puts ""

    accounts.group(:platform).count.sort_by { |_, v| -v }.each do |platform, count|
      puts "  #{platform}: #{count}"
    end
    puts ""

    succeeded = 0
    failed = 0
    errors = []

    accounts.find_each.with_index do |account, index|
      component_id = JunkipediaService.component_id_for(account)
      next if component_id.blank?

      person_name = account.person&.name rescue "Unknown"
      platform = account.platform
      progress = "[#{index + 1}/#{total}]"

      if dry_run
        puts "#{progress} Would add #{platform} #{component_id} (#{person_name})"
        succeeded += 1
        next
      end

      begin
        result = service.add_component(list_id: list_id, component_id: component_id)
        channel_id = result['channel_id']
        succeeded += 1
        puts "#{progress} Added #{platform} #{component_id} (#{person_name}) → channel_id: #{channel_id}"
      rescue JunkipediaService::JunkipediaError => e
        failed += 1
        error_msg = "#{progress} FAILED #{platform} #{component_id} (#{person_name}): #{e.message}"
        errors << error_msg
        puts error_msg
      end

      sleep(0.2) unless dry_run
    end

    puts ""
    puts "=== #{state.name} Push Complete ==="
    puts "List ID:   #{list_id}"
    puts "Total:     #{total}"
    puts "Succeeded: #{succeeded}"
    puts "Failed:    #{failed}"

    if errors.any?
      puts ""
      puts "=== Errors (#{errors.length}) ==="
      errors.each { |e| puts e }
    end
  end

  desc "Push all states, creating one list per state. Usage: bin/rails junkipedia:push_all_states"
  task push_all_states: :environment do
    dry_run = ENV['DRY_RUN'] == '1'

    states_with_accounts = Person
      .where.not(state_of_residence: [nil, ''])
      .joins(:social_media_accounts)
      .merge(SocialMediaAccount.active.where.not(url: [nil, '']))
      .group(:state_of_residence)
      .count
      .sort_by { |_, v| -v }

    puts "=== States with pushable accounts ==="
    states_with_accounts.each { |s, c| puts "  #{s}: #{c}" }
    puts ""
    puts "Total: #{states_with_accounts.sum(&:last)} accounts across #{states_with_accounts.length} states"
    puts ""

    if dry_run
      puts "DRY RUN: No lists will be created. Run without DRY_RUN=1 to proceed."
    else
      puts "To push a specific state: bin/rails junkipedia:push_state[TX]"
      puts "To push all, set CONFIRM=1: CONFIRM=1 bin/rails junkipedia:push_all_states"

      if ENV['CONFIRM'] == '1'
        states_with_accounts.each do |abbrev, _count|
          puts ""
          puts "=== Starting #{abbrev} ==="
          Rake::Task['junkipedia:push_state'].reenable
          Rake::Task['junkipedia:push_state'].invoke(abbrev)
        end
      end
    end
  end

  desc "Show what would be pushed (counts by platform, optionally by state)"
  task preview: :environment do
    accounts = SocialMediaAccount
      .active
      .where.not(url: [nil, ''])

    if ENV['STATE'].present?
      abbrev = ENV['STATE'].upcase
      accounts = accounts.where(person: Person.where(state_of_residence: abbrev))
      puts "=== #{abbrev} Active Accounts with URLs ==="
    else
      puts "=== All Active Accounts with URLs ==="
    end

    total_supported = 0
    total_unsupported = 0

    accounts.group(:platform).count.sort_by { |_, v| -v }.each do |platform, count|
      supported = JunkipediaService.supported_platform?(platform)
      marker = supported ? "✓" : "✗ (not supported)"
      puts "  #{platform}: #{count} #{marker}"
      if supported
        total_supported += count
      else
        total_unsupported += count
      end
    end

    puts ""
    puts "Supported: #{total_supported} accounts ready to push"
    puts "Unsupported: #{total_unsupported} accounts (will be skipped)"
  end

  desc "List existing Junkipedia lists"
  task lists: :environment do
    service = JunkipediaService.new
    result = service.get_lists
    lists = result['data'] || result

    if lists.is_a?(Array)
      lists.each do |list|
        puts "ID: #{list['id']} | Name: #{list['name']} | Channels: #{list['channels_count']}"
      end
    else
      puts result.inspect
    end
  end

  desc "Push all accounts to per-state lists, reusing existing Candidata - {STATE} Officials lists if present"
  task push_all_idempotent: :environment do
    dry_run = ENV['DRY_RUN'] == '1'
    only_abbrev = ENV['ONLY']&.upcase
    sleep_seconds = (ENV['SLEEP'] || '0.2').to_f

    service = JunkipediaService.new
    headers = service.instance_variable_get(:@headers)

    puts "Fetching existing Junkipedia lists..."
    all_lists = []
    page = 1
    loop do
      resp = service.class.get("/lists?page=#{page}&per_page=100", headers: headers)
      data = resp.parsed_response['data'] || []
      break if data.empty?
      all_lists.concat(data)
      break if data.length < 100
      page += 1
    end

    existing = {}
    all_lists.each do |l|
      name = l.dig('attributes', 'name').to_s
      if name =~ /^Candidata - (.+) Officials$/
        existing[$1] = l['id'].to_i
      end
    end
    puts "Found #{existing.length} existing Candidata state lists: #{existing.keys.sort.join(', ')}"
    puts ""

    states_with_accounts = Person
      .where.not(state_of_residence: [nil, ''])
      .joins(:social_media_accounts)
      .merge(SocialMediaAccount.active.where.not(url: [nil, '']))
      .where(social_media_accounts: { platform: JunkipediaService::SUPPORTED_PLATFORMS })
      .group(:state_of_residence)
      .count
      .sort_by { |_, v| -v }

    states_with_accounts = states_with_accounts.select { |abbrev, _| abbrev == only_abbrev } if only_abbrev

    grand_total = states_with_accounts.sum(&:last)
    puts "States to push: #{states_with_accounts.length} | Total accounts: #{grand_total}"
    puts "Mode: #{dry_run ? 'DRY RUN' : 'LIVE'} | sleep=#{sleep_seconds}s"
    puts ""

    overall = { succeeded: 0, failed: 0, skipped: 0, lists_created: 0, lists_reused: 0 }

    states_with_accounts.each_with_index do |(abbrev, count), state_idx|
      state = State.find_by(abbreviation: abbrev)
      unless state
        puts "[#{abbrev}] SKIP: no State record"
        next
      end

      list_id = existing[state.name]
      if list_id
        overall[:lists_reused] += 1
        puts "[#{state_idx + 1}/#{states_with_accounts.length}] #{abbrev} (#{state.name}): reusing list #{list_id} | #{count} accounts"
      elsif dry_run
        puts "[#{state_idx + 1}/#{states_with_accounts.length}] #{abbrev} (#{state.name}): DRY would create list | #{count} accounts"
        next
      else
        result = service.create_list(
          name: "Candidata - #{state.name} Officials",
          description: "Social media accounts for #{state.name} elected officials and candidates, exported from Candidata"
        )
        list_id = result['id']
        existing[state.name] = list_id
        overall[:lists_created] += 1
        puts "[#{state_idx + 1}/#{states_with_accounts.length}] #{abbrev} (#{state.name}): CREATED list #{list_id} | #{count} accounts"
      end

      next if dry_run

      accounts = SocialMediaAccount.active
        .where.not(url: [nil, ''])
        .where(person: Person.where(state_of_residence: abbrev))
        .where(platform: JunkipediaService::SUPPORTED_PLATFORMS)
        .includes(:person)
        .order(:platform, :id)

      state_stats = { ok: 0, fail: 0, skip: 0 }
      accounts.find_each.with_index do |account, i|
        cid = JunkipediaService.component_id_for(account)
        if cid.blank?
          state_stats[:skip] += 1
          next
        end
        begin
          service.add_component(list_id: list_id, component_id: cid)
          state_stats[:ok] += 1
        rescue JunkipediaService::JunkipediaError => e
          state_stats[:fail] += 1
          puts "  [#{abbrev}] FAIL #{account.platform} #{cid.to_s[0..80]}: #{e.message.to_s[0..160]}"
        end
        sleep(sleep_seconds)
        if (i + 1) % 50 == 0
          puts "  [#{abbrev}] progress: #{i + 1}/#{accounts.size} ok=#{state_stats[:ok]} fail=#{state_stats[:fail]}"
        end
      end

      overall[:succeeded] += state_stats[:ok]
      overall[:failed] += state_stats[:fail]
      overall[:skipped] += state_stats[:skip]
      puts "[#{abbrev}] DONE: ok=#{state_stats[:ok]} fail=#{state_stats[:fail]} skip=#{state_stats[:skip]}"
      puts ""
    end

    puts "=" * 60
    puts "ALL STATES COMPLETE"
    puts "  Lists reused:  #{overall[:lists_reused]}"
    puts "  Lists created: #{overall[:lists_created]}"
    puts "  Accounts OK:   #{overall[:succeeded]}"
    puts "  Accounts FAIL: #{overall[:failed]}"
    puts "  Skipped:       #{overall[:skipped]}"
    puts "=" * 60
  end

  desc "Match Candidata pending accounts against existing Junkipedia channels (throttled, rate-limit aware)"
  task match_pending: :environment do
    target_rate    = (ENV['RATE'] || '1.2').to_f          # req/sec; 1.2 ≈ 4320/hour, under 5000/hour cap
    floor_rate     = (ENV['FLOOR'] || '0.3').to_f         # never go below this (3.3s between calls) even when remaining is low
    safety_buffer  = (ENV['BUFFER'] || '50').to_i         # pause when x-ratelimit-remaining falls below this
    limit          = ENV['LIMIT']&.to_i
    only_state     = ENV['STATE']&.upcase
    include_errored = ENV['INCLUDE_ERRORED'] != '0'        # default: also retry rate-limited error rows

    service = JunkipediaService.new

    scope = SocialMediaAccount.junkipedia_pending
    scope = scope.joins(:person).where(people: { state_of_residence: only_state }) if only_state
    if include_errored
      err_scope = SocialMediaAccount.junkipedia_eligible
                    .where(junkipedia_channel_id: [nil, ''])
                    .where.not(junkipedia_last_error: [nil, ''])
      err_scope = err_scope.joins(:person).where(people: { state_of_residence: only_state }) if only_state
      ids = (scope.pluck(:id) + err_scope.pluck(:id)).uniq
    else
      ids = scope.pluck(:id)
    end
    ids = ids.first(limit) if limit

    total    = ids.size
    started  = Time.now
    matched  = 0
    missed   = 0
    skipped  = 0
    errored  = 0

    interval = 1.0 / target_rate
    puts "=" * 70
    puts "MATCH PENDING: #{total} accounts, target #{target_rate} req/sec (#{interval.round(2)}s between calls)"
    puts "  STATE=#{only_state || 'all'} INCLUDE_ERRORED=#{include_errored} LIMIT=#{limit || 'none'}"
    puts "=" * 70

    ids.each_with_index do |id, i|
      acct = SocialMediaAccount.find_by(id: id)
      unless acct
        skipped += 1
        next
      end

      handle = JunkipediaService.handle_from(acct)
      if handle.blank?
        skipped += 1
        acct.update_columns(junkipedia_last_error: "no derivable handle from url=#{acct.url}")
      else
        begin
          resp = service.search_channel(
            handle: handle,
            platform: JunkipediaService.junkipedia_platform(acct.platform)
          )
          cid = JunkipediaService.first_channel_id(resp)
          if cid
            now = Time.current
            updates = {
              junkipedia_channel_id: cid,
              junkipedia_id_collected_at: now,
              junkipedia_last_error: nil
            }
            updates[:junkipedia_enqueued_at] = now if acct.junkipedia_enqueued_at.nil?
            acct.update_columns(updates)
            matched += 1
          else
            missed += 1
            acct.update_columns(junkipedia_last_error: nil) if acct.junkipedia_last_error.present?
          end
        rescue JunkipediaService::RateLimitError => e
          wait = [e.seconds_until_reset, 60].max
          puts "  [#{i+1}/#{total}] RATE LIMITED — sleeping #{wait}s until window resets"
          sleep wait
          retry
        rescue JunkipediaService::JunkipediaError => e
          errored += 1
          acct.update_columns(junkipedia_last_error: e.message.to_s.truncate(1000))
        end
      end

      # Adaptive pace: if we're close to the cap, sleep until the window resets
      remaining = JunkipediaService.rate_limit_remaining
      reset_at  = JunkipediaService.rate_limit_reset
      if remaining && remaining < safety_buffer && reset_at
        wait = [reset_at - Time.now.to_i, 0].max + 5
        puts "  [#{i+1}/#{total}] remaining=#{remaining} below buffer=#{safety_buffer} — sleeping #{wait}s"
        sleep wait
      else
        sleep [interval, 1.0 / [target_rate, 0.001].max].max
      end

      if (i + 1) % 100 == 0 || i + 1 == total
        elapsed = Time.now - started
        rate = (i + 1) / elapsed
        eta_min = ((total - i - 1) / [rate, 0.001].max / 60).round
        rem_str = remaining ? "remaining=#{remaining}" : ""
        puts "  [#{i+1}/#{total}] matched=#{matched} missed=#{missed} err=#{errored} skipped=#{skipped} | #{rate.round(2)}/s ETA=#{eta_min}min #{rem_str}"
      end
    end

    puts "=" * 70
    puts "DONE in #{((Time.now - started) / 60).round(1)} min"
    puts "  matched=#{matched}  missed=#{missed}  errored=#{errored}  skipped=#{skipped}  of #{total}"
    puts "=" * 70
  end

  desc "Clear junkipedia_last_error for all eligible accounts so they retry cleanly"
  task clear_errors: :environment do
    scope = SocialMediaAccount.where.not(junkipedia_last_error: [nil, ''])
    n = scope.update_all(junkipedia_last_error: nil)
    puts "Cleared junkipedia_last_error on #{n} rows"
  end

  desc "Show channels in a Junkipedia list"
  task :list_channels, [:list_id] => :environment do |_t, args|
    list_id = args[:list_id]
    abort "Usage: bin/rails junkipedia:list_channels[LIST_ID]" unless list_id.present?

    service = JunkipediaService.new
    result = service.get_channels(list_id)
    channels = result['data'] || result

    if channels.is_a?(Array)
      channels.each do |ch|
        puts "#{ch['id']} | #{ch['platform']} | #{ch['title'] || ch['name']} | #{ch['url']}"
      end
      puts ""
      puts "Total: #{channels.length} channels"
    else
      puts result.inspect
    end
  end
end
