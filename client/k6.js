import http from 'k6/http';
import { check } from 'k6';

export const options = {
  summaryTimeUnit: 'ms',
  scenarios: {
    contacts: {
      executor: 'constant-vus',
      startTime: '0s',
      vus: 1,
      duration: '1m',
      // duration: '10s',
  },
  },
};
export function handleSummary(data) {
  const throughput = data.metrics.http_reqs.values.rate;
  const req_count = data.metrics.http_reqs.values.count;
  const avg_latency = data.metrics.http_req_waiting.values.avg;
  const p90_latency = data.metrics.http_req_waiting.values['p(90)'];
  const p95_latency = data.metrics.http_req_waiting.values['p(95)'];

  return {
    'summary.json': JSON.stringify(data), //the default data object
    stdout: `${throughput}\n${req_count}\n${avg_latency}\n${p90_latency}\n${p95_latency}\n`,
  };
}

let resnet = {
    method: 'POST',
    url: 'http://localhost:8080/predict',
    body: {}, 
    params: {
      headers: {
        'Content-Type': 'application/json'
      },
    },
};
export default function () {
  const res = http.post(resnet.url, resnet.body, resnet.params)
  check(res, {
    'is status 200': (r) => r.status === 200,
  });
}
