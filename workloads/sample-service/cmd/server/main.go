// Command server runs the TenantForge reference workload: a deliberately
// small multi-tenant notes API whose only job is to prove the platform
// (container -> Helm -> AKS -> ArgoCD -> observability) works end-to-end.
package main

import (
	"encoding/json"
	"log/slog"
	"net/http"
	"os"
	"strconv"
	"time"

	"github.com/chethankumblekar/tenantforge/workloads/sample-service/internal/metrics"
	"github.com/chethankumblekar/tenantforge/workloads/sample-service/internal/notes"
)

func main() {
	logger := slog.New(slog.NewJSONHandler(os.Stdout, nil))
	slog.SetDefault(logger)

	addr := os.Getenv("LISTEN_ADDR")
	if addr == "" {
		addr = ":8080"
	}

	store := notes.NewStore()
	reg := metrics.NewRegistry()
	mux := newMux(store, reg)

	srv := &http.Server{
		Addr:         addr,
		Handler:      withLogging(mux),
		ReadTimeout:  5 * time.Second,
		WriteTimeout: 5 * time.Second,
		IdleTimeout:  60 * time.Second,
	}

	slog.Info("starting sample-service", "addr", addr)
	if err := srv.ListenAndServe(); err != nil && err != http.ErrServerClosed {
		slog.Error("server stopped unexpectedly", "error", err)
		os.Exit(1)
	}
}

func newMux(store *notes.Store, reg *metrics.Registry) *http.ServeMux {
	mux := http.NewServeMux()

	// Probes are deliberately not instrumented — they're kubelet noise, not
	// traffic the SLOs care about.
	mux.HandleFunc("GET /healthz", handleHealthz)
	mux.HandleFunc("GET /readyz", handleReadyz)
	mux.HandleFunc("GET /metrics", handleMetrics(reg))

	route(mux, reg, "GET", "/tenants/{tenantID}/notes", handleListNotes(store))
	route(mux, reg, "POST", "/tenants/{tenantID}/notes", handleCreateNote(store))
	route(mux, reg, "GET", "/tenants/{tenantID}/notes/{id}", handleGetNote(store))

	return mux
}

// route registers h under "METHOD pattern" and wraps it with request-count
// and latency instrumentation, labeled by the route pattern rather than the
// raw request path so tenant/note IDs never become a metric label value.
func route(mux *http.ServeMux, reg *metrics.Registry, method, pattern string, h http.HandlerFunc) {
	mux.HandleFunc(method+" "+pattern, func(w http.ResponseWriter, r *http.Request) {
		sw := &statusWriter{ResponseWriter: w, status: http.StatusOK}
		start := time.Now()
		h(sw, r)
		reg.Observe(method, pattern, strconv.Itoa(sw.status), time.Since(start))
	})
}

// statusWriter captures the status code a handler writes, since
// http.ResponseWriter doesn't expose it after the fact.
type statusWriter struct {
	http.ResponseWriter
	status int
}

func (w *statusWriter) WriteHeader(code int) {
	w.status = code
	w.ResponseWriter.WriteHeader(code)
}

// handleHealthz answers "is the process alive" — used for the liveness probe.
func handleHealthz(w http.ResponseWriter, r *http.Request) {
	w.WriteHeader(http.StatusOK)
	_, _ = w.Write([]byte("ok"))
}

// handleReadyz answers "can this pod take traffic" — used for the readiness
// probe. There's no external dependency yet (in-memory store), so this is
// always ready once the process is up; it's a placeholder for when a real
// backing store is added.
func handleReadyz(w http.ResponseWriter, r *http.Request) {
	w.WriteHeader(http.StatusOK)
	_, _ = w.Write([]byte("ready"))
}

// handleMetrics serves real request-count and latency metrics in Prometheus
// exposition format — see internal/metrics and docs/adr/0004 for why this is
// hand-rolled rather than the OTel SDK. The OTel collector
// (observability/otel-collector) scrapes this endpoint.
func handleMetrics(reg *metrics.Registry) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		w.Header().Set("Content-Type", "text/plain; version=0.0.4")
		reg.RenderText(w)
	}
}

func handleListNotes(store *notes.Store) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		tenantID := r.PathValue("tenantID")
		writeJSON(w, http.StatusOK, store.List(tenantID))
	}
}

func handleCreateNote(store *notes.Store) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		tenantID := r.PathValue("tenantID")

		var body struct {
			Text string `json:"text"`
		}
		if err := json.NewDecoder(r.Body).Decode(&body); err != nil || body.Text == "" {
			http.Error(w, `{"error":"body must be JSON with a non-empty \"text\" field"}`, http.StatusBadRequest)
			return
		}

		n := store.Create(tenantID, body.Text)
		writeJSON(w, http.StatusCreated, n)
	}
}

func handleGetNote(store *notes.Store) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		tenantID := r.PathValue("tenantID")
		id := r.PathValue("id")

		n, err := store.Get(tenantID, id)
		if err != nil {
			http.Error(w, `{"error":"note not found"}`, http.StatusNotFound)
			return
		}
		writeJSON(w, http.StatusOK, n)
	}
}

func writeJSON(w http.ResponseWriter, status int, v any) {
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(status)
	_ = json.NewEncoder(w).Encode(v)
}

func withLogging(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		start := time.Now()
		next.ServeHTTP(w, r)
		slog.Info("request",
			"method", r.Method,
			"path", r.URL.Path,
			"duration_ms", time.Since(start).Milliseconds(),
		)
	})
}
