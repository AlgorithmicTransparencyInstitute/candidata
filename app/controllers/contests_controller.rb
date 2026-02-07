class ContestsController < ApplicationController
  def index
    @contests = Contest.includes(:office, :ballot, :candidates).order(date: :desc)

    if params[:year].present?
      year = params[:year].to_i
      @contests = @contests.joins(:ballot).where(ballots: { year: year })
    end

    if params[:state].present?
      @contests = @contests.joins(:ballot).where(ballots: { state: params[:state] })
    end

    if params[:party].present?
      @contests = @contests.where(party: params[:party])
    end

    if params[:contest_type].present?
      @contests = @contests.where(contest_type: params[:contest_type])
    end

    @contests = @contests.page(params[:page]).per(50)

    @years = Ballot.where.not(year: nil).distinct.pluck(:year).sort.reverse
    @states = Ballot.where.not(state: nil).distinct.pluck(:state).sort
    @parties = Contest.where.not(party: nil).distinct.pluck(:party).sort
    @contest_types = Contest::CONTEST_TYPES
  end

  def show
    @contest = Contest.includes(:office, :ballot, candidates: :person).find(params[:id])
    @candidates = @contest.candidates.includes(:person).order(tally: :desc, created_at: :asc)
  end
end
