require 'rails_helper'

# Smoke test: the admin record pages touched by the ballots/contests/offices/
# elections work render without ERB or query errors.
RSpec.describe 'Admin records pages render', type: :request do
  let(:admin) { create(:user, :admin) }
  before { sign_in admin }

  let(:election) { Election.create!(state: 'OH', date: Date.new(2026, 5, 5), election_type: 'primary', year: 2026) }
  let(:district) { District.create!(state: 'OH', level: 'state', chamber: 'lower', district_number: 5, ocdid: 'ocd-division/country:us/state:oh/sldl:5') }
  let(:office) { Office.create!(title: 'State Representative', level: 'state', branch: 'legislative', state: 'OH', district: district, office_category: 'State Representative', body_name: 'OH State House') }
  let(:ballot) do
    Ballot.create!(state: 'OH', date: election.date, election_type: 'primary',
                   party: 'Democratic', year: 2026, election: election)
  end
  let!(:contest) do
    Contest.create!(office: office, ballot: ballot, date: ballot.date, party: 'Democratic', contest_type: 'primary')
  end

  it 'renders the election show page with the add-ballots panel' do
    get admin_election_path(election)
    expect(response).to have_http_status(:ok)
    expect(response.body).to include('Add party ballots')
  end

  it 'renders the ballots index with filters' do
    get admin_ballots_path
    expect(response).to have_http_status(:ok)
    expect(response.body).to include('Party')
  end

  it 'renders the ballots index filtered by state without error' do
    get admin_ballots_path, params: { state: 'OH' }
    expect(response).to have_http_status(:ok)
  end

  it 'renders the new-ballot form (prefilled from an election)' do
    get new_admin_ballot_path(election_id: election.id)
    expect(response).to have_http_status(:ok)
  end

  it 'renders the new-contest form with the searchable office picker' do
    get new_admin_contest_path
    expect(response).to have_http_status(:ok)
    expect(response.body).to include('office-search')
  end

  describe 'record lists render and filter without error' do
    it 'districts index + state filter + search' do
      get admin_districts_path
      expect(response).to have_http_status(:ok)
      get admin_districts_path, params: { state: 'OH', q: 'sldl', level: 'state', chamber: 'lower' }
      expect(response).to have_http_status(:ok)
    end

    it 'offices index + state/branch/category filters' do
      get admin_offices_path, params: { state: 'OH', branch: 'legislative', category: 'State Representative', q: 'Representative' }
      expect(response).to have_http_status(:ok)
      expect(response.body).to include('State Representative')
    end

    it 'contests index + party/state/type filters' do
      get admin_contests_path, params: { party: 'Democratic', state: 'OH', contest_type: 'primary' }
      expect(response).to have_http_status(:ok)
    end

    it 'elections index' do
      get admin_elections_path, params: { state: 'OH' }
      expect(response).to have_http_status(:ok)
    end

    it 'admin guide renders' do
      get admin_guide_path
      expect(response).to have_http_status(:ok)
    end
  end

  describe 'record show pages render with cross-links' do
    it 'office show' do
      get admin_office_path(office)
      expect(response).to have_http_status(:ok)
      expect(response.body).to include(admin_district_path(district))
    end

    it 'district show' do
      get admin_district_path(district)
      expect(response).to have_http_status(:ok)
      expect(response.body).to include(admin_office_path(office))
    end

    it 'contest show links to ballot, office, election' do
      get admin_contest_path(contest)
      expect(response).to have_http_status(:ok)
      expect(response.body).to include(admin_ballot_path(ballot), admin_office_path(office), admin_election_path(election))
    end

    it 'ballot show links to election and lists office' do
      get admin_ballot_path(ballot)
      expect(response).to have_http_status(:ok)
      expect(response.body).to include(admin_election_path(election), admin_office_path(office))
    end
  end
end
