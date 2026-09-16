package application

import (
	"bytes"
	"encoding/json"
	"errors"
	"io/fs"
	"testing"

	"gameframe/data"
	"gameframe/internal/domain"
	db "gameframe/internal/persistence"
	pb "gameframe/internal/protocol"
	"google.golang.org/protobuf/proto"
)

type testStore struct {
	data []byte
	fail bool
}

func (s *testStore) Load() ([]byte, error) {
	if s.data == nil {
		return nil, fs.ErrNotExist
	}
	return bytes.Clone(s.data), nil
}
func (s *testStore) Save(data []byte) error {
	if s.fail {
		return errors.New("write failed")
	}
	s.data = bytes.Clone(data)
	return nil
}

type testClock struct{ now int64 }

func (c *testClock) Unix() int64 { return c.now }
func newTestRuntime(t *testing.T) (*Runtime, *testStore, *testClock) {
	t.Helper()
	s := &testStore{}
	c := &testClock{now: 100000}
	r, e := New(data.Files, s, c)
	if e != nil {
		t.Fatal(e)
	}
	return r, s, c
}
func command(id, kind string, revision int64) *pb.Command {
	return &pb.Command{ProtocolVersion: ProtocolVersion, Id: id, Type: kind, ExpectedRevision: revision}
}

func isFullUpdate(u *pb.StateUpdate) bool {
	return u != nil && u.Wallet != nil && u.Heroes != nil && u.Equipment != nil && u.Formation != nil && u.Campaign != nil && u.Idle != nil
}

func TestProtoFullAndDirtyModules(t *testing.T) {
	r, _, _ := newTestRuntime(t)
	full := r.Execute(command("full", "snapshot", 0)).Update
	if !isFullUpdate(full) || full.Revision != 1 {
		t.Fatal("incomplete initial state")
	}
	level := command("level", "hero.level_up", 1)
	level.HeroId = 1
	response := r.Execute(level)
	u := response.Update
	if response.Code != "ok" || isFullUpdate(u) || u.Revision != 2 || u.Wallet == nil || u.Heroes == nil || u.Equipment != nil || u.Formation != nil || u.Campaign != nil {
		t.Fatalf("wrong dirty update: %v", response)
	}
	equip := command("equip", "equipment.equip", 2)
	equip.HeroId = 1
	equip.EquipmentId = 101
	response = r.Execute(equip)
	u = response.Update
	if response.Code != "ok" || u.Wallet != nil || u.Heroes == nil || u.Equipment != nil || len(response.Notifications) != 1 {
		t.Fatal("equipment should use hero module + inventory notification")
	}
	patch := response.Notifications[0].Equipment
	if len(patch.Upsert) != 1 || patch.Upsert[0].Id != 101 || patch.Upsert[0].HeroId != 1 {
		t.Fatal("missing owner upsert")
	}
	formation := command("formation", "formation.save", 3)
	formation.Formation = []int32{4, 1, 2, 3, 6}
	u = r.Execute(formation).Update
	if u.Formation == nil || u.Heroes != nil || u.Wallet != nil || isFullUpdate(u) {
		t.Fatal("formation changed unrelated modules")
	}
}

func TestEquipmentDeleteAndUnequipDelta(t *testing.T) {
	r, _, _ := newTestRuntime(t)
	before := clone(r.record.State)
	before.Heroes[0].Equipment = 101
	after := clone(before)
	after.Heroes[0].Equipment = 0
	changes := equipmentChanges(before, after)
	if len(changes.Upsert) != 1 || changes.Upsert[0].HeroId != 0 {
		t.Fatal("zero owner was lost")
	}
	after.Equipment = []int32{102, 103}
	changes = equipmentChanges(before, after)
	if len(changes.DeletedIds) != 1 || changes.DeletedIds[0] != 101 || len(changes.Upsert) != 0 {
		t.Fatal("inventory deletion not represented")
	}
}

func TestSyncRecoveryAndHeartbeat(t *testing.T) {
	r, _, clock := newTestRuntime(t)
	clock.now += 61
	u := r.Execute(command("poll", "state.sync", 1)).Update
	if isFullUpdate(u) || u.Revision != 1 || u.Heroes != nil || u.Wallet != nil || u.Idle.Gold != 61 {
		t.Fatal("heartbeat sent an unnecessary full state")
	}
	u = r.Execute(command("gap", "state.sync", 0)).Update
	if !isFullUpdate(u) || u.Heroes == nil {
		t.Fatal("missing revisions did not recover with full state")
	}
	c := command("stale", "hero.level_up", 0)
	c.HeroId = 1
	result := r.Execute(c)
	if result.Code != "stale_state" || !isFullUpdate(result.Update) || result.Update.Revision != 1 {
		t.Fatal("stale write did not return recovery state")
	}
}

