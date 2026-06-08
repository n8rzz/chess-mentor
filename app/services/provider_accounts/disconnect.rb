# frozen_string_literal: true

module ProviderAccounts
  class Disconnect
    class ImportInProgressError < StandardError; end

    def self.call(user:, provider_account:)
      new(user:, provider_account:).call
    end

    def initialize(user:, provider_account:)
      @user = user
      @provider_account = provider_account
    end

    def call
      raise ActiveRecord::RecordNotFound unless @provider_account.user_id == @user.id

      if @provider_account.import_batches.in_progress.exists?
        raise ImportInProgressError, "Cannot disconnect while an import is in progress"
      end

      @provider_account.destroy!
    end
  end
end
