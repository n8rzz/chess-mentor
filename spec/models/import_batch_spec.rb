# frozen_string_literal: true

# == Schema Information
#
# Table name: import_batches
#
#  id                   :string           not null, primary key
#  error_details        :jsonb
#  error_message        :text
#  finished_at          :datetime
#  games_failed_count   :integer          default(0), not null
#  games_found_count    :integer          default(0), not null
#  games_imported_count :integer          default(0), not null
#  games_skipped_count  :integer          default(0), not null
#  max_games            :integer          not null
#  metadata             :jsonb            not null
#  provider             :integer          not null
#  requested_since      :datetime         not null
#  requested_until      :datetime         not null
#  started_at           :datetime
#  status               :integer          default("pending"), not null
#  time_controls        :jsonb            not null
#  created_at           :datetime         not null
#  updated_at           :datetime         not null
#  provider_account_id  :string           not null
#  user_id              :string           not null
#
# Indexes
#
#  index_import_batches_on_provider_account_id     (provider_account_id)
#  index_import_batches_on_user_id                 (user_id)
#  index_import_batches_on_user_id_and_created_at  (user_id,created_at)
#  index_import_batches_on_user_id_and_status      (user_id,status)
#
# Foreign Keys
#
#  fk_rails_...  (provider_account_id => provider_accounts.id) ON DELETE => cascade
#  fk_rails_...  (user_id => users.id) ON DELETE => cascade
#
require "rails_helper"

RSpec.describe ImportBatch, type: :model do
  subject(:import_batch) { build(:import_batch) }

  describe "associations" do
    it { is_expected.to belong_to(:user) }
    it { is_expected.to belong_to(:provider_account) }
    it { is_expected.to have_many(:import_records).dependent(:destroy) }
    it { is_expected.to have_many(:games).dependent(:destroy) }
  end

  describe "enums" do
    it do
      expect(import_batch).to define_enum_for(:status)
        .with_values(
          pending: 0,
          running: 1,
          succeeded: 2,
          partially_succeeded: 3,
          failed: 4,
          cancelled: 5
        )
        .backed_by_column_of_type(:integer)
        .with_default(:pending)
    end

    it do
      expect(import_batch).to define_enum_for(:provider)
        .with_values(lichess: 0, chess_com: 1)
        .backed_by_column_of_type(:integer)
    end
  end

  describe "validations" do
    it { is_expected.to validate_presence_of(:requested_since) }
    it { is_expected.to validate_presence_of(:requested_until) }
    it { is_expected.to validate_presence_of(:max_games) }
    it { is_expected.to validate_numericality_of(:max_games).is_greater_than(0).is_less_than_or_equal_to(30) }

    it "requires time_controls to be an array" do
      import_batch.time_controls = "blitz"

      expect(import_batch).not_to be_valid
      expect(import_batch.errors[:time_controls]).to include("must be an array")
    end
  end

  describe "scopes" do
    it "in_progress includes pending and running" do
      pending = create(:import_batch)
      running = create(:import_batch, :running)
      create(:import_batch, :succeeded)

      expect(described_class.in_progress).to contain_exactly(pending, running)
    end

    it "terminal includes succeeded, partially_succeeded, failed, and cancelled" do
      succeeded = create(:import_batch, :succeeded)
      failed = create(:import_batch, :failed)
      cancelled = create(:import_batch, status: :cancelled, finished_at: Time.current)
      create(:import_batch)

      expect(described_class.terminal).to contain_exactly(succeeded, failed, cancelled)
    end
  end

  describe "ULID primary key" do
    it "assigns a ULID on create" do
      import_batch.save!

      expect(import_batch.id).to match(/\A[0-9A-HJKMNP-TV-Z]{26}\z/)
    end
  end
end
