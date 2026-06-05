# frozen_string_literal: true

# == Schema Information
#
# Table name: analysis_runs
#
#  id               :string           not null, primary key
#  analysis_version :string           not null
#  depth            :integer          not null
#  engine_name      :string           not null
#  engine_version   :string           not null
#  error_details    :jsonb
#  error_message    :text
#  finished_at      :datetime
#  metadata         :jsonb            not null
#  started_at       :datetime
#  status           :integer          default("pending"), not null
#  created_at       :datetime         not null
#  updated_at       :datetime         not null
#  game_id          :string           not null
#  user_id          :string           not null
#
# Indexes
#
#  index_analysis_runs_on_game_id             (game_id)
#  index_analysis_runs_on_user_id             (user_id)
#  index_analysis_runs_on_user_id_and_status  (user_id,status)
#
# Foreign Keys
#
#  fk_rails_...  (game_id => games.id) ON DELETE => cascade
#  fk_rails_...  (user_id => users.id) ON DELETE => cascade
#
require "rails_helper"

RSpec.describe AnalysisRun, type: :model do
  subject(:analysis_run) { build(:analysis_run) }

  describe "associations" do
    it { is_expected.to belong_to(:game) }
    it { is_expected.to belong_to(:user) }
    it { is_expected.to have_many(:move_evaluations).dependent(:destroy) }
    it { is_expected.to have_many(:candidate_events).dependent(:destroy) }
  end

  describe "enums" do
    it do
      expect(analysis_run).to define_enum_for(:status)
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
  end

  describe "validations" do
    it { is_expected.to validate_presence_of(:engine_name) }
    it { is_expected.to validate_presence_of(:engine_version) }
    it { is_expected.to validate_presence_of(:analysis_version) }
    it { is_expected.to validate_presence_of(:depth) }

    it "prevents updates to terminal runs" do
      run = create(:analysis_run, :succeeded)

      run.depth = 20

      expect(run).not_to be_valid
      expect(run.errors[:base]).to include("terminal analysis runs cannot be modified")
    end

    %i[failed cancelled].each do |terminal_trait|
      it "prevents updates to #{terminal_trait} runs" do
        run = create(:analysis_run, terminal_trait)

        run.error_message = "changed"

        expect(run).not_to be_valid
        expect(run.errors[:base]).to include("terminal analysis runs cannot be modified")
      end
    end
  end

  describe "scopes" do
    it "in_progress includes pending and running" do
      pending = create(:analysis_run)
      running = create(:analysis_run, :running)
      create(:analysis_run, :succeeded)

      expect(described_class.in_progress).to contain_exactly(pending, running)
    end

    it "terminal includes succeeded, partially_succeeded, failed, and cancelled" do
      succeeded = create(:analysis_run, :succeeded)
      failed = create(:analysis_run, :failed)
      cancelled = create(:analysis_run, status: :cancelled, finished_at: Time.current)
      create(:analysis_run)

      expect(described_class.terminal).to contain_exactly(succeeded, failed, cancelled)
    end

    it "succeeded includes only succeeded runs" do
      succeeded = create(:analysis_run, :succeeded)
      create(:analysis_run, :failed)

      expect(described_class.succeeded).to contain_exactly(succeeded)
    end
  end

  describe "ULID primary key" do
    it "assigns a ULID on create" do
      analysis_run.save!

      expect(analysis_run.id).to match(/\A[0-9A-HJKMNP-TV-Z]{26}\z/)
    end
  end
end
