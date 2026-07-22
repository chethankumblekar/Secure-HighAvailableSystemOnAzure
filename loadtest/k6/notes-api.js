// k6 load test for sample-service's notes API. Load profile is a mixed
// multi-tenant workload (create, get-by-id, list) across a small pool of
// tenants, matching how the reference workload is actually meant to be
// used. Thresholds are deliberately set to the exact SLOs defined in
// observability/prometheus/slo-rules.yaml (p95 < 500ms, error ratio < 5%)
// so a passing k6 run and a quiet SLO dashboard are the same claim
// checked two different ways.
import http from 'k6/http';
import { check, sleep } from 'k6';
import { Counter } from 'k6/metrics';

const BASE_URL = __ENV.K6_BASE_URL || 'http://localhost:8080';
const TENANTS = ['tenant-a', 'tenant-b', 'tenant-c'];

const errors = new Counter('sample_service_errors');

export const options = {
  stages: [
    { duration: '30s', target: 20 }, // ramp up
    { duration: '4m', target: 20 }, // steady state
    { duration: '30s', target: 0 }, // ramp down
  ],
  thresholds: {
    http_req_duration: ['p(95)<500'], // matches SampleServiceHighLatency's threshold
    http_req_failed: ['rate<0.05'], // matches SampleServiceHighErrorRate's threshold
  },
};

function randomTenant() {
  return TENANTS[Math.floor(Math.random() * TENANTS.length)];
}

export default function () {
  const tenant = randomTenant();

  const createRes = http.post(
    `${BASE_URL}/tenants/${tenant}/notes`,
    JSON.stringify({ text: `load-test note at ${Date.now()}` }),
    { headers: { 'Content-Type': 'application/json' }, tags: { route: 'create' } },
  );
  const created = check(createRes, {
    'create: status is 201': (r) => r.status === 201,
  });
  if (!created) {
    errors.add(1);
    sleep(1);
    return;
  }

  const noteID = createRes.json('id');

  const getRes = http.get(`${BASE_URL}/tenants/${tenant}/notes/${noteID}`, {
    tags: { route: 'get-by-id' },
  });
  check(getRes, { 'get: status is 200': (r) => r.status === 200 }) || errors.add(1);

  const listRes = http.get(`${BASE_URL}/tenants/${tenant}/notes`, {
    tags: { route: 'list' },
  });
  check(listRes, { 'list: status is 200': (r) => r.status === 200 }) || errors.add(1);

  sleep(1);
}
