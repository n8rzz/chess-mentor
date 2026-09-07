# frozen_string_literal: true

module ReviewPeriods
  class CreateFromGames
    class Error < StandardError; end
    class EmptyGamesError < Error; end

    def self.call(user:, games:, label: nil, status: :active, time_class: nil, max_games: nil, metadata: {})
      new(user:, games:, label:, status:, time_class:, max_games:, metadata:).call
    end

    def initialize(user:, games:, label:, status:, time_class:, max_games:, metadata:)
      @user = user
      @games = Array(games)
      @label = label
      @status = status
      @time_class = time_class
      @max_games = max_games
      @metadata = metadata
    end

    def call
      raise EmptyGamesError, "At least one game is required" if @games.empty?

      scoped_games = @user.games.where(id: @games.map { |game| game.respond_to?(:id) ? game.id : game })
      raise EmptyGamesError, "No games found for user" if scoped_games.empty?

      starts_at = scoped_games.minimum(:played_at)
      ends_at = scoped_games.maximum(:played_at)
      label = @label.presence || default_label(starts_at, ends_at)

      period = ActiveRecord::Base.transaction do
        period = ReviewPeriod.create!(
          user: @user,
          label: label,
          starts_at: starts_at,
          ends_at: ends_at,
          status: @status,
          time_class: @time_class,
          max_games: @max_games || scoped_games.count,
          metadata: @metadata
        )

        scoped_games.find_each do |game|
          period.review_period_games.create!(game: game)
        end

        period
      end

      ReviewPeriodMetrics::Enqueue.call(user: @user)
      period
    end

    private

    def default_label(starts_at, ends_at)
      "#{starts_at.to_date} – #{ends_at.to_date}"
    end
  end
end