func TestProtoSaveAndReceiptAtomicity(t *testing.T) {
	r, store, clock := newTestRuntime(t)
	c := command("once", "hero.level_up", 1)
	c.HeroId = 1
	before := bytes.Clone(store.data)
	store.fail = true
	if result := r.Execute(c); result.Code != "save_failed" || result.Update.Revision != 1 {
		t.Fatal("failed save was committed")
	}
	if !bytes.Equal(before, store.data) {
		t.Fatal("failed save altered durable record")
	}
	store.fail = false
	first := r.Execute(c)
	if isFullUpdate(first.Update) || first.Update.Heroes.Heroes[0].Level != 2 {
		t.Fatal("retry lost dirty changes")
	}
	envelope := &db.SaveEnvelope{}
	if err := proto.Unmarshal(store.data, envelope); err != nil {
		t.Fatal(err)
	}
	player := &db.PlayerRecord{}
	if err := proto.Unmarshal(envelope.Payload, player); err != nil {
		t.Fatal(err)
	}
	if player.SchemaVersion != saveSchemaVersion || player.Revision != 2 || len(player.Receipts) != 1 || player.Idle.LastClaimAt != 100000 {
		t.Fatal("incomplete persistence transaction")
	}
	restarted, err := New(data.Files, store, clock)
	if err != nil {
		t.Fatal(err)
	}
	if !proto.Equal(first, restarted.Execute(c)) {
		t.Fatal("persisted receipt is not byte-semantically stable")
	}
	first.Update.Heroes.Heroes[0].Level = 99
	if restarted.Execute(c).Update.Heroes.Heroes[0].Level != 2 {
		t.Fatal("caller mutated stored receipt")
	}
	if err = restarted.SaveToDB(); err != nil {
		t.Fatal(err)
	}
}

func TestSaveCorruptionFailsClosed(t *testing.T) {
	_, store, clock := newTestRuntime(t)
	store.data[len(store.data)-1] ^= 1
	corrupted := bytes.Clone(store.data)
	if _, err := New(data.Files, store, clock); err == nil {
		t.Fatal("checksum corruption accepted")
	}
	if !bytes.Equal(corrupted, store.data) {
		t.Fatal("corruption was overwritten with a fresh save")
	}
}

func TestLegacyMigrationKeepsStateAndReceipt(t *testing.T) {
	r, store, clock := newTestRuntime(t)
	c := domain.Command{ID: "old-once", Type: "hero.level_up", HeroID: 1, ExpectedRevision: 1}
	r.record.State.Heroes[0].Level = 2
	r.record.State.Gold -= 35
	r.record.State.Experience -= 25
	r.record.State.Revision = 2
	response := domain.Response{ID: c.ID, OK: true, Code: "ok", Snapshot: &domain.Snapshot{State: clone(r.record.State), ServerTime: clock.Unix()}}
	legacy := map[string]any{"state": r.record.State, "order": []string{c.ID}, "receipts": map[string]any{c.ID: map[string]any{"command": c, "response": response}}}
	raw, err := json.Marshal(legacy)
	if err != nil {
		t.Fatal(err)
	}
	store.data = raw
	store.fail = true
	if _, err = New(data.Files, store, clock); err == nil {
		t.Fatal("migration failure ignored")
	}
	if !bytes.Equal(raw, store.data) {
		t.Fatal("failed migration damaged original")
	}
	store.fail = false
	migrated, err := New(data.Files, store, clock)
	if err != nil {
		t.Fatal(err)
	}
	if bytes.HasPrefix(store.data, []byte("{")) {
		t.Fatal("JSON save was not converted")
	}
	cmd := command(c.ID, c.Type, 1)
	cmd.HeroId = 1
	retry := migrated.Execute(cmd)
	if retry.Code != "ok" || !isFullUpdate(retry.Update) || retry.Update.Revision != 2 || retry.Update.Wallet.Gold != 1165 {
		t.Fatal("legacy idempotency receipt lost")
	}
	if migrated.record.State.Heroes[0].Level != 2 {
		t.Fatal("legacy retry charged twice")
	}
}

func TestWireRejectsUnknownFieldsAndProtocol(t *testing.T) {
	r, _, _ := newTestRuntime(t)
	c := command("read", "snapshot", 0)
	raw, _ := proto.Marshal(c)
	// Unknown field 100, varint value 1. Old JSON and forged balances have no path.
	for _, payload := range [][]byte{append(bytes.Clone(raw), 0xa0, 0x06, 0x01), []byte(`{"type":"snapshot","gold":999999}`), {0xff}} {
		response := &pb.GameResponse{}
		if err := proto.Unmarshal(r.HandleBytes(payload), response); err != nil {
			t.Fatal(err)
		}
		if response.Code != "invalid_request" {
			t.Fatalf("accepted malformed/unknown fields: %v", response)
		}
	}
	c.ProtocolVersion = 99
	if result := r.Execute(c); result.Code != "protocol_mismatch" {
		t.Fatal(result.Code)
	}
}
