class ElectionsController < ApplicationController
  def index
    @upcoming_elections = Election.where('date >= ?', Date.current)
                                   .order(:date)
                                   .includes(:ballots)
                                   .limit(50)

    @past_elections = Election.where('date < ?', Date.current)
                               .order(date: :desc)
                               .includes(:ballots)
                               .limit(20)
  end

  def show
    @election = Election.includes(ballots: { contests: { candidates: :person, office: :district } })
                        .find(params[:id])

    # Group contests by ballot/party for better organization
    @ballots_with_contests = @election.ballots.map do |ballot|
      {
        ballot: ballot,
        contests: ballot.contests.includes(office: :district, candidates: :person).order('offices.title')
      }
    end
  end
end
