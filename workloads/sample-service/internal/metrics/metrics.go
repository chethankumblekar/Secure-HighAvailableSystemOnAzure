// Package metrics is a minimal Prometheus-exposition-format registry, stdlib
// only — see docs/adr/0004-stdlib-metrics-not-otel-sdk.md for why this
// isn't the OTel SDK. It supports exactly what sample-service's SLOs need:
// a request counter and a duration histogram, both labeled by method and
// route pattern (never the raw path — tenant/note IDs would blow up
// cardinality).
package metrics

import (
	"fmt"
	"io"
	"sort"
	"strconv"
	"strings"
	"sync"
	"time"
)

// defaultBuckets mirrors Prometheus client library defaults closely enough
// for a p95/p99 latency SLO in the sub-second range this service lives in.
var defaultBuckets = []float64{0.005, 0.01, 0.025, 0.05, 0.1, 0.25, 0.5, 1, 2.5, 5, 10}

type histogram struct {
	// counts[i] is the number of observations <= defaultBuckets[i]
	// (Prometheus bucket semantics: each bucket is already cumulative).
	counts []uint64
	sum    float64
	count  uint64
}

func newHistogram() *histogram {
	return &histogram{counts: make([]uint64, len(defaultBuckets))}
}

func (h *histogram) observe(seconds float64) {
	h.sum += seconds
	h.count++
	for i, b := range defaultBuckets {
		if seconds <= b {
			h.counts[i]++
		}
	}
}

// Registry accumulates request counts and latencies. Safe for concurrent use.
type Registry struct {
	mu       sync.Mutex
	requests map[string]uint64     // key: method|route|status
	latency  map[string]*histogram // key: method|route
}

func NewRegistry() *Registry {
	return &Registry{
		requests: make(map[string]uint64),
		latency:  make(map[string]*histogram),
	}
}

// Observe records one completed request: method and route are the fixed
// route pattern used to register the handler (e.g. "/tenants/{tenantID}/notes"),
// not r.URL.Path.
func (r *Registry) Observe(method, route, status string, dur time.Duration) {
	r.mu.Lock()
	defer r.mu.Unlock()

	r.requests[method+"|"+route+"|"+status]++

	hKey := method + "|" + route
	h, ok := r.latency[hKey]
	if !ok {
		h = newHistogram()
		r.latency[hKey] = h
	}
	h.observe(dur.Seconds())
}

// RenderText renders the registry in Prometheus text exposition format.
func (r *Registry) RenderText(w io.Writer) {
	r.mu.Lock()
	defer r.mu.Unlock()

	fmt.Fprintln(w, "# HELP sample_service_up Always 1 while the process is serving this endpoint.")
	fmt.Fprintln(w, "# TYPE sample_service_up gauge")
	fmt.Fprintln(w, "sample_service_up 1")

	fmt.Fprintln(w, "# HELP http_requests_total Total HTTP requests, by method, route and status code.")
	fmt.Fprintln(w, "# TYPE http_requests_total counter")
	for _, k := range sortedKeys(r.requests) {
		method, route, status := splitKey3(k)
		fmt.Fprintf(w, "http_requests_total{method=%q,route=%q,status=%q} %d\n", method, route, status, r.requests[k])
	}

	fmt.Fprintln(w, "# HELP http_request_duration_seconds Request duration in seconds, by method and route.")
	fmt.Fprintln(w, "# TYPE http_request_duration_seconds histogram")
	for _, k := range sortedKeys(r.latency) {
		method, route, _ := splitKey3(k + "|")
		h := r.latency[k]
		for i, b := range defaultBuckets {
			fmt.Fprintf(w, "http_request_duration_seconds_bucket{method=%q,route=%q,le=%q} %d\n",
				method, route, strconv.FormatFloat(b, 'g', -1, 64), h.counts[i])
		}
		fmt.Fprintf(w, "http_request_duration_seconds_bucket{method=%q,route=%q,le=\"+Inf\"} %d\n", method, route, h.count)
		fmt.Fprintf(w, "http_request_duration_seconds_sum{method=%q,route=%q} %s\n", method, route, strconv.FormatFloat(h.sum, 'f', -1, 64))
		fmt.Fprintf(w, "http_request_duration_seconds_count{method=%q,route=%q} %d\n", method, route, h.count)
	}
}

func sortedKeys[V any](m map[string]V) []string {
	keys := make([]string, 0, len(m))
	for k := range m {
		keys = append(keys, k)
	}
	sort.Strings(keys)
	return keys
}

func splitKey3(k string) (a, b, c string) {
	parts := strings.SplitN(k, "|", 3)
	for len(parts) < 3 {
		parts = append(parts, "")
	}
	return parts[0], parts[1], parts[2]
}
