# frozen_string_literal: true

module ProviderIdentifiable
  extend ActiveSupport::Concern

  PROVIDERS = {
    lichess: 0,
    chess_com: 1
  }.freeze

  included do
    enum :provider, PROVIDERS, validate: true
  end
end
