class BallotsController < ApplicationController
  def index
    @ballots = Ballot.includes(:contests).order(date: :desc, state: :asc, party: :asc)

    if params[:year].present?
      @ballots = @ballots.where(year: params[:year])
    end

    if params[:state].present?
      @ballots = @ballots.where(state: params[:state])
    end

    if params[:party].present?
      @ballots = @ballots.where(party: params[:party])
    end

    @ballots = @ballots.page(params[:page]).per(50)

    @years = Ballot.where.not(year: nil).distinct.pluck(:year).sort.reverse
    @states = Ballot.where.not(state: nil).distinct.pluck(:state).sort
    @parties = Ballot.where.not(party: nil).distinct.pluck(:party).sort
  end

  def show
    @ballot = Ballot.includes(contests: :office).find(params[:id])
    @contests = @ballot.contests.includes(:office, :candidates).order(Arel.sql('offices.title'))
  end
end
