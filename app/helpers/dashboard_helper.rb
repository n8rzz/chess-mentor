# frozen_string_literal: true

module DashboardHelper
  CHART_COLORS = [
    "#111827",
    "#2563eb",
    "#059669",
    "#d97706"
  ].freeze

  def dashboard_chart_cards(progress)
    [
      rating_history_card(progress),
      weakness_trend_card(progress),
      line_card("Blunders per game", progress.blunders_per_game, key: "blunders"),
      line_card("Average centipawn loss", progress.average_centipawn_loss, key: "cpl")
    ].compact
  end

  def progress_chart_payload(progress)
    dashboard_chart_cards(progress).to_h { |card| [ card[:key], card[:series] ] }
  end

  private

  def rating_history_card(progress)
    eligible = progress.ratings_by_time_class.select { |_, points| points.size >= 2 }
    return if eligible.empty?

    reference_times = eligible.values.flat_map { |points| points.map(&:at) }.uniq.sort
    labels = reference_times.map { |at| format_chart_label(at) }

    datasets = eligible.each_with_index.map do |(time_class, points), index|
      values_by_time = points.index_by(&:at)
      {
        label: time_class.to_s.titleize,
        data: reference_times.map { |at| values_by_time[at]&.value },
        borderColor: CHART_COLORS[index % CHART_COLORS.length],
        backgroundColor: "transparent",
        tension: 0.25,
        spanGaps: true
      }
    end

    {
      key: "rating_history",
      label: "Rating history",
      series: {
        labels: labels,
        datasets: datasets
      }
    }
  end

  def weakness_trend_card(progress)
    points = progress.weakness_trend
    return if points.size < 2

    values = points.map { |point| point.occurrences || point.frequency }
    {
      key: "weakness_trend",
      label: "Weakness trend",
      series: {
        labels: points.map { |point| format_chart_label(point.at) },
        datasets: [
          {
            label: "Occurrences",
            data: values,
            borderColor: CHART_COLORS.first,
            backgroundColor: "transparent",
            tension: 0.25
          }
        ]
      }
    }
  end

  def line_card(label, points, key:)
    return if points.size < 2

    {
      key: key,
      label: label,
      series: {
        labels: points.map { |point| format_chart_label(point.at) },
        datasets: [
          {
            label: label,
            data: points.map(&:value),
            borderColor: CHART_COLORS[1],
            backgroundColor: "transparent",
            tension: 0.25
          }
        ]
      }
    }
  end

  def format_chart_label(timestamp)
    timestamp.in_time_zone.strftime("%b %-d")
  end
end
