# Integration verification for /api/* endpoints. Run: bin/rails runner tmp/api_verify.rb
# Creates temp records via real HTTP-stack requests, asserts statuses/shapes, cleans up everything.
# NOTE: Warden test-mode login_as only applies to the NEXT request, so every
# request helper re-injects the current user first.
require "warden/test/helpers"

Warden.test_mode!
HELPER = Object.new.extend(Warden::Test::Helpers)

$failures = []
$checks = 0
$current_user = nil

def check(label, condition, detail = nil)
  $checks += 1
  if condition
    puts "  ok  #{label}"
  else
    $failures << label
    puts "  FAIL #{label}#{detail ? " — #{detail}" : ''}"
  end
end

def parse(session)
  JSON.parse(session.response.body)
rescue JSON::ParserError
  {}
end

SESSION = ActionDispatch::Integration::Session.new(Rails.application)
SESSION.host! "localhost"

def relogin
  HELPER.login_as($current_user, scope: :user, store: false) if $current_user
end

def fetch_csrf
  relogin
  SESSION.get "/"
  SESSION.response.body[/name="csrf-token" content="([^"]+)"/, 1]
end

def api_get(path)
  relogin
  SESSION.get(path, headers: { "Accept" => "application/json" })
  parse(SESSION)
end

def mutation_headers
  $csrf ||= fetch_csrf
  { "Content-Type" => "application/json", "Accept" => "application/json", "X-CSRF-Token" => $csrf }
end

def api_post(path, body)
  headers = mutation_headers
  relogin
  SESSION.post(path, params: body.to_json, headers: headers)
  parse(SESSION)
end

def api_patch(path, body)
  headers = mutation_headers
  relogin
  SESSION.patch(path, params: body.to_json, headers: headers)
  parse(SESSION)
end

def api_delete(path)
  headers = mutation_headers
  relogin
  SESSION.delete(path, headers: headers)
  SESSION.response.status
end

admin = researcher = nil
created = { people: [], elections: [], ballots: [], contests: [], candidates: [], accounts: [], offices: [], assignments: [] }

