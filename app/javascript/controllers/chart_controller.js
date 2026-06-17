import { Controller } from "@hotwired/stimulus";

export default class extends Controller {
  static values = {
    type: { type: String, default: "line" },
    series: Object,
    label: String,
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
          tooltip: { mode: "index", intersect: false },
        },
        scales: {
          x: {
            ticks: { maxTicksLimit: 6, maxRotation: 0 },
          },
          y: {
            beginAtZero: false,
          },
        },
      },
    });
  }

  disconnect() {
    this.chart?.destroy();
  }
}
