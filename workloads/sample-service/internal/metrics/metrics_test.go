package metrics

import (
	"strings"
	"testing"
	"time"
)

func TestObserveRendersCounterAndHistogram(t *testing.T) {
	r := NewRegistry()
	r.Observe("GET", "/tenants/{tenantID}/notes", "200", 20*time.Millisecond)
	r.Observe("GET", "/tenants/{tenantID}/notes", "200", 800*time.Millisecond)
	r.Observe("GET", "/tenants/{tenantID}/notes", "500", 5*time.Millisecond)

	var buf strings.Builder
	r.RenderText(&buf)
	out := buf.String()

	want := []string{
		`http_requests_total{method="GET",route="/tenants/{tenantID}/notes",status="200"} 2`,
		`http_requests_total{method="GET",route="/tenants/{tenantID}/notes",status="500"} 1`,
		`http_request_duration_seconds_count{method="GET",route="/tenants/{tenantID}/notes"} 3`,
	}
	for _, w := range want {
		if !strings.Contains(out, w) {
			t.Errorf("output missing %q\ngot:\n%s", w, out)
		}
	}
}

func TestHistogramBucketsAreCumulative(t *testing.T) {
	r := NewRegistry()
	r.Observe("GET", "/healthz", "200", 20*time.Millisecond) // falls in the 0.025 bucket and every larger one

	var buf strings.Builder
	r.RenderText(&buf)
	out := buf.String()

	if !strings.Contains(out, `http_request_duration_seconds_bucket{method="GET",route="/healthz",le="0.025"} 1`) {
		t.Errorf("expected le=0.025 bucket to contain the observation:\n%s", out)
	}
	if !strings.Contains(out, `http_request_duration_seconds_bucket{method="GET",route="/healthz",le="10"} 1`) {
		t.Errorf("expected le=10 bucket to still contain the observation (cumulative):\n%s", out)
	}
	if !strings.Contains(out, `http_request_duration_seconds_bucket{method="GET",route="/healthz",le="0.005"} 0`) {
		t.Errorf("expected le=0.005 bucket to NOT contain the 20ms observation:\n%s", out)
	}
}

func TestNoObservationsRendersNoSeries(t *testing.T) {
	r := NewRegistry()

	var buf strings.Builder
	r.RenderText(&buf)
	out := buf.String()

	if strings.Contains(out, "http_requests_total{") {
		t.Errorf("expected no http_requests_total series with zero observations:\n%s", out)
	}
	if !strings.Contains(out, "sample_service_up 1") {
		t.Errorf("expected sample_service_up gauge always present:\n%s", out)
	}
}
