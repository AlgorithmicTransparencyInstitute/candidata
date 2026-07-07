# Integration verification for the public /api/v1 API.
# Run: bin/rails runner lib/scripts/public_api_verify.rb
# Read-only against the dev DB except for one temp ApiToken (deleted at the end).

$failures = []
$checks = 0

def check(label, condition, detail = nil)
  $checks += 1
  if condition
    puts "  ok  #{label}"
  else
    $failures << label
    puts "  FAIL #{label}#{detail ? " — #{detail}" : ''}"
  end
end

SESSION = ActionDispatch::Integration::Session.new(Rails.application)
SESSION.host! "localhost"

def api_get(path, token: nil, params: {})
  headers = token ? { "Authorization" => "Bearer #{token}" } : {}
  SESSION.get(path, params: params, headers: headers)
  body = begin
    JSON.parse(SESSION.response.body)
  rescue JSON::ParserError
    {}
  end
  [SESSION.response.status, body]
end

token = ApiToken.generate!(name: "public-api-verify-temp")
raw = token.raw_token

begin
  puts "== auth"
  status, body = api_get("/api/v1/people", params: { per_page: 1 })
  check("no token -> 401 UNAUTHORIZED", status == 401 && body["code"] == "UNAUTHORIZED")
  status, = api_get("/api/v1/people", token: "cnd_live_" + "0" * 24, params: { per_page: 1 })
  check("bad token -> 401", status == 401)
  status, body = api_get("/api/v1/people", token: raw, params: { per_page: 1 })
  check("valid token -> 200 with data+meta", status == 200 && body.key?("data") && body.key?("meta"))
  check("last_used_at stamped", token.reload.last_used_at.present?)

  puts "== officeholders"
  status, body = api_get("/api/v1/officeholders", token: raw, params: { per_page: 2 })
  check("index 200", status == 200)
  check("rows have person+office", body["data"].all? { |r| r["person"] && r["office"] })
  check("default rows are current", body["data"].all? { |r| r["current"] == true })

  sample = Officeholder.current.joins(office: :district)
                       .where.not(districts: { district_number: nil })
                       .where(offices: { office_category: "U.S. Representative" }).first
  if sample
    d = sample.office.district
    status, body = api_get("/api/v1/officeholders", token: raw,
                           params: { state: d.state, office_category: "U.S. Representative",
                                     district: d.district_number, chamber: d.chamber })
    found = body["data"].any? { |r| r["id"] == sample.id }
    check("district lookup finds known rep (#{d.state}-#{d.district_number})", status == 200 && found)
  else
    puts "  skip district lookup (no current U.S. Representative with district in DB)"
  end

  holder_with_party = Officeholder.current.joins(person: { person_parties: :party })
                                  .where(person_parties: { is_primary: true }).first
  if holder_with_party
    abbr = holder_with_party.person.person_parties.find(&:is_primary).party.abbreviation
    status, body = api_get("/api/v1/officeholders", token: raw, params: { party: abbr, per_page: 5 })
    check("party filter (#{abbr}) returns rows", status == 200 && body["data"].any?)
  else
    puts "  skip party filter (no current officeholder with a primary party)"
  end

  puts "== candidates"
  status, body = api_get("/api/v1/candidates", token: raw, params: { per_page: 2 })
  check("index 200 with contest chain", status == 200 &&
        body["data"].all? { |r| r["person"] && r["contest"] && r["contest"]["office"] })
  status, body = api_get("/api/v1/candidates", token: raw, params: { winners: "true", per_page: 100 })
  check("winners=true only won/advanced", status == 200 &&
        body["data"].all? { |r| %w[won advanced].include?(r["outcome"]) })
  status, body = api_get("/api/v1/candidates", token: raw, params: { incumbent: "true", per_page: 50 })
  check("incumbent=true only incumbents", status == 200 && body["data"].all? { |r| r["incumbent"] })

  puts "== people"
  status, body = api_get("/api/v1/people", token: raw, params: { per_page: 2 })
  check("index 200", status == 200)
  no_leak = !body.to_json.match?(/research_status|junkipedia|entered_by|needs_secondary/)
  check("no workflow fields in payload", no_leak)
  all_verified = body["data"].flat_map { |p| p["social_media_accounts"] }.none? { |a| a.key?("verified") }
  check("socials have no verified flag (implicitly verified-only)", all_verified)

  uuid_person = Person.where.not(person_uuid: nil).joins(:social_media_accounts)
                      .where(social_media_accounts: { verified: true }).first
  if uuid_person
    status, body = api_get("/api/v1/people/#{uuid_person.person_uuid}", token: raw)
    check("show by uuid 200", status == 200 && body["data"]["person_uuid"] == uuid_person.person_uuid)
    verified_count = uuid_person.social_media_accounts.verified.active.count
    check("show returns only verified+active socials (#{verified_count})",
          body["data"]["social_media_accounts"].length == verified_count)
  else
    puts "  skip uuid show (no person with uuid + verified account)"
  end
  status, body = api_get("/api/v1/people/00000000-0000-0000-0000-000000000000", token: raw)
  check("unknown uuid -> 404 NOT_FOUND", status == 404 && body["code"] == "NOT_FOUND")

  puts "== params"
  status, body = api_get("/api/v1/people", token: raw, params: { updated_since: "garbage" })
  check("bad updated_since -> 400 INVALID_PARAM", status == 400 && body["code"] == "INVALID_PARAM")
  status, body = api_get("/api/v1/people", token: raw, params: { per_page: 9999, page: 1 })
  check("per_page capped at 500", status == 200 && body["meta"]["per_page"] == 500)
  status, body = api_get("/api/v1/people", token: raw,
                         params: { updated_since: 1.week.ago.iso8601, per_page: 1 })
  check("updated_since filters", status == 200 && body["meta"]["total"] <= Person.count)

  puts "== revocation"
  token.revoke!
  status, = api_get("/api/v1/people", token: raw, params: { per_page: 1 })
  check("revoked token -> 401", status == 401)
ensure
  token.destroy
end

puts
if $failures.empty?
  puts "ALL #{$checks} CHECKS PASSED"
else
  puts "#{$failures.size}/#{$checks} FAILED: #{$failures.join(', ')}"
  exit 1
end
