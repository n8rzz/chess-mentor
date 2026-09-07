# frozen_string_literal: true

# Shared analysis/pattern version stamps. Keep string values aligned with
# analysis/worker/weakness_package/constants.py and eval enqueue defaults.
module AnalysisVersions
  ANALYSIS_VERSION = "1.0.0"
  METRIC_FORMULA_VERSION = "1.0.0"
  ENGINE_NAME = "Stockfish"
  ENGINE_VERSION = "16.1"
  DEFAULT_DEPTH = 15

  PATTERN_CLASSIFIER_NAME = "rules_v1"
  PATTERN_CLASSIFIER_VERSION = "1.0.0"
  PATTERN_TAXONOMY_VERSION = "1.0.0"
end
