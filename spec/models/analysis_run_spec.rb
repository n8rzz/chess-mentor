# frozen_string_literal: true

# == Schema Information
#
# Table name: analysis_runs
#
#  id                     :string           not null, primary key
#  analysis_version       :string           not null
#  depth                  :integer          not null
#  depth_critical         :integer          default(20), not null
#  engine_name            :string           not null
#  engine_version         :string           not null
#  error_details          :jsonb
#  error_message          :text
#  finished_at            :datetime
#  metadata               :jsonb            not null
#  metric_formula_version :string           default("1.0.0"), not null
#  multipv                :integer          default(3), not null
#  started_at             :datetime
#  status                 :integer          default("pending"), not null
#  created_at             :datetime         not null
#  updated_at             :datetime         not null
#  game_id                :string           not null
#  user_id                :string           not null
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
    it { is_expected.to have_many(:analysis_events).dependent(:destroy) }
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
    it { is_expected.to validate_presence_of(:depth_critical) }
    it { is_expected.to validate_presence_of(:multipv) }

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

  describe "#progress_percent" do
    it "returns a low percent while queued" do
      expect(build(:analysis_run).progress_percent).to eq(5)
    end

    it "advances during scan based on moves evaluated" do
      run = build(
        :analysis_run,
        :running,
        metadata: { "phase" => "scan", "moves_done" => 10, "moves_total" => 40 }
      )

      expect(run.progress_percent).to eq(30)
    end

    it "advances during deepen based on critical positions" do
      run = build(
        :analysis_run,
        :running,
        metadata: { "phase" => "deepen", "pass2_done" => 2, "pass2_total" => 4 }
      )

      expect(run.progress_percent).to eq(81)
    end

    it "returns 100 when succeeded" do
      expect(build(:analysis_run, :succeeded).progress_percent).to eq(100)
    end
  end

  describe "#status_label" do
    it "returns Queued for pending runs" do
      expect(build(:analysis_run).status_label).to eq("Queued")
    end

    it "returns the phase label while running" do
      run = build(:analysis_run, :running, metadata: { "phase" => "detect" })

      expect(run.status_label).to eq("Detect")
    end

    it "includes move progress during scan" do
      run = build(
        :analysis_run,
        :running,
        metadata: { "phase" => "scan", "moves_done" => 12, "moves_total" => 40 }
      )

      expect(run.status_label).to eq("Scan 12/40")
    end

    it "returns Running when no phase is set" do
      expect(build(:analysis_run, :running).status_label).to eq("Running")
    end

    it "returns Succeeded for completed runs" do
      expect(build(:analysis_run, :succeeded).status_label).to eq("Succeeded")
    end
  end

  describe "#recently_finished?" do
    it "is true for runs that finished within the recent window" do
      run = build(:analysis_run, :succeeded, finished_at: 1.minute.ago)

      expect(run).to be_recently_finished
    end

    it "is false for older successes" do
      run = build(:analysis_run, :succeeded, finished_at: 20.minutes.ago)

      expect(run).not_to be_recently_finished
    end
  end
end
