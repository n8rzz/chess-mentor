# frozen_string_literal: true

# Shared analysis/pattern version stamps. Keep string values aligned with
# analysis/worker/weakness_package/constants.py and eval enqueue defaults.
module AnalysisVersions
  ANALYSIS_VERSION = "1.1.0"
  METRIC_FORMULA_VERSION = "1.0.0"
  ENGINE_NAME = "Stockfish"
  ENGINE_VERSION = "16.1"

  # Pass 1 scan depth (analysis_runs.depth).
  DEPTH_SCAN = 14
  # Pass 2 critical depth (analysis_runs.depth_critical).
  DEPTH_CRITICAL = 20
  # MultiPV for both passes (analysis_runs.multipv). Pass 1 needs MultiPV >= 2
  # for candidate-gap criticality; pass 2 reuses the same MultiPV at deeper depth.
  MULTIPV = 3

  # Back-compat alias used by older enqueue call sites / seeds.
  DEFAULT_DEPTH = DEPTH_SCAN

  PATTERN_CLASSIFIER_NAME = "rules_v1"
  PATTERN_CLASSIFIER_VERSION = "1.0.0"
  PATTERN_TAXONOMY_VERSION = "1.0.0"

  # Opening / middlegame / endgame classifier stamped on analysis_runs.metadata.
  PHASE_CLASSIFIER_VERSION = "1.0.0"
end
