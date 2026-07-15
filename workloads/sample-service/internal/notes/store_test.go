package notes

import "testing"

func TestCreateAndGet(t *testing.T) {
	s := NewStore()

	n := s.Create("tenant-a", "hello")
	got, err := s.Get("tenant-a", n.ID)
	if err != nil {
		t.Fatalf("Get returned error: %v", err)
	}
	if got.Text != "hello" {
		t.Errorf("Text = %q, want %q", got.Text, "hello")
	}
}

func TestGetWrongTenantIsNotFound(t *testing.T) {
	s := NewStore()

	n := s.Create("tenant-a", "secret")
	if _, err := s.Get("tenant-b", n.ID); err != ErrNotFound {
		t.Errorf("Get with wrong tenant = %v, want ErrNotFound", err)
	}
}

func TestGetUnknownIDIsNotFound(t *testing.T) {
	s := NewStore()

	if _, err := s.Get("tenant-a", "does-not-exist"); err != ErrNotFound {
		t.Errorf("Get with unknown id = %v, want ErrNotFound", err)
	}
}

func TestListOnlyReturnsOwnTenant(t *testing.T) {
	s := NewStore()

	s.Create("tenant-a", "a1")
	s.Create("tenant-a", "a2")
	s.Create("tenant-b", "b1")

	a := s.List("tenant-a")
	if len(a) != 2 {
		t.Fatalf("List(tenant-a) returned %d notes, want 2", len(a))
	}
	for _, n := range a {
		if n.TenantID != "tenant-a" {
			t.Errorf("List(tenant-a) leaked note from tenant %q", n.TenantID)
		}
	}

	b := s.List("tenant-b")
	if len(b) != 1 {
		t.Fatalf("List(tenant-b) returned %d notes, want 1", len(b))
	}
}

func TestListUnknownTenantIsEmptyNotNil(t *testing.T) {
	s := NewStore()

	got := s.List("nobody")
	if got == nil {
		t.Error("List for unknown tenant returned nil, want empty slice (so it JSON-encodes as [] not null)")
	}
	if len(got) != 0 {
		t.Errorf("List for unknown tenant returned %d notes, want 0", len(got))
	}
}
