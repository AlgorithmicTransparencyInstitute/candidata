# frozen_string_literal: true

class HelpController < ApplicationController
  def index
  end

  def data_sources
  end

  def data_model
  end

  def coverage
    @stats = {
      people: Person.count,
      offices: Office.count,
      officeholders: Officeholder.count,
      parties: Party.count,
      districts: District.count,
      states: 56
    }
  end

  def researcher_guide
    # Public-facing researcher guide page
  end
end
