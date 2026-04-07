# Junkipedia Integration

## Purpose

Candidata maintains a comprehensive database of social media accounts for US elected officials, candidates, and political figures across 11 platforms (Facebook, Twitter, Instagram, YouTube, TikTok, BlueSky, TruthSocial, Gettr, Rumble, Telegram, Threads). [Junkipedia](https://www.junkipedia.org) is a social listening platform that collects and archives posts from public social media accounts for research purposes.

This integration pushes social media accounts from Candidata into Junkipedia as monitored channels, organized into per-state multi-platform lists. This ensures that posts from elected officials and candidates are being collected and available for research analysis.

## How It Works

1. **Create a Junkipedia list** — One multi-platform list per state (e.g., "Candidata - Texas Officials")
2. **Push accounts** — Each active social media account with a URL is added to the list via the Junkipedia API's `add_component` endpoint
3. **Junkipedia begins collection** — Once added, Junkipedia starts collecting posts from those accounts on its regular schedule

### Platform Mapping

| Candidata | Junkipedia |
|-----------|------------|
| Facebook | Facebook |
| Twitter | Twitter |
| Instagram | Instagram |
| YouTube | YouTube |
| TikTok | TikTok |
| BlueSky | Bluesky |
| TruthSocial | TruthSocial |
| Gettr | GETTR |
| Rumble | Rumble |
| Telegram | Telegram |
| Threads | Threads |

## Configuration

Set the API token in your environment:

```bash
# Local development (.env file, gitignored)
JUNKIPEDIA_API_TOKEN=your_token_here

# Heroku production
heroku config:set JUNKIPEDIA_API_TOKEN=your_token_here --app candidata
```

API tokens are generated in Junkipedia under User Account > Manage API Keys.

## Rake Tasks

### Preview

```bash
# Show all pushable accounts by platform
bin/rails junkipedia:preview

# Filter to a specific state
STATE=TX bin/rails junkipedia:preview
```

### Push a Single State

Creates a new Junkipedia list and pushes all active accounts for that state:

```bash
bin/rails 'junkipedia:push_state[TX]'

# Dry run (no API calls)
DRY_RUN=1 bin/rails 'junkipedia:push_state[TX]'

# Resume into an existing list instead of creating a new one
LIST_ID=10591 bin/rails 'junkipedia:push_state[TX]'
```

### Push All States

```bash
# Preview what would be pushed
DRY_RUN=1 bin/rails junkipedia:push_all_states

# Actually push (requires confirmation)
CONFIRM=1 bin/rails junkipedia:push_all_states
```

### List Management

```bash
# List all Junkipedia lists visible to your account
bin/rails junkipedia:lists

# Show channels in a specific list
bin/rails 'junkipedia:list_channels[10591]'
```

### Push by Platform

```bash
# Push only Twitter accounts to a specific list
bin/rails 'junkipedia:push_platform[10591,Twitter]'
```

## Key Files

- `app/services/junkipedia_service.rb` — API client with retry logic for the Junkipedia v2 API
- `lib/tasks/junkipedia.rake` — Rake tasks for pushing accounts

## Current Status

### Completed Pushes

| State | List ID | Channels Added | Date |
|-------|---------|---------------|------|
| Texas (TX) | 10591 | ~2,328 | 2026-03-13 |
| Illinois (IL) | 10599 | ~1,326 (partial) | 2026-03-17 |

### Remaining States (from target batch)

IN, OH, KY, WV, MD, NC, AL, MS, AR, LA, NM — not yet started.

### Account Totals by State

As of the last production database pull (March 2026), 41,016 active accounts with URLs across 56 states/territories. Top states:

| State | Accounts | State | Accounts |
|-------|----------|-------|----------|
| TX | 2,971 | MO | 892 |
| CA | 1,878 | AL | 884 |
| IL | 1,785 | MN | 877 |
| NY | 1,730 | WI | 868 |
| GA | 1,642 | VA | 828 |
| NC | 1,540 | IN | 824 |
| FL | 1,528 | MA | 791 |
| PA | 1,410 | KS | 731 |
| KY | 1,079 | CO | 694 |
| OH | 1,077 | IA | 688 |
| MI | 1,055 | NH | 687 |
| TN | 1,016 | CT | 677 |
| MD | 969 | AR | 655 |
| LA | 920 | MS | 644 |
| SC | 918 | OK | 610 |

## Known Issues

- **Junkipedia 500 errors** — Some accounts return HTTP 500 from Junkipedia's side. These are typically Facebook share links, personal profiles (e.g., `/dan.mims.1`), deleted accounts, or accounts Junkipedia can't resolve. Roughly 18% failure rate observed on the Texas push.
- **Dirty Twitter handles** — Some handles in Candidata contain URL query parameters (e.g., `?lang=en`, `?ref_src=...`) or are not real handles (e.g., `highlights`). These should be cleaned up in Candidata's data.
- **Rate limiting** — A 0.2s delay between API calls is used to avoid overwhelming Junkipedia. A full state like Texas (~3,000 accounts) takes about 10 minutes.
- **Network timeouts** — The service includes retry logic (3 retries with exponential backoff) for transient network errors, but long machine sleep during a push can cause the process to stall.
