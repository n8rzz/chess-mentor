export function integerYAxisScale(series) {
  const values = series.datasets
    .flatMap((dataset) => dataset.data)
    .filter((value) => value != null && !Number.isNaN(Number(value)))
    .map(Number);

  if (values.length === 0) {
    return { ticks: { stepSize: 1, precision: 0 } };
  }

  const dataMin = Math.min(...values);
  const dataMax = Math.max(...values);
  const range = dataMax - dataMin;
  const padding = range <= 0 ? 5 : Math.max(1, Math.ceil(range * 0.1));
  const min = Math.floor(dataMin - padding);
  const max = Math.ceil(dataMax + padding);
  const span = max - min;

  let step = 1;

  if (span > 200) {
    step = 50;
  } else if (span > 100) {
    step = 20;
  } else if (span > 50) {
    step = 10;
  } else if (span > 20) {
    step = 5;
  }

  const tickValues = [];

  for (let value = min; value <= max; value += step) {
    tickValues.push(value);
  }

  return {
    min,
    max,
    ticks: {
      values: tickValues,
      callback: (value) => Math.round(Number(value)).toString(),
    },
  };
}
