// Package notes implements a tiny tenant-scoped in-memory notes store.
//
// This is intentionally not backed by a real database — Azure SQL lands in
// a later infra phase. The point of this service is to prove the platform
// (container -> Helm -> AKS -> ArgoCD), not to be a real notes app.
package notes

import (
	"errors"
	"sync"
	"time"
)

var ErrNotFound = errors.New("note not found")

type Note struct {
	ID        string    `json:"id"`
	TenantID  string    `json:"tenantId"`
	Text      string    `json:"text"`
	CreatedAt time.Time `json:"createdAt"`
}

// Store is a tenant-partitioned, in-memory note store. Safe for concurrent use.
type Store struct {
	mu    sync.RWMutex
	byID  map[string]Note
	seq   int
	seqMu sync.Mutex
}

func NewStore() *Store {
	return &Store{byID: make(map[string]Note)}
}

func (s *Store) nextID() string {
	s.seqMu.Lock()
	defer s.seqMu.Unlock()
	s.seq++
	return time.Now().UTC().Format("20060102T150405") + "-" + itoa(s.seq)
}

func itoa(n int) string {
	if n == 0 {
		return "0"
	}
	digits := []byte{}
	for n > 0 {
		digits = append([]byte{byte('0' + n%10)}, digits...)
		n /= 10
	}
	return string(digits)
}

// List returns every note belonging to tenantID, oldest first.
func (s *Store) List(tenantID string) []Note {
	s.mu.RLock()
	defer s.mu.RUnlock()

	out := make([]Note, 0)
	for _, n := range s.byID {
		if n.TenantID == tenantID {
			out = append(out, n)
		}
	}
	return out
}

// Create adds a note scoped to tenantID and returns it.
func (s *Store) Create(tenantID, text string) Note {
	s.mu.Lock()
	defer s.mu.Unlock()

	n := Note{
		ID:        s.nextID(),
		TenantID:  tenantID,
		Text:      text,
		CreatedAt: time.Now().UTC(),
	}
	s.byID[n.ID] = n
	return n
}

// Get returns a note by ID, scoped to tenantID so one tenant can never read
// another tenant's note even if it guesses the ID.
func (s *Store) Get(tenantID, id string) (Note, error) {
	s.mu.RLock()
	defer s.mu.RUnlock()

	n, ok := s.byID[id]
	if !ok || n.TenantID != tenantID {
		return Note{}, ErrNotFound
	}
	return n, nil
}
