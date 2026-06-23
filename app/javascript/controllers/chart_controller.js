import { Controller } from "@hotwired/stimulus";
import { integerYAxisScale } from "utils/chart_axis";

export default class extends Controller {
  static values = {
    type: { type: String, default: "line" },
    series: Object,
    label: String,
    integerYAxis: { type: Boolean, default: false },
  };

  async connect() {
    if (!this.hasSeriesValue || !this.seriesValue?.datasets?.length) {
      return;
    }

    await import("chart.js");

    const Chart = window.Chart;

    if (!Chart) {
      return;
    }

    const canvas = this.element.querySelector("canvas");

    if (!canvas) {
      return;
    }

    const integerYAxis = this.integerYAxisValue;

    this.chart = new Chart(canvas.getContext("2d"), {
      type: this.typeValue,
      data: this.seriesValue,
      options: {
        responsive: true,
        maintainAspectRatio: false,
        plugins: {
          legend: {
            display: this.seriesValue.datasets.length > 1,
            position: "bottom",
          },
          tooltip: {
            mode: "index",
            intersect: false,
            callbacks: integerYAxis
              ? {
                  label: (context) => {
                    const datasetLabel = context.dataset.label || "";
                    const value = Math.round(context.parsed.y);
                    return datasetLabel
                      ? `${datasetLabel}: ${value}`
                      : `${value}`;
                  },
                }
              : undefined,
          },
        },
        scales: {
          x: {
            ticks: { maxTicksLimit: 6, maxRotation: 0 },
          },
          y: {
            beginAtZero: false,
            ...(integerYAxis ? integerYAxisScale(this.seriesValue) : {}),
          },
        },
      },
    });
  }

  disconnect() {
    this.chart?.destroy();
  }
}
