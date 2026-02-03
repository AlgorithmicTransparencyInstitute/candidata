class Admin::DashboardController < ApplicationController
  before_action :authenticate_user!
  
  def index
    @party_count = Party.count
    @person_count = Person.count
    @district_count = District.count
    @office_count = Office.count
    @ballot_count = Ballot.count
    @contest_count = Contest.count
    @candidate_count = Candidate.count
    @officeholder_count = Officeholder.count
    
    @recent_contests = Contest.order(date: :desc).limit(5)
    @current_officeholders = Officeholder.current.includes(:person, :office).limit(10)
  end
end
