// Stress variant of notes-api.js: no think time, far more VUs, short
// duration. Where notes-api.js answers "does normal usage stay inside
// the SLO," this answers "where does it actually break" — sample-service
// runs a single replica with a 250m CPU limit
// (workloads/sample-service/helm/values.yaml) and no autoscaling by
// default, so this is expected to find that ceiling, not a bug.
import http from 'k6/http';
import { check } from 'k6';

const BASE_URL = __ENV.K6_BASE_URL || 'http://localhost:8080';
const TENANTS = ['tenant-a', 'tenant-b', 'tenant-c'];

export const options = {
  stages: [
    { duration: '20s', target: 100 },
    { duration: '90s', target: 100 },
    { duration: '10s', target: 0 },
  ],
};

function randomTenant() {
  return TENANTS[Math.floor(Math.random() * TENANTS.length)];
}

export default function () {
  const tenant = randomTenant();
  const res = http.get(`${BASE_URL}/tenants/${tenant}/notes`, { tags: { route: 'list' } });
  check(res, { 'status is 200': (r) => r.status === 200 });
}
