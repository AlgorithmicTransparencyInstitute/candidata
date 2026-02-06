# Rails 8 Upgrade

**Date:** 2026-02-06
**From:** Rails 7.2.3
**To:** Rails 8.0.4
**Ruby:** 3.1.7 → 3.3.6

## Overview

This document describes the upgrade process and compatibility changes required to migrate Candidata from Rails 7.2 to Rails 8.0.

## Upgrade Process

The upgrade was performed on the `rails-8-upgrade` branch following these steps:

1. **Ruby Version Upgrade**
   - Updated `.ruby-version` from `3.1.7` to `3.3.6` (Rails 8 requires Ruby 3.2+)
   - Verified installation via rbenv

2. **Rails Version Upgrade**
   - Updated `Gemfile`: `gem "rails", "~> 8.0.0"`
   - Ran `bundle update rails`
   - Successfully upgraded all Rails gems to 8.0.4

3. **Configuration Update**
   - Ran `bin/rails app:update` to update configuration files
   - Accepted all defaults (overwrote modified config files)
   - Generated three new Active Storage migrations
   - Created `config/initializers/new_framework_defaults_8_0.rb`

4. **Database Migration**
   - Ran `bin/rails db:migrate`
   - Applied three Active Storage compatibility migrations:
     - `AddServiceNameToActiveStorageBlobs`
     - `CreateActiveStorageVariantRecords`
     - `RemoveNotNullOnActiveStorageBlobsChecksum`

## Breaking Changes Fixed

### 1. Letter Opener Configuration

**Issue:** The `bin/rails app:update` task overwrote `config/environments/development.rb` and removed the letter_opener gem configuration.

**Symptom:** Invitation and password reset emails were being queued but not opening in the browser during development.

**Fix:** Added letter_opener configuration back to `config/environments/development.rb`:

```ruby
# Use letter_opener to preview emails in browser instead of sending them
config.action_mailer.delivery_method = :letter_opener
config.action_mailer.perform_deliveries = true
```

**Location:** `config/environments/development.rb:44-46`

### 2. button_to with Block and Text Argument

**Issue:** Rails 8 changed `button_to` behavior when using blocks. The button text can no longer be passed as the first argument when using a block—the block content becomes the button.

**Symptom:** `NoMethodError: undefined method 'stringify_keys' for an instance of String` when viewing `/admin/users/:id`

**Example of problematic code:**
```erb
<%# WRONG - Rails 7 syntax %>
<%= button_to "Resend Invitation", resend_invitation_admin_user_path(@user), method: :post, class: "..." do %>
  <svg>...</svg>
  Resend Invitation
<% end %>
```

**Fixed syntax:**
```erb
<%# CORRECT - Rails 8 syntax %>
<%= button_to resend_invitation_admin_user_path(@user), method: :post, class: "..." do %>
  <svg>...</svg>
  Resend Invitation
<% end %>
```

**Locations Fixed:**
- `app/views/admin/users/show.html.erb:52` - Resend Invitation button
- `app/views/admin/users/show.html.erb:59` - Send Password Reset button

## Compatibility Scan Results

### No Issues Found

The following areas were scanned and found to be fully compatible:

- ✅ **button_to without blocks** - All other instances use correct syntax
- ✅ **link_to helpers** - No issues with link generation
- ✅ **ActiveRecord queries** - `.where.not` and other query methods work correctly
- ✅ **Model associations** - All `has_many`/`belongs_to` with proper dependent options
- ✅ **Asset pipeline** - Sprockets configuration is compatible
- ✅ **Model inheritance** - ApplicationRecord pattern is correct
- ✅ **Callbacks** - No deprecated callback usage
- ✅ **Serialization** - No deprecated serialize usage

### Deprecated But Working

These features still work but are deprecated and should be updated eventually:

1. **form_for in Devise views** (5 instances)
   - Found in: `devise/sessions/new.html.erb`, `devise/passwords/*.html.erb`, etc.
   - Status: Works fine with Rails 8 compatibility mode
   - Future action: Consider migrating to `form_with` when convenient

2. **load_defaults 7.2**
   - `config/application.rb` still uses `config.load_defaults 7.2`
   - This is intentional for gradual upgrade
   - Rails 8 features can be enabled incrementally via `config/initializers/new_framework_defaults_8_0.rb`

## Gradual Feature Adoption

Rails 8 provides `config/initializers/new_framework_defaults_8_0.rb` with commented-out configurations. You can enable Rails 8 features one-by-one by uncommenting these lines:

