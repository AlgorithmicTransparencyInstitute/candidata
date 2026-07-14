require 'rails_helper'

# Smoke test: the admin record pages touched by the ballots/contests/offices/
# elections work render without ERB or query errors.
RSpec.describe 'Admin records pages render', type: :request do
  let(:admin) { create(:user, :admin) }
  before { sign_in admin }

  let(:election) { Election.create!(state: 'OH', date: Date.new(2026, 5, 5), election_type: 'primary', year: 2026) }
  let(:office) { Office.create!(title: 'Governor', level: 'state', branch: 'executive', state: 'OH') }
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
end
