class Admin::CandidatesController < Admin::BaseController
  before_action :set_candidate, only: [:show, :edit, :update, :destroy]

  def index
    @candidates = Candidate.includes(:person, :contest, :party).order('contests.date DESC').page(params[:page]).per(50)
  end

  def show
  end

  def edit
  end

  def update
    if @candidate.update(candidate_params)
      redirect_to admin_person_path(@candidate.person), notice: "Candidate updated."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @candidate.destroy
    redirect_to admin_candidates_path, notice: "Candidate deleted."
  end

  private

  def set_candidate
    @candidate = Candidate.find(params[:id])
  end

  def candidate_params
    params.require(:candidate).permit(:person_id, :contest_id, :party_id, :party_at_time,
                                     :incumbent, :outcome, :tally, :vote_percentage,
                                     :advanced_from_primary)
  end
end
