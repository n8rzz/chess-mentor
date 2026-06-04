require "rails_helper"

RSpec.describe "Active Job queue adapter" do
  it "uses the test adapter in the test environment" do
    expect(ActiveJob::Base.queue_adapter).to be_a(ActiveJob::QueueAdapters::TestAdapter)
  end
end
