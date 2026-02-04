class HomeController < ApplicationController
  def index
    @people_count = Person.count
    @offices_count = Office.count
    @bodies_count = Office.where.not(body_name: [nil, '']).distinct.count(:body_name)
    @parties_count = Party.count
    @states_count = State.count
    @districts_count = District.count
    @current_officeholders_count = Person.current_officeholders.count
  end
end
