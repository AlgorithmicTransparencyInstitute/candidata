# frozen_string_literal: true

class AboutController < ApplicationController
  def index
    @stats = {
      people: Person.count,
      current_officeholders: Officeholder.current.count,
      offices: Office.count,
      bodies: Body.count,
      districts: District.count,
      social_media_accounts: SocialMediaAccount.count,
      parties: Party.count,
      ballots: Ballot.count,
      contests: Contest.count,
      states: State.count,
      federal_offices: Office.federal.count,
      state_offices: Office.state.count,
      local_offices: Office.local.count
    }
  end
end
