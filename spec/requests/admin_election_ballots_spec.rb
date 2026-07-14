require 'rails_helper'

# Pins the election-page "add ballots" feature: find-or-create ballots for an
# election (idempotent, linked, party-validated). See ElectionsController#add_ballots.
RSpec.describe 'Admin election add_ballots', type: :request do
  let(:admin) { create(:user, :admin) }
  before { sign_in admin }

  let(:primary) { Election.create!(state: 'OH', date: Date.new(2026, 5, 5), election_type: 'primary', year: 2026) }

  it 'creates a party ballot per selection, linked to the election, and is idempotent' do
    expect {
      post add_ballots_admin_election_path(primary), params: { parties: ['Democratic', 'Republican'] }
    }.to change(Ballot, :count).by(2)

    ballots = primary.ballots.reload
    expect(ballots.map(&:party)).to contain_exactly('Democratic', 'Republican')
    expect(ballots.map(&:election_id).uniq).to eq([primary.id])

    expect {
      post add_ballots_admin_election_path(primary), params: { parties: ['Democratic', 'Republican'] }
    }.not_to change(Ballot, :count)
  end

  it 'ignores parties outside the vocabulary' do
    expect {
      post add_ballots_admin_election_path(primary), params: { parties: ['Zzz'] }
    }.not_to change(Ballot, :count)
  end

  it 'requires a party selection for a primary' do
    post add_ballots_admin_election_path(primary), params: { parties: [] }
    expect(response).to redirect_to(admin_election_path(primary))
    expect(flash[:alert]).to be_present
  end

  it 'creates a single party-less ballot for a non-primary election' do
    general = Election.create!(state: 'OH', date: Date.new(2026, 11, 3), election_type: 'general', year: 2026)
    expect {
      post add_ballots_admin_election_path(general)
    }.to change(Ballot, :count).by(1)
    expect(general.ballots.reload.first.party).to be_nil
  end
end
