# frozen_string_literal: true

require "rails_helper"

RSpec.describe AnalysisRuns::ReconcileJob do
  before { described_class.clear }

  describe "#perform" do
    it "runs reconciliation" do
      expect(ImportBatches::ReconcileStuck).to receive(:call)
      expect(AnalysisRuns::ReconcileAll).to receive(:call)
      expect(SystemJobs::ReconcileFailed).to receive(:call)

      described_class.new.perform(false)
    end

    it "reschedules itself when reschedule is true" do
      allow(ImportBatches::ReconcileStuck).to receive(:call)
      allow(AnalysisRuns::ReconcileAll).to receive(:call)
      allow(SystemJobs::ReconcileFailed).to receive(:call)

      described_class.new.perform(true)

      expect(described_class.jobs.size).to eq(1)
    end

    it "does not reschedule when reschedule is false" do
      allow(ImportBatches::ReconcileStuck).to receive(:call)
      allow(AnalysisRuns::ReconcileAll).to receive(:call)
      allow(SystemJobs::ReconcileFailed).to receive(:call)

      described_class.new.perform(false)

      expect(described_class.jobs).to be_empty
    end

    it "reschedules by default when called without arguments" do
      allow(ImportBatches::ReconcileStuck).to receive(:call)
      allow(AnalysisRuns::ReconcileAll).to receive(:call)
      allow(SystemJobs::ReconcileFailed).to receive(:call)

      described_class.new.perform

      expect(described_class.jobs.size).to eq(1)
    end
  end
end
