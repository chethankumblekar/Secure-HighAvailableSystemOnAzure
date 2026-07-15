// Command server runs the TenantForge reference workload: a deliberately
// small multi-tenant notes API whose only job is to prove the platform
// (container -> Helm -> AKS -> ArgoCD -> observability) works end-to-end.
package main

import (
	"encoding/json"
	"log/slog"
	"net/http"
	"os"
	"time"

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
	mux := newMux(store)

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

func newMux(store *notes.Store) *http.ServeMux {
	mux := http.NewServeMux()

	mux.HandleFunc("GET /healthz", handleHealthz)
	mux.HandleFunc("GET /readyz", handleReadyz)
	mux.HandleFunc("GET /metrics", handleMetrics)

	mux.HandleFunc("GET /tenants/{tenantID}/notes", handleListNotes(store))
	mux.HandleFunc("POST /tenants/{tenantID}/notes", handleCreateNote(store))
	mux.HandleFunc("GET /tenants/{tenantID}/notes/{id}", handleGetNote(store))

	return mux
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

// handleMetrics emits a minimal Prometheus-format counter without pulling in
// the full client_golang dependency — good enough to prove the observability
// pipeline (Phase 4) can scrape this service; will be replaced with real
// request/latency histograms once OTel lands.
func handleMetrics(w http.ResponseWriter, r *http.Request) {
	w.Header().Set("Content-Type", "text/plain; version=0.0.4")
	_, _ = w.Write([]byte("sample_service_up 1\n"))
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
