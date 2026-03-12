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

  desc "Show what would be pushed (counts by platform)"
  task preview: :environment do
    accounts = SocialMediaAccount
      .active
      .where.not(url: [nil, ''])

    puts "=== All Active Accounts with URLs ==="
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