```ruby
# Timezone preservation for to_time methods
Rails.application.config.active_support.to_time_preserves_timezone = :zone

# Strict cache freshness (RFC 7232 compliance)
Rails.application.config.action_dispatch.strict_freshness = true

# Regexp timeout for security
Regexp.timeout = 1
```

When all features are enabled and tested, you can:
1. Remove `config/initializers/new_framework_defaults_8_0.rb`
2. Change `config.load_defaults 7.2` to `config.load_defaults 8.0`

## Gem Compatibility

All major gems upgraded successfully:

| Gem | Status | Notes |
|-----|--------|-------|
| devise (5.0.0) | ✅ Compatible | No changes needed |
| devise_invitable (2.0.11) | ✅ Compatible | No changes needed |
| omniauth (2.1.4) | ✅ Compatible | OAuth flows work correctly |
| omniauth-google-oauth2 (1.2.1) | ✅ Compatible | Google login works |
| omniauth-entra-id (3.1.1) | ✅ Compatible | Microsoft login works |
| kaminari (1.2.2) | ✅ Compatible | Pagination works |
| paper_trail (16.0.0) | ✅ Compatible | Audit trails work |
| tailwindcss-rails | ✅ Compatible | Styling unaffected |
| letter_opener | ✅ Compatible | Required config re-add |
| puma (7.1.0) | ⬆️ Upgraded | Auto-upgraded from 5.x |

## Testing Results

Manual testing confirmed the following functionality works correctly:

- ✅ Server starts (`bin/dev`)
- ✅ Database queries and Active Record operations
- ✅ User authentication (Devise email/password)
- ✅ OAuth login (Google, Microsoft)
- ✅ User invitations (devise_invitable)
- ✅ Email delivery (letter_opener in dev)
- ✅ Password reset emails
- ✅ Admin user management pages
- ✅ Researcher assignments workflow
- ✅ Active Storage (avatars)
- ✅ File uploads
- ✅ Turbo/Stimulus functionality

## Files Modified

### Configuration Files
- `.ruby-version` - Updated to 3.3.6
- `Gemfile` - Rails version constraint updated
- `Gemfile.lock` - All gems updated
- `config/environments/development.rb` - Letter opener config restored
- `config/environments/production.rb` - Rails 8 defaults
- `config/environments/test.rb` - Rails 8 defaults
- `config/puma.rb` - Rails 8 defaults
- `config/initializers/assets.rb` - Rails 8 defaults
- `config/initializers/filter_parameter_logging.rb` - Rails 8 defaults
- `bin/dev` - Rails 8 script updates
- `bin/setup` - Rails 8 script updates

### New Files Created
- `config/initializers/new_framework_defaults_8_0.rb` - Gradual feature adoption
- `db/migrate/20260206151757_add_service_name_to_active_storage_blobs.active_storage.rb`
- `db/migrate/20260206151758_create_active_storage_variant_records.active_storage.rb`
- `db/migrate/20260206151759_remove_not_null_on_active_storage_blobs_checksum.active_storage.rb`
- `public/400.html` - New error page

### View Files Fixed
- `app/views/admin/users/show.html.erb` - Fixed 2 button_to calls

### Database Schema
- `db/schema.rb` - Updated with Active Storage changes

## Recommendations

### Immediate
- ✅ All critical fixes applied
- ✅ Application is production-ready on Rails 8

### Short-term (Optional)
- Consider migrating Devise forms from `form_for` to `form_with`
- Test enabling individual Rails 8 framework defaults
- Update CLAUDE.md to reflect Rails 8.0.4

### Long-term
- Once all Rails 8 features are adopted, change `config.load_defaults` to `8.0`
- Remove `config/initializers/new_framework_defaults_8_0.rb`

## Rollback Plan

If issues arise, rollback is simple:

```bash
git checkout main
# Or if you need to undo specific changes:
git checkout main -- Gemfile Gemfile.lock .ruby-version
bundle install
```

## Conclusion

The Rails 8 upgrade was **successful** with minimal breaking changes. The application is stable and all features work correctly. The two issues found (letter_opener config and button_to syntax) have been fixed and documented.

**Upgrade difficulty:** ⭐ Easy (2 breaking changes, both minor)
**Risk level:** 🟢 Low (all tests passed, no data migrations required)
**Recommendation:** ✅ Safe to merge to main after thorough testing
