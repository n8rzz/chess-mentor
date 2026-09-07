# frozen_string_literal: true

class RenameCandidateEventsToAnalysisEvents < ActiveRecord::Migration[8.1]
  def change
    rename_table :candidate_events, :analysis_events
  end
end
