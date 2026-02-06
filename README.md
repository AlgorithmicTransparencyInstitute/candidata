# Candidata

A Ruby on Rails 8 application that integrates with Airtable for user authentication and dynamic form management.

## Overview

This application allows users to:
- **Login** using email/password credentials stored in an Airtable base
- **View assigned records** fetched from Airtable based on the logged-in user's email
- **Submit form data** that gets pushed back to Airtable via API

## Tech Stack

- **Ruby on Rails 8**
- **PostgreSQL** - Database
- **Tailwind CSS** - Styling
- **Airtable API** - External data source for authentication and records

## Setup

### Prerequisites
- Ruby 3.1+
- PostgreSQL
- Airtable account with API access

### Installation

```bash
# Install dependencies
bundle install

# Create database
bin/rails db:create db:migrate

# Start the development server
bin/dev
```

### Environment Variables

You'll need to configure the following environment variables for Airtable integration:

```
AIRTABLE_API_KEY=your_api_key
AIRTABLE_BASE_ID=your_base_id
AIRTABLE_USERS_TABLE=Users
AIRTABLE_RECORDS_TABLE=Records
```

### Airtable Data Import

To import existing candidate data from Airtable:

```bash
# Set environment variables
export AIRTABLE_API_KEY='your_api_key'
export AIRTABLE_BASE_ID='your_base_id'

# Test connection
bin/rails import:test_airtable

# List available tables
bin/rails import:list_tables

# Import all data
bin/rails import:airtable
```

The import service will:
1. Import political parties
2. Import people/candidates
3. Import districts and offices
4. Import ballots and contests
5. Import candidate relationships
6. Import officeholder records

## Documentation

- [2026 Candidate Management Plan](docs/2026_CANDIDATE_MANAGEMENT_PLAN.md) - Implementation plan for admin/researcher workflow
- [Temp Data Analysis Report](docs/TEMP_DATA_ANALYSIS.md) - Analysis of staging tables with 2024 election data
- [Rails 8 Upgrade](docs/RAILS_8_UPGRADE.md) - Rails 7.2 → 8.0 upgrade process and compatibility changes

## Development

```bash
# Run the server with Tailwind CSS watching
bin/dev
```

## Project Structure

- `app/controllers/home_controller.rb` - Handles login and main page
- `app/controllers/sessions_controller.rb` - Session management (to be added)
- `app/services/airtable_service.rb` - Airtable API integration (to be added)

## Deployment

### Heroku

```bash
# Create Heroku app
heroku create candidata

# Add PostgreSQL
heroku addons:create heroku-postgresql:essential-0

# Set environment variables
heroku config:set AIRTABLE_API_KEY=your_api_key
heroku config:set AIRTABLE_BASE_ID=your_base_id

# Deploy
git push heroku main

# Run migrations
heroku run rails db:migrate
```

### Custom Domain

```bash
# Add domain to Heroku
heroku domains:add your-domain.com

# Configure DNS with your registrar:
# CNAME record pointing to your-app.herokuapp.com
```
