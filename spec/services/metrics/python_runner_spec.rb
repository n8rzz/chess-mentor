# frozen_string_literal: true

require "rails_helper"

RSpec.describe Metrics::PythonRunner do
  describe ".persist_game_metrics!" do
    it "raises when the python script fails" do
      runner = described_class.new
      allow(runner).to receive(:python_env).and_return({})
      allow(Open3).to receive(:capture3).and_return([ "", "boom", instance_double(Process::Status, success?: false) ])
      allow(Dir).to receive(:chdir).and_yield

      expect do
        runner.persist_game_metrics!(analysis_run_id: "01TEST")
      end.to raise_error(Metrics::PythonRunner::Error, /boom/)
    end
  end
end
