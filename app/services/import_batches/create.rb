# frozen_string_literal: true

module ImportBatches
  class Create
    class Error < StandardError; end
    class ImportInProgressError < Error; end
    class InvalidProviderError < Error; end
    class InvalidFiltersError < Error; end
    class MissingAccessTokenError < Error; end

    ALLOWED_DAYS = [ 7, 14, 30 ].freeze
    ALLOWED_TIME_CONTROLS = %w[bullet blitz rapid classical].freeze
    MAX_GAMES_LIMIT = 30
    SYNC_OVERLAP = 1.minute

    def self.call(user:, provider_account:, days:, time_controls:, max_games: MAX_GAMES_LIMIT)
      new(user:, provider_account:, days:, time_controls:, max_games:).call
    end

    def initialize(user:, provider_account:, days:, time_controls:, max_games: MAX_GAMES_LIMIT)
      @user = user
      @provider_account = provider_account
      @days = days.to_i
      @time_controls = Array(time_controls).map(&:to_s)
      @max_games = max_games.to_i
    end

    def call
      validate!

      batch = nil
      ActiveRecord::Base.transaction do
        batch = ImportBatch.create!(
          user: @user,
          provider_account: @provider_account,
          provider: @provider_account.provider,
          requested_since: requested_since,
          requested_until: Time.current,
          max_games: @max_games,
          time_controls: @time_controls,
          metadata: {}
        )

        SystemJobs::Create.call(
          user: @user,
          job_type: :import_games,
          payload: JobPayload.for(batch: batch, provider_account: @provider_account)
        )
      end

      batch
    end

    private

    def requested_since
      watermark = sync_watermark
      lookback = @days.days.ago

      return lookback if watermark.blank?

      [ watermark - SYNC_OVERLAP, lookback ].max
    end

    def sync_watermark
      newest_game_played_at = @provider_account.games.maximum(:played_at)
      [ @provider_account.last_imported_at, newest_game_played_at ].compact.max
    end

    def validate!
      raise ActiveRecord::RecordNotFound unless @provider_account.user_id == @user.id
      raise InvalidProviderError, "Only Lichess imports are supported" unless @provider_account.lichess?
      raise MissingAccessTokenError, "Reconnect your Lichess account before importing games" if @provider_account.access_token.blank?

      if @provider_account.import_batches.in_progress.exists?
        raise ImportInProgressError, "An import is already in progress for this account"
      end

      raise InvalidFiltersError, "Invalid date range" unless ALLOWED_DAYS.include?(@days)

      invalid_controls = @time_controls - ALLOWED_TIME_CONTROLS
      raise InvalidFiltersError, "Invalid time controls" if invalid_controls.any?
      raise InvalidFiltersError, "Select at least one time control" if @time_controls.empty?

      unless @max_games.between?(1, MAX_GAMES_LIMIT)
        raise InvalidFiltersError, "Max games must be between 1 and #{MAX_GAMES_LIMIT}"
      end
    end
  end
end