begin
  admin = User.create!(email: "api-verify-admin@example.com", password: "Ap1-verify-pass!", name: "API Verify Admin", role: "admin")
  researcher = User.create!(email: "api-verify-researcher@example.com", password: "Ap1-verify-pass!", name: "API Verify Researcher", role: "researcher")
  $current_user = admin

  check "csrf token available", fetch_csrf.present?

  puts "\n== States =="
  body = api_get("/api/states?per_page=5")
  check "states index 200", SESSION.response.status == 200, SESSION.response.status.to_s
  check "states paginated", body.dig("meta", "total").to_i >= 50 && body["data"]&.size == 5
  state_id = body["data"].first["id"]
  body = api_get("/api/states/#{state_id}")
  check "states show has counts", body["data"].key?("districts_count") && body["data"].key?("ballots_count")

  puts "\n== Parties =="
  body = api_get("/api/parties?per_page=100")
  check "parties index 200", SESSION.response.status == 200
  check "parties count >30", body.dig("meta", "total").to_i > 30
  body = api_get("/api/parties/#{Party.first.id}")
  check "parties show people_count", body["data"].key?("people_count")

  puts "\n== Offices =="
  body = api_get("/api/offices?q=Governor&state=SD")
  check "offices search 200", SESSION.response.status == 200
  body = api_post("/api/offices", { office: { title: "API Verify Office", level: "state", branch: "executive", state: "SD" } })
  check "office create 201", SESSION.response.status == 201, SESSION.response.body[0..200]
  office_id = body.dig("data", "id")
  created[:offices] << office_id if office_id
  body = api_patch("/api/offices/#{office_id}", { office: { seat: "Seat 9" } })
  check "office update", body.dig("data", "seat") == "Seat 9"
  body = api_get("/api/offices/#{office_id}")
  check "office show officeholders key", body["data"].key?("current_officeholders")

  puts "\n== Elections =="
  body = api_get("/api/elections?year=2026&state=SD")
  check "elections index filtered", SESSION.response.status == 200 && body["data"].any?
  ut = Election.find_by(state: "UT", year: 2026)
  body = api_get("/api/elections/#{ut.id}")
  check "election show ballots", body.dig("data", "ballots").is_a?(Array) && body.dig("data", "ballots").size == 7
  body = api_post("/api/elections", { election: { state: "SD", date: "2026-11-03", election_type: "general", name: "API Verify General" } })
  check "election create 201", SESSION.response.status == 201, SESSION.response.body[0..200]
  election_id = body.dig("data", "id")
  created[:elections] << election_id if election_id
  check "election year derived", body.dig("data", "year") == 2026
  body = api_patch("/api/elections/#{election_id}", { election: { name: "API Verify General Updated" } })
  check "election update", body.dig("data", "name") == "API Verify General Updated"

  puts "\n== Ballots =="
  body = api_get("/api/ballots?state=SD&year=2026")
  check "ballots index filtered", SESSION.response.status == 200
  body = api_post("/api/ballots", { ballot: { state: "SD", date: "2026-11-03", election_type: "general", election_id: election_id } })
  check "ballot create 201", SESSION.response.status == 201, SESSION.response.body[0..200]
  ballot_id = body.dig("data", "id")
  created[:ballots] << ballot_id if ballot_id
  body = api_get("/api/ballots/#{ballot_id}")
  check "ballot show contests array", body.dig("data", "contests").is_a?(Array)

  puts "\n== Contests =="
  body = api_post("/api/contests", { contest: { date: "2026-11-03", contest_type: "general", office_id: office_id, ballot_id: ballot_id } })
  check "contest create 201", SESSION.response.status == 201, SESSION.response.body[0..200]
  contest_id = body.dig("data", "id")
  created[:contests] << contest_id if contest_id
  body = api_get("/api/contests?ballot_id=#{ballot_id}")
  check "contests index by ballot", body["data"]&.size == 1
  body = api_get("/api/contests/#{contest_id}")
  check "contest show office+ballot", body.dig("data", "office", "title") == "API Verify Office" && body.dig("data", "ballot").present?

  puts "\n== People =="
  body = api_get("/api/people?q=gronli")
  check "people search finds Gronli", body["data"].any? { |p| p["last_name"] == "Gronli" }
  existing_person = Candidate.joins(:contest).first.person
  body = api_get("/api/people/#{existing_person.id}")
  check "person show candidacies", body.dig("data", "candidacies").is_a?(Array) && body.dig("data", "candidacies").any?
  check "person show socials", body.dig("data", "social_media_accounts").is_a?(Array)
  dem = Party.where("name ILIKE ?", "Democratic%").first
  body = api_post("/api/people", { person: { first_name: "ApiVerify", last_name: "Person", gender: "Female", race: "White", state_of_residence: "SD", primary_party_id: dem&.id }.compact })
  check "person create 201", SESSION.response.status == 201, SESSION.response.body[0..200]
  person_id = body.dig("data", "id")
  created[:people] << person_id if person_id
  check "person primary party set", body.dig("data", "primary_party", "id") == dem&.id
  body = api_patch("/api/people/#{person_id}", { person: { middle_name: "Q" } })
  check "person update", body.dig("data", "middle_name") == "Q"

  puts "\n== Bulk assign =="
  body = api_post("/api/people/bulk_assign", { person_ids: [person_id], user_id: researcher.id, task_type: "data_collection", notes: "api verify" })
  check "bulk assign created", body.dig("meta", "created") == 1, SESSION.response.body[0..200]
  created[:assignments].concat(body["data"].map { |a| a["id"] })
  body = api_post("/api/people/bulk_assign", { person_ids: [person_id], user_id: researcher.id, task_type: "data_collection" })
  check "bulk assign dedupes", body.dig("meta", "skipped") == 1

  puts "\n== Candidates =="
  body = api_post("/api/candidates", { candidate: { person_id: person_id, contest_id: contest_id, party_at_time: "Democratic", incumbent: false } })
  check "candidate create 201 + pending default", SESSION.response.status == 201 && body.dig("data", "outcome") == "pending", SESSION.response.body[0..200]
  candidate_id = body.dig("data", "id")
  created[:candidates] << candidate_id if candidate_id
  body = api_patch("/api/candidates/#{candidate_id}", { candidate: { outcome: "won", tally: 1234 } })
  check "candidate update", body.dig("data", "outcome") == "won" && body.dig("data", "tally") == 1234
  body = api_get("/api/candidates?contest_id=#{contest_id}")
  check "candidates index by contest", body["data"]&.size == 1
  body = api_get("/api/candidates/#{candidate_id}")
  check "candidate detail vote pct", body.dig("data", "vote_percentage").to_f == 100.0

  puts "\n== Social media accounts =="
  # No URL on the verify-test account: keeps it junkipedia-ineligible so the
  # after_commit hook can never fire a live API call.
  body = api_post("/api/social_media_accounts", { social_media_account: { person_id: person_id, platform: "Twitter", handle: "api_verify_handle", channel_type: "Campaign" } })
  check "account create 201", SESSION.response.status == 201, SESSION.response.body[0..200]
  account_id = body.dig("data", "id")
  created[:accounts] << account_id if account_id
  check "account research_status entered", body.dig("data", "research_status") == "entered"

  body = api_post("/api/social_media_accounts/#{account_id}/verify", { notes: "api verify" })
  check "account verify", body.dig("data", "verified") == true && body.dig("data", "verified_by", "email") == admin.email
  check "no junkipedia enqueue (no url)", SocialMediaAccount.find(account_id).junkipedia_enqueued_at.nil?
  body = api_post("/api/social_media_accounts/#{account_id}/reject", { notes: "rejected" })
  check "account reject", body.dig("data", "research_status") == "rejected"

  body = api_post("/api/social_media_accounts", { social_media_account: { person_id: person_id, platform: "Instagram", channel_type: "Campaign" } })
  account2_id = body.dig("data", "id")
  created[:accounts] << account2_id if account2_id
  body = api_post("/api/social_media_accounts/#{account2_id}/mark_entered", { url: "https://www.instagram.com/api_verify", handle: "api_verify" })
  check "account mark_entered", body.dig("data", "url") == "https://www.instagram.com/api_verify"
  body = api_post("/api/social_media_accounts/#{account2_id}/mark_not_found", {})
  check "account mark_not_found", body.dig("data", "research_status") == "not_found" && body.dig("data", "url").nil?
  body = api_get("/api/social_media_accounts?person_id=#{person_id}&platform=Twitter")
  check "accounts index filters", body["data"]&.size == 1

  puts "\n== Validation / authz =="
  body = api_post("/api/people", { person: { first_name: "", last_name: "" } })
  check "validation error 422", SESSION.response.status == 422 && body["code"] == "VALIDATION_ERROR"
  api_get("/api/people/999999999")
  check "not found 404", SESSION.response.status == 404
  api_post("/api/elections", {})
  check "param missing 400", SESSION.response.status == 400

  $current_user = researcher
  $csrf = nil
  api_post("/api/people", { person: { first_name: "X", last_name: "Y" } })
  check "researcher create person forbidden 403", SESSION.response.status == 403, SESSION.response.status.to_s
  api_get("/api/people?per_page=1")
  check "researcher read allowed 200", SESSION.response.status == 200

  $current_user = admin
  $csrf = nil

  puts "\n== Destroys =="
  check "candidate destroy 204", api_delete("/api/candidates/#{candidate_id}") == 204
  created[:candidates].clear
  check "contest destroy 204", api_delete("/api/contests/#{contest_id}") == 204
  created[:contests].clear
  check "ballot destroy 204", api_delete("/api/ballots/#{ballot_id}") == 204
  created[:ballots].clear
  check "election destroy 204", api_delete("/api/elections/#{election_id}") == 204
  created[:elections].clear
  statuses = created[:accounts].map { |id| api_delete("/api/social_media_accounts/#{id}") }
  check "account destroys 204", statuses.all? { |s| s == 204 }
  created[:accounts].clear
ensure
  HELPER.logout
  Warden.test_reset!
  Assignment.where(id: created[:assignments]).destroy_all
  Candidate.where(id: created[:candidates]).destroy_all
  SocialMediaAccount.where(id: created[:accounts]).destroy_all
  Contest.where(id: created[:contests]).destroy_all
  Ballot.where(id: created[:ballots]).destroy_all
  Election.where(id: created[:elections]).destroy_all
  Office.where(id: created[:offices]).destroy_all
  Person.where(id: created[:people]).destroy_all
  researcher&.destroy
  admin&.destroy
end

puts "\n#{$checks} checks, #{$failures.size} failures"
puts $failures.map { |f| "  FAILED: #{f}" }.join("\n") if $failures.any?
exit($failures.any? ? 1 : 0)
