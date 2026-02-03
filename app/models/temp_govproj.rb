# frozen_string_literal: true

# Temporary staging table for govproj CSV data
# Used to analyze and transform data before importing into core tables
class TempGovproj < ApplicationRecord
  self.table_name = 'temp_govproj'
end
