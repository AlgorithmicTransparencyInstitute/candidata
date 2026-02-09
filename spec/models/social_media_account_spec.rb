require 'rails_helper'

RSpec.describe SocialMediaAccount, type: :model do
  describe 'associations' do
    it { is_expected.to belong_to(:person) }
    it { is_expected.to belong_to(:entered_by).class_name('User').optional }
    it { is_expected.to belong_to(:verified_by).class_name('User').optional }
  end

  describe 'validations' do
    it { is_expected.to validate_presence_of(:platform) }

    it 'validates platform inclusion' do
      valid_platforms = %w[Facebook Twitter Instagram YouTube TikTok BlueSky TruthSocial Gettr Rumble Telegram Threads]
      valid_platforms.each do |platform|
        account = build(:social_media_account, platform: platform)
        expect(account).to be_valid, "Expected #{platform} to be valid"
      end
    end

    it 'rejects invalid platforms' do
      account = build(:social_media_account, platform: 'MySpace')
      expect(account).not_to be_valid
      expect(account.errors[:platform]).to be_present
    end

    it 'validates channel_type inclusion' do
      ['Campaign', 'Official Office', 'Personal'].each do |type|
        expect(build(:social_media_account, channel_type: type)).to be_valid
      end
      expect(build(:social_media_account, channel_type: 'Other')).not_to be_valid
    end

    it 'allows blank channel_type' do
      expect(build(:social_media_account, channel_type: nil)).to be_valid
      expect(build(:social_media_account, channel_type: '')).to be_valid
    end

    it 'validates handle uniqueness scoped to person, platform, and channel_type' do
      person = create(:person)
      create(:social_media_account, person: person, platform: 'Twitter', channel_type: 'Campaign', handle: 'unique_handle')
      duplicate = build(:social_media_account, person: person, platform: 'Twitter', channel_type: 'Campaign', handle: 'unique_handle')
      expect(duplicate).not_to be_valid
    end

    it 'allows same handle on different platforms' do
      person = create(:person)
      create(:social_media_account, person: person, platform: 'Twitter', handle: 'handle1')
      account = build(:social_media_account, person: person, platform: 'Facebook', handle: 'handle1')
      expect(account).to be_valid
    end

    it 'validates research_status inclusion' do
      %w[not_started entered not_found verified rejected revised].each do |status|
        expect(build(:social_media_account, research_status: status)).to be_valid
      end
      expect(build(:social_media_account, research_status: 'invalid')).not_to be_valid
    end
  end

  describe 'constants' do
    it 'defines PLATFORMS' do
      expect(SocialMediaAccount::PLATFORMS).to include('Twitter', 'Facebook', 'Instagram', 'YouTube', 'TikTok', 'BlueSky')
    end

    it 'defines CORE_PLATFORMS' do
      expect(SocialMediaAccount::CORE_PLATFORMS).to eq(%w[Facebook Twitter Instagram YouTube TikTok BlueSky])
    end

    it 'defines FRINGE_PLATFORMS' do
      expect(SocialMediaAccount::FRINGE_PLATFORMS).to eq(%w[TruthSocial Gettr Rumble Telegram Threads])
    end

    it 'defines RESEARCH_STATUSES' do
      expect(SocialMediaAccount::RESEARCH_STATUSES).to eq(%w[not_started entered not_found verified rejected revised])
    end
  end

  describe 'scopes' do
    let(:person) { create(:person) }

    describe '.active / .inactive' do
      it 'filters by account_inactive flag' do
        active = create(:social_media_account, person: person, account_inactive: false)
        inactive = create(:social_media_account, person: person, platform: 'Facebook', account_inactive: true)

        expect(SocialMediaAccount.active).to include(active)
        expect(SocialMediaAccount.active).not_to include(inactive)
        expect(SocialMediaAccount.inactive).to include(inactive)
        expect(SocialMediaAccount.inactive).not_to include(active)
      end
    end

    describe '.verified / .unverified' do
      it 'filters by verified flag' do
        verified = create(:social_media_account, person: person, verified: true, handle: 'v1')
        unverified = create(:social_media_account, person: person, verified: false, platform: 'Facebook', handle: 'u1')

        expect(SocialMediaAccount.verified).to include(verified)
        expect(SocialMediaAccount.unverified).to include(unverified)
      end
    end

    describe '.by_platform' do
      it 'filters by platform' do
        twitter = create(:social_media_account, person: person, platform: 'Twitter')
        facebook = create(:social_media_account, person: person, platform: 'Facebook')

        expect(SocialMediaAccount.by_platform('Twitter')).to include(twitter)
        expect(SocialMediaAccount.by_platform('Twitter')).not_to include(facebook)
      end
    end

    describe '.campaign / .official / .personal' do
      it 'filters by channel type' do
        campaign = create(:social_media_account, person: person, channel_type: 'Campaign')
        official = create(:social_media_account, person: person, platform: 'Facebook', channel_type: 'Official Office')
        personal = create(:social_media_account, person: person, platform: 'Instagram', channel_type: 'Personal')

        expect(SocialMediaAccount.campaign).to include(campaign)
        expect(SocialMediaAccount.official).to include(official)
        expect(SocialMediaAccount.personal).to include(personal)
      end
    end

    describe '.pre_populated' do
      it 'returns pre-populated accounts' do
        prepop = create(:social_media_account, :pre_populated, person: person)
        normal = create(:social_media_account, person: person, platform: 'Facebook', pre_populated: false)

        expect(SocialMediaAccount.pre_populated).to include(prepop)
        expect(SocialMediaAccount.pre_populated).not_to include(normal)
      end
    end

    describe '.needs_research' do
      it 'returns pre-populated accounts with not_started status' do
        needs = create(:social_media_account, person: person, pre_populated: true, research_status: 'not_started')
        done = create(:social_media_account, person: person, platform: 'Facebook', pre_populated: true, research_status: 'entered', handle: 'h1')

        expect(SocialMediaAccount.needs_research).to include(needs)
        expect(SocialMediaAccount.needs_research).not_to include(done)
      end
    end

    describe '.needs_verification' do
      it 'returns accounts needing verification' do
        entered = create(:social_media_account, person: person, research_status: 'entered', handle: 'h1')
        not_found = create(:social_media_account, person: person, platform: 'Facebook', research_status: 'not_found')
        verified = create(:social_media_account, person: person, platform: 'Instagram', research_status: 'verified', handle: 'h2')

        expect(SocialMediaAccount.needs_verification).to include(entered, not_found)
        expect(SocialMediaAccount.needs_verification).not_to include(verified)
      end
    end

    describe '.core_platforms / .fringe_platforms' do
      it 'filters by platform category' do
        core = create(:social_media_account, person: person, platform: 'Twitter')
        fringe = create(:social_media_account, person: person, platform: 'TruthSocial')

        expect(SocialMediaAccount.core_platforms).to include(core)
        expect(SocialMediaAccount.fringe_platforms).to include(fringe)
      end
    end
  end

  describe '#active?' do
    it 'returns true when not inactive' do
      account = build(:social_media_account, account_inactive: false)
      expect(account.active?).to be true
    end

    it 'returns false when inactive' do
      account = build(:social_media_account, account_inactive: true)
      expect(account.active?).to be false
    end
  end

  describe '#display_name' do
    it 'returns @handle when handle is present' do
      account = build(:social_media_account, handle: 'testuser')
      expect(account.display_name).to eq('@testuser')
    end

    it 'returns url when handle is blank' do
      account = build(:social_media_account, handle: nil, url: 'https://twitter.com/test')
      expect(account.display_name).to eq('https://twitter.com/test')
    end
  end

  describe '#mark_entered!' do
    it 'transitions to entered status' do
      person = create(:person)
      account = create(:social_media_account, person: person)
      user = create(:user)

      account.mark_entered!(user, url: 'https://twitter.com/handle', handle: 'handle')

      expect(account.research_status).to eq('entered')
      expect(account.entered_by).to eq(user)
      expect(account.entered_at).to be_present
      expect(account.url).to eq('https://twitter.com/handle')
      expect(account.handle).to eq('handle')
    end
  end

  describe '#mark_not_found!' do
    it 'transitions to not_found status' do
      person = create(:person)
      account = create(:social_media_account, person: person)
      user = create(:user)

      account.mark_not_found!(user)

      expect(account.research_status).to eq('not_found')
      expect(account.entered_by).to eq(user)
      expect(account.entered_at).to be_present
    end
  end

  describe '#reset_status!' do
    it 'resets to not_started and clears data' do
      person = create(:person)
      account = create(:social_media_account, :entered, person: person)
      user = create(:user)

      account.reset_status!(user)

      expect(account.research_status).to eq('not_started')
      expect(account.url).to be_nil
      expect(account.handle).to be_nil
    end
  end

  describe '#verify!' do
    it 'transitions to verified status' do
      person = create(:person)
      account = create(:social_media_account, person: person, research_status: 'entered', handle: 'h1')
      user = create(:user)

      account.verify!(user, notes: 'Looks good')

      expect(account.research_status).to eq('verified')
      expect(account.verified).to be true
      expect(account.verified_by).to eq(user)
      expect(account.verified_at).to be_present
      expect(account.verification_notes).to eq('Looks good')
    end
  end

  describe '#reject!' do
    it 'transitions to rejected status' do
      person = create(:person)
      account = create(:social_media_account, person: person, research_status: 'entered', handle: 'h1')
      user = create(:user)

      account.reject!(user, notes: 'Wrong account')

      expect(account.research_status).to eq('rejected')
      expect(account.verified_by).to eq(user)
      expect(account.verification_notes).to eq('Wrong account')
    end
  end

  describe '#revise!' do
    it 'transitions to revised status and unverifies' do
      person = create(:person)
      account = create(:social_media_account, :verified, person: person)
      user = create(:user)

      account.revise!(user, handle: 'new_handle', notes: 'Fixed handle')

      expect(account.research_status).to eq('revised')
      expect(account.verified).to be false
      expect(account.handle).to eq('new_handle')
      expect(account.verification_notes).to eq('Fixed handle')
    end

    it 'preserves existing url when not provided' do
      person = create(:person)
      account = create(:social_media_account, person: person, url: 'https://original.com', handle: 'orig')
      user = create(:user)

      account.revise!(user, notes: 'Minor fix')

      expect(account.url).to eq('https://original.com')
    end
  end

  describe '#needs_verification?' do
    it 'returns true for entered, not_found, and revised statuses' do
      %w[entered not_found revised].each do |status|
        account = build(:social_media_account, research_status: status)
        expect(account.needs_verification?).to eq(true)
      end
    end

    it 'returns false for other statuses' do
      %w[not_started verified rejected].each do |status|
        account = build(:social_media_account, research_status: status)
        expect(account.needs_verification?).to eq(false)
      end
    end
  end

  describe '.prepopulate_for_person!' do
    it 'creates accounts for core platforms' do
      person = create(:person)

      expect {
        SocialMediaAccount.prepopulate_for_person!(person)
      }.to change { person.social_media_accounts.count }.by(6)

      SocialMediaAccount::CORE_PLATFORMS.each do |platform|
        account = person.social_media_accounts.find_by(platform: platform, channel_type: 'Campaign')
        expect(account).to be_present
        expect(account.pre_populated).to be true
        expect(account.research_status).to eq('not_started')
      end
    end

    it 'skips platforms that already exist' do
      person = create(:person)
      create(:social_media_account, person: person, platform: 'Twitter', channel_type: 'Campaign')

      expect {
        SocialMediaAccount.prepopulate_for_person!(person)
      }.to change { person.social_media_accounts.count }.by(5)
    end

    it 'accepts custom platforms list' do
      person = create(:person)

      expect {
        SocialMediaAccount.prepopulate_for_person!(person, platforms: %w[Twitter Facebook])
      }.to change { person.social_media_accounts.count }.by(2)
    end

    it 'accepts custom channel_type' do
      person = create(:person)

      SocialMediaAccount.prepopulate_for_person!(person, channel_type: 'Official Office')

      person.social_media_accounts.each do |account|
        expect(account.channel_type).to eq('Official Office')
      end
    end
  end

  describe 'PaperTrail', versioning: true do
    it 'tracks changes' do
      person = create(:person)
      account = create(:social_media_account, person: person)
      account.update!(handle: 'new_handle')

      expect(account.versions.count).to eq(2)
    end

    describe '#has_revisions?' do
      it 'returns true when multiple versions exist' do
        person = create(:person)
        account = create(:social_media_account, person: person)
        account.update!(handle: 'updated')

        expect(account.has_revisions?).to be true
      end

      it 'returns false for new records' do
        person = create(:person)
        account = create(:social_media_account, person: person)

        expect(account.has_revisions?).to be false
      end
    end
  end
end
