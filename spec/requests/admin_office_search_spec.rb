require 'rails_helper'

# Pins the searchable office picker backend (/admin/offices/search) used by the
# core contest form. Whole-table search, optional state narrowing, rich labels.
RSpec.describe 'Admin office search', type: :request do
  let(:admin) { create(:user, :admin) }
  before { sign_in admin }

  let!(:co_office) do
    Office.create!(title: 'State Representative', level: 'state', branch: 'legislative',
                   state: 'CO', seat: 'District 5', body_name: 'CO State House')
  end
  let!(:ny_office) do
    Office.create!(title: 'State Representative', level: 'state', branch: 'legislative',
                   state: 'NY', seat: 'District 5', body_name: 'NY State Assembly')
  end

  def search(params)
    get search_admin_offices_path, params: params
    expect(response).to have_http_status(:ok)
    JSON.parse(response.body)['offices']
  end

  it 'searches across all states and labels results with state context' do
    offices = search(q: 'Representative')
    ids = offices.map { |o| o['id'] }
    expect(ids).to include(co_office.id, ny_office.id)
    co = offices.find { |o| o['id'] == co_office.id }
    expect(co['label']).to include('CO')
    expect(co['state']).to eq('CO')
  end

  it 'narrows by state when asked' do
    offices = search(q: 'Representative', state: 'CO')
    expect(offices.map { |o| o['id'] }).to contain_exactly(co_office.id)
  end

  it 'returns nothing for queries under two characters' do
    expect(search(q: 'R')).to eq([])
  end
end
