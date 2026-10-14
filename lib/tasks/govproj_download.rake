# Downloads the current CTCL GovProj officeholder CSVs (one per state/territory)
# from ballotinfo.org into data/govproj/<last-modified-date>/, converted from
# CTCL's UTF-16 to UTF-8 TSV so govproj:load_temp etc. can read them.
#
# Credentials come from a curl netrc file (never pass them on the command line):
#   printf 'machine ballotinfo.org login USER password PASS\n' > ~/.ballotinfo_netrc
#   chmod 600 ~/.ballotinfo_netrc
#
#   bin/rails govproj:download            # NETRC=path to override ~/.ballotinfo_netrc
namespace :govproj do
  desc "Download current GovProj CSVs from ballotinfo.org into data/govproj/<date>/"
  task download: :environment do
    require "open3"
    base  = "https://ballotinfo.org/govproj/csv/"
    netrc = File.expand_path(ENV.fetch("NETRC", "~/.ballotinfo_netrc"))
    abort "Missing #{netrc} (see header of #{__FILE__})" unless File.exist?(netrc)

    curl = ->(*args) {
      out, err, status = Open3.capture3("curl", "-sSf", "--netrc-file", netrc, *args)
      abort "curl failed: #{err}" unless status.success?
      out
    }

    index = curl.call(base)
    entries = index.scan(%r{href="([a-z]{2}_office_holders\.csv)".*?(\d{4}-\d{2}-\d{2}) \d{2}:\d{2}})
    abort "No CSVs found in index - login or page format changed?" if entries.empty?

    dest = Rails.root.join("data", "govproj", entries.map(&:last).max)
    FileUtils.mkdir_p(dest)
    puts "Downloading #{entries.size} files (latest update #{entries.map(&:last).max}) to #{dest}"

    entries.each do |name, _date|
      raw = curl.call("#{base}#{name}").b
      text = raw.start_with?("\xFF\xFE".b, "\xFE\xFF".b) ? raw.force_encoding("UTF-16").encode("UTF-8") : raw.force_encoding("UTF-8")
      File.write(dest.join(name), text.delete_prefix("﻿"))
      print "."
    end
    puts "\nDone. Load with: CSV_DIR=#{dest.relative_path_from(Rails.root)} bin/rails govproj:load_temp"
  end
end
