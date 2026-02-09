require 'rails_helper'

RSpec.describe Assignment, type: :model do
  describe 'associations' do
    it { is_expected.to belong_to(:user) }
    it { is_expected.to belong_to(:assigned_by).class_name('User') }
    it { is_expected.to belong_to(:person) }
  end

  describe 'validations' do
    it { is_expected.to validate_presence_of(:task_type) }
    it { is_expected.to validate_inclusion_of(:task_type).in_array(%w[data_collection data_validation]) }
    it { is_expected.to validate_presence_of(:status) }
    it { is_expected.to validate_inclusion_of(:status).in_array(%w[pending in_progress completed]) }

    it 'validates uniqueness of user_id scoped to person_id and task_type' do
      user = create(:user)
      person = create(:person)
      admin = create(:user, :admin)
      create(:assignment, user: user, person: person, assigned_by: admin, task_type: 'data_collection')

      duplicate = build(:assignment, user: user, person: person, assigned_by: admin, task_type: 'data_collection')
      expect(duplicate).not_to be_valid
      expect(duplicate.errors[:user_id]).to be_present
    end

    it 'allows same user with different task_type for same person' do
      user = create(:user)
      person = create(:person)
      admin = create(:user, :admin)
      create(:assignment, user: user, person: person, assigned_by: admin, task_type: 'data_collection')

      different_type = build(:assignment, user: user, person: person, assigned_by: admin, task_type: 'data_validation')
      expect(different_type).to be_valid
    end
  end

  describe 'constants' do
    it 'defines TASK_TYPES' do
      expect(Assignment::TASK_TYPES).to eq(%w[data_collection data_validation])
    end

    it 'defines STATUSES' do
      expect(Assignment::STATUSES).to eq(%w[pending in_progress completed])
    end
  end

  describe 'scopes' do
    let(:user) { create(:user) }
    let(:admin) { create(:user, :admin) }

    describe '.pending / .in_progress / .completed' do
      it 'filters by status' do
        pending = create(:assignment, user: user, assigned_by: admin, status: 'pending')
        in_prog = create(:assignment, user: user, person: create(:person), assigned_by: admin, status: 'in_progress')
        done = create(:assignment, user: user, person: create(:person), assigned_by: admin, status: 'completed')

        expect(Assignment.pending).to include(pending)
        expect(Assignment.in_progress).to include(in_prog)
        expect(Assignment.completed).to include(done)
      end
    end

    describe '.data_collection / .data_validation' do
      it 'filters by task type' do
        collection = create(:assignment, user: user, assigned_by: admin, task_type: 'data_collection')
        validation = create(:assignment, user: user, person: create(:person), assigned_by: admin, task_type: 'data_validation')

        expect(Assignment.data_collection).to include(collection)
        expect(Assignment.data_validation).to include(validation)
      end
    end

    describe '.for_user' do
      it 'filters by user' do
        other_user = create(:user)
        mine = create(:assignment, user: user, assigned_by: admin)
        theirs = create(:assignment, user: other_user, assigned_by: admin)

        expect(Assignment.for_user(user)).to include(mine)
        expect(Assignment.for_user(user)).not_to include(theirs)
      end
    end

    describe '.active' do
      it 'returns pending and in_progress assignments' do
        pending = create(:assignment, user: user, assigned_by: admin, status: 'pending')
        in_prog = create(:assignment, user: user, person: create(:person), assigned_by: admin, status: 'in_progress')
        done = create(:assignment, user: user, person: create(:person), assigned_by: admin, status: 'completed')

        expect(Assignment.active).to include(pending, in_prog)
        expect(Assignment.active).not_to include(done)
      end
    end
  end

  describe '#start!' do
    it 'transitions to in_progress' do
      assignment = create(:assignment, status: 'pending')
      assignment.start!

      expect(assignment.status).to eq('in_progress')
    end
  end

  describe '#complete!' do
    it 'transitions to completed and sets completed_at' do
      assignment = create(:assignment, status: 'in_progress')
      assignment.complete!

      expect(assignment.status).to eq('completed')
      expect(assignment.completed_at).to be_present
    end
  end

  describe '#reopen!' do
    it 'transitions back to in_progress and clears completed_at' do
      assignment = create(:assignment, :completed)
      assignment.reopen!

      expect(assignment.status).to eq('in_progress')
      expect(assignment.completed_at).to be_nil
    end
  end

  describe '#has_validation_assignment?' do
    it 'returns true when an active validation assignment exists for the person' do
      user = create(:user)
      admin = create(:user, :admin)
      person = create(:person)
      collection = create(:assignment, user: user, person: person, assigned_by: admin, task_type: 'data_collection')
      create(:assignment, user: create(:user), person: person, assigned_by: admin, task_type: 'data_validation', status: 'pending')

      expect(collection.has_validation_assignment?).to be true
    end

    it 'returns false when no active validation assignment exists' do
      assignment = create(:assignment, task_type: 'data_collection')
      expect(assignment.has_validation_assignment?).to be false
    end
  end

  describe 'status query methods' do
    it '#pending? returns true when pending' do
      expect(build(:assignment, status: 'pending').pending?).to be true
      expect(build(:assignment, status: 'in_progress').pending?).to be false
    end

    it '#in_progress? returns true when in_progress' do
      expect(build(:assignment, status: 'in_progress').in_progress?).to be true
      expect(build(:assignment, status: 'pending').in_progress?).to be false
    end

    it '#completed? returns true when completed' do
      expect(build(:assignment, status: 'completed').completed?).to be true
      expect(build(:assignment, status: 'pending').completed?).to be false
    end
  end

  describe 'PaperTrail', versioning: true do
    it 'tracks changes' do
      assignment = create(:assignment)
      assignment.update!(status: 'in_progress')

      expect(assignment.versions.count).to eq(2)
    end
  end
end
