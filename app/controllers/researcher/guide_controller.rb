module Researcher
  class GuideController < ApplicationController
    # No authentication required - guide is publicly accessible
    layout 'researcher'

    def show
      # Render the researcher user guide
    end
  end
end
