# frozen_string_literal: true

require "rails_helper"

RSpec.describe ReviewPeriodMetrics::Enqueue do
  describe ".call" do
    it "creates a pending refresh_review_period_metrics job" do
      user = create(:user)

      expect { described_class.call(user:) }
        .to change { user.system_jobs.refresh_review_period_metrics.pending.count }
        .by(1)
    end

    it "dedupes pending jobs" do
      user = create(:user)
      create(:system_job, user:, job_type: :refresh_review_period_metrics, status: :pending)

      expect { described_class.call(user:) }
        .not_to change { user.system_jobs.refresh_review_period_metrics.count }
    end
  end
end
