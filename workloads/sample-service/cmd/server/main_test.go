package main

import (
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"

	"github.com/chethankumblekar/tenantforge/workloads/sample-service/internal/metrics"
	"github.com/chethankumblekar/tenantforge/workloads/sample-service/internal/notes"
)

func testMux() *http.ServeMux {
	return newMux(notes.NewStore(), metrics.NewRegistry())
}

func TestHealthzAndReadyz(t *testing.T) {
	mux := testMux()

	for _, path := range []string{"/healthz", "/readyz"} {
		req := httptest.NewRequest(http.MethodGet, path, nil)
		rec := httptest.NewRecorder()
		mux.ServeHTTP(rec, req)

		if rec.Code != http.StatusOK {
			t.Errorf("GET %s = %d, want 200", path, rec.Code)
		}
	}
}

func TestCreateAndGetNote(t *testing.T) {
	mux := testMux()

	createReq := httptest.NewRequest(http.MethodPost, "/tenants/acme/notes", strings.NewReader(`{"text":"hello"}`))
	createRec := httptest.NewRecorder()
	mux.ServeHTTP(createRec, createReq)

	if createRec.Code != http.StatusCreated {
		t.Fatalf("POST create = %d, want 201, body=%s", createRec.Code, createRec.Body.String())
	}

	var created struct {
		ID   string `json:"id"`
		Text string `json:"text"`
	}
	if err := json.Unmarshal(createRec.Body.Bytes(), &created); err != nil {
		t.Fatalf("decoding create response: %v", err)
	}
	if created.Text != "hello" {
		t.Errorf("created.Text = %q, want %q", created.Text, "hello")
	}

	getReq := httptest.NewRequest(http.MethodGet, "/tenants/acme/notes/"+created.ID, nil)
	getRec := httptest.NewRecorder()
	mux.ServeHTTP(getRec, getReq)

	if getRec.Code != http.StatusOK {
		t.Fatalf("GET note = %d, want 200, body=%s", getRec.Code, getRec.Body.String())
	}
}

func TestCreateNoteRejectsEmptyOrMissingText(t *testing.T) {
	mux := testMux()

	cases := []string{`{"text":""}`, `{}`, `not-json`}
	for _, body := range cases {
		req := httptest.NewRequest(http.MethodPost, "/tenants/acme/notes", strings.NewReader(body))
		rec := httptest.NewRecorder()
		mux.ServeHTTP(rec, req)

		if rec.Code != http.StatusBadRequest {
			t.Errorf("POST with body %q = %d, want 400", body, rec.Code)
		}
	}
}

func TestGetNoteWrongTenantIsNotFound(t *testing.T) {
	mux := testMux()

	createReq := httptest.NewRequest(http.MethodPost, "/tenants/tenant-a/notes", strings.NewReader(`{"text":"secret"}`))
	createRec := httptest.NewRecorder()
	mux.ServeHTTP(createRec, createReq)

	var created struct {
		ID string `json:"id"`
	}
	_ = json.Unmarshal(createRec.Body.Bytes(), &created)

	// Same note ID, wrong tenant in the URL — must not leak across tenants.
	getReq := httptest.NewRequest(http.MethodGet, "/tenants/tenant-b/notes/"+created.ID, nil)
	getRec := httptest.NewRecorder()
	mux.ServeHTTP(getRec, getReq)

	if getRec.Code != http.StatusNotFound {
		t.Errorf("cross-tenant GET = %d, want 404", getRec.Code)
	}
}

func TestGetNoteUnknownIDIsNotFound(t *testing.T) {
	mux := testMux()

	req := httptest.NewRequest(http.MethodGet, "/tenants/acme/notes/does-not-exist", nil)
	rec := httptest.NewRecorder()
	mux.ServeHTTP(rec, req)

	if rec.Code != http.StatusNotFound {
		t.Errorf("GET unknown note = %d, want 404", rec.Code)
	}
}

func TestListNotesScopedToTenant(t *testing.T) {
	mux := testMux()

	for _, tenant := range []string{"tenant-a", "tenant-a", "tenant-b"} {
		req := httptest.NewRequest(http.MethodPost, "/tenants/"+tenant+"/notes", strings.NewReader(`{"text":"x"}`))
		rec := httptest.NewRecorder()
		mux.ServeHTTP(rec, req)
		if rec.Code != http.StatusCreated {
			t.Fatalf("setup: POST for %s = %d", tenant, rec.Code)
		}
	}

	req := httptest.NewRequest(http.MethodGet, "/tenants/tenant-a/notes", nil)
	rec := httptest.NewRecorder()
	mux.ServeHTTP(rec, req)

	var list []struct {
		TenantID string `json:"tenantId"`
	}
	if err := json.Unmarshal(rec.Body.Bytes(), &list); err != nil {
		t.Fatalf("decoding list response: %v", err)
	}
	if len(list) != 2 {
		t.Fatalf("List(tenant-a) returned %d notes, want 2", len(list))
	}
	for _, n := range list {
		if n.TenantID != "tenant-a" {
			t.Errorf("List(tenant-a) leaked note from tenant %q", n.TenantID)
		}
	}
}

func TestMetricsEndpointReflectsTraffic(t *testing.T) {
	mux := testMux()

	req := httptest.NewRequest(http.MethodGet, "/tenants/acme/notes", nil)
	mux.ServeHTTP(httptest.NewRecorder(), req)

	metricsReq := httptest.NewRequest(http.MethodGet, "/metrics", nil)
	metricsRec := httptest.NewRecorder()
	mux.ServeHTTP(metricsRec, metricsReq)

	if metricsRec.Code != http.StatusOK {
		t.Fatalf("GET /metrics = %d, want 200", metricsRec.Code)
	}
	body := metricsRec.Body.String()
	if !strings.Contains(body, `http_requests_total{method="GET",route="/tenants/{tenantID}/notes",status="200"} 1`) {
		t.Errorf("expected /metrics to reflect the GET /tenants/{tenantID}/notes request:\n%s", body)
	}
}

func TestProbesAreNotInstrumented(t *testing.T) {
	// healthz/readyz are deliberately excluded from metrics (see newMux) —
	// confirm that stays true rather than silently regressing.
	mux := testMux()

	for i := 0; i < 3; i++ {
		req := httptest.NewRequest(http.MethodGet, "/healthz", nil)
		mux.ServeHTTP(httptest.NewRecorder(), req)
	}

	metricsReq := httptest.NewRequest(http.MethodGet, "/metrics", nil)
	metricsRec := httptest.NewRecorder()
	mux.ServeHTTP(metricsRec, metricsReq)

	if strings.Contains(metricsRec.Body.String(), `route="/healthz"`) {
		t.Error("expected /healthz to be absent from /metrics, probes are not instrumented")
	}
}
