document.addEventListener("DOMContentLoaded", function () {
  const canvas = document.getElementById("velocity-chart");
  if (!canvas) return;

  const chartData = JSON.parse(canvas.dataset.chart);
  const labels = chartData.map(i => i.name);
  const velocity = chartData.map(i => i.velocity);
  const bugRatio = chartData.map(i => i.bug_ratio);

  new Chart(canvas, {
    type: 'bar',
    data: {
      labels: labels,
      datasets: [
        {
          type: 'bar',
          label: 'Velocity',
          data: velocity,
          backgroundColor: 'rgba(54, 162, 235, 0.5)',
          borderColor: 'rgba(54, 162, 235, 1)',
          borderWidth: 1
        },
        {
          type: 'line',
          label: 'Bug Ratio',
          data: bugRatio,
          borderColor: 'rgba(255, 99, 132, 1)',
          backgroundColor: 'rgba(255, 99, 132, 0.2)',
          yAxisID: 'y1'
        }
      ]
    },
    options: {
      scales: {
        y: {
          beginAtZero: true,
          title: { display: true, text: 'Velocity' }
        },
        y1: {
          beginAtZero: true,
          position: 'right',
          title: { display: true, text: 'Bug / Point' }
        }
      }
    }
  });
});
