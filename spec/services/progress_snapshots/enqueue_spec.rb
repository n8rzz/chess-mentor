# frozen_string_literal: true

require "rails_helper"

RSpec.describe ProgressSnapshots::Enqueue do
  describe ".call" do
    it "creates a pending update_progress_snapshots job" do
      user = create(:user)

      expect { described_class.call(user:) }
        .to change { user.system_jobs.update_progress_snapshots.pending.count }
        .by(1)
    end

    it "dedupes pending jobs" do
      user = create(:user)
      create(:system_job, user:, job_type: :update_progress_snapshots, status: :pending)

      expect { described_class.call(user:) }
        .not_to change { user.system_jobs.update_progress_snapshots.count }
    end
  end
end
