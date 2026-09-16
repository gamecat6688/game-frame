package application_test

import (
	"errors"
	"fmt"
	"io/fs"
	"reflect"
	"sync"
	"testing"

	"gameframe/data"
	"gameframe/internal/application"
	"gameframe/internal/domain"
	pb "gameframe/internal/protocol"
)

type memoryStore struct {
	bytes []byte
	fail  bool
}

func (s *memoryStore) Load() ([]byte, error) {
	if s.bytes == nil {
		return nil, fs.ErrNotExist
	}
	return append([]byte(nil), s.bytes...), nil
}
func (s *memoryStore) Save(b []byte) error {
	if s.fail {
		return errors.New("disk unavailable")
	}
	s.bytes = append([]byte(nil), b...)
	return nil
}

type fakeClock struct{ now int64 }

func (c *fakeClock) Unix() int64 { return c.now }
func setup(t *testing.T) (*application.Runtime, *memoryStore, *fakeClock) {
	t.Helper()
	store := &memoryStore{}
	clock := &fakeClock{now: 100000}
	r, err := application.New(data.Files, store, clock)
	if err != nil {
		t.Fatal(err)
	}
	return r, store, clock
}
func snapshot(r *application.Runtime) *domain.Snapshot {
	u := r.Execute(&pb.Command{ProtocolVersion: application.ProtocolVersion, Id: "read", Type: "snapshot"}).Update
	s := &domain.Snapshot{State: domain.State{Revision: uint64(u.Revision), ConfigVersion: u.ConfigVersion, Gold: u.Wallet.Gold, Experience: u.Wallet.Experience, Stage: u.Campaign.Stage, Formation: append([]int32(nil), u.Formation.Slots...)}, ServerTime: u.ServerTime, IdleGold: u.Idle.Gold, IdleExperience: u.Idle.Experience}
	for _, h := range u.Heroes.Heroes {
		s.Heroes = append(s.Heroes, domain.Hero{ID: h.Id, Level: h.Level, Equipment: h.Equipment})
		s.Stats = append(s.Stats, domain.Fighter{ID: h.Id, Attack: h.Attack, Health: h.Health, Defense: h.Defense, SkillID: h.SkillId})
	}
	for _, e := range u.Equipment.Items {
		s.Equipment = append(s.Equipment, e.Id)
	}
	return s
}
func send(r *application.Runtime, cmd domain.Command) domain.Response {
	cmd.ExpectedRevision = snapshot(r).Revision
	if cmd.ID == "" {
		cmd.ID = fmt.Sprintf("op-%d", cmd.ExpectedRevision)
	}
	return execute(r, cmd)
}

func TestValidationDoesNotMutateState(t *testing.T) {
	r, _, _ := setup(t)
	before := snapshot(r)
	for _, command := range []domain.Command{
		{Type: "equipment.equip", HeroID: 1, EquipmentID: 103},
		{Type: "hero.level_up", HeroID: 999},
		{Type: "formation.save", Formation: []int32{1, 1, 2, 3, 4}},
		{Type: "formation.save", Formation: []int32{1, 2, 3, 4, 999}},
		{Type: "campaign.report_win"},
	} {
		result := send(r, command)
		if result.OK {
			t.Fatalf("accepted invalid command: %+v", command)
		}
		if !reflect.DeepEqual(before, snapshot(r)) {
			t.Fatal("rejected command changed state")
		}
	}
}

func TestReceiptSurvivesRestartAndRejectsReuse(t *testing.T) {
	r, store, clock := setup(t)
	cmd := domain.Command{ID: "upgrade-once", Type: "hero.level_up", HeroID: 1, ExpectedRevision: 1}
	first := execute(r, cmd)
	if !first.OK {
		t.Fatal(first.Code)
	}
	restarted, err := application.New(data.Files, store, clock)
	if err != nil {
		t.Fatal(err)
	}
	if !reflect.DeepEqual(first, execute(restarted, cmd)) {
		t.Fatal("retry did not return the original receipt")
	}
	if snapshot(restarted).Heroes[0].Level != 2 {
		t.Fatal("duplicate charged twice")
	}
	cmd.HeroID = 2
	if got := execute(restarted, cmd); got.Code != "request_conflict" {
		t.Fatal(got.Code)
	}
}

func TestSaveFailureRollsBackAndCanRetry(t *testing.T) {
	r, store, _ := setup(t)
	before := snapshot(r)
	store.fail = true
	cmd := domain.Command{ID: "disk-retry", Type: "hero.level_up", HeroID: 1, ExpectedRevision: 1}
	if result := execute(r, cmd); result.Code != "save_failed" {
		t.Fatal(result.Code)
	}
	if !reflect.DeepEqual(before, snapshot(r)) {
		t.Fatal("failed persistence committed state")
	}
	store.fail = false
	if result := execute(r, cmd); !result.OK {
		t.Fatal(result.Code)
	}
}

func TestConcurrentRevisionOnlyCommitsOnce(t *testing.T) {
	r, _, _ := setup(t)
	var wg sync.WaitGroup
	results := make(chan domain.Response, 2)
	for i := 0; i < 2; i++ {
		wg.Add(1)
		go func(i int) {
			defer wg.Done()
			results <- execute(r, domain.Command{ID: fmt.Sprintf("concurrent-%d", i), Type: "hero.level_up", HeroID: 1, ExpectedRevision: 1})
		}(i)
	}
	wg.Wait()
	close(results)
	wins := 0
	for response := range results {
		if response.OK {
			wins++
		} else if response.Code != "stale_state" {
			t.Fatal(response.Code)
		}
	}
	if wins != 1 || snapshot(r).Heroes[0].Level != 2 {
		t.Fatal("revision race allowed two commits")
	}
}

func TestIdleUsesAuthorityClockAndCapsTime(t *testing.T) {
	r, _, clock := setup(t)
	initial := snapshot(r)
	clock.now -= 100
	if snapshot(r).IdleGold != 0 {
		t.Fatal("clock rollback rewarded currency")
	}
	clock.now = initial.ServerTime + 86400
	view := snapshot(r)
	if view.IdleGold != 43200 || view.IdleExperience != 21600 {
		t.Fatal("12 hour cap is incorrect")
	}
	claimed := send(r, domain.Command{Type: "idle.claim"})
	if !claimed.OK || claimed.Snapshot.Gold != initial.Gold+43200 {
		t.Fatal("claim did not settle authority accrual")
	}
	if got := send(r, domain.Command{Type: "idle.claim"}); got.Code != "nothing_to_claim" {
		t.Fatal(got.Code)
	}
}

func TestEquipmentOwnershipAndAtomicMove(t *testing.T) {
	r, _, _ := setup(t)
	if got := send(r, domain.Command{Type: "equipment.equip", HeroID: 1, EquipmentID: 101}); !got.OK {
		t.Fatal(got.Code)
	}
	if got := send(r, domain.Command{Type: "equipment.equip", HeroID: 2, EquipmentID: 101}); got.Code != "equipment_in_use" {
		t.Fatal(got.Code)
	}
	if got := send(r, domain.Command{Type: "equipment.equip", HeroID: 1, EquipmentID: 0}); !got.OK {
		t.Fatal(got.Code)
	}
	if got := send(r, domain.Command{Type: "equipment.equip", HeroID: 2, EquipmentID: 101}); !got.OK {
		t.Fatal(got.Code)
	}
	if snapshot(r).Stats[1].Attack != 70 {
		t.Fatal("equipment stat bonus not applied")
	}
}

func TestIndependentHostsProduceSameBattle(t *testing.T) {
	a, _, _ := setup(t)
	b, _, _ := setup(t)
	for _, cmd := range []domain.Command{{Type: "hero.level_up", HeroID: 1}, {Type: "equipment.equip", HeroID: 1, EquipmentID: 101}, {Type: "formation.save", Formation: []int32{4, 1, 2, 3, 6}}, {Type: "campaign.battle"}} {
		x := send(a, cmd)
		y := send(b, cmd)
		if !x.OK || !reflect.DeepEqual(x, y) {
			t.Fatalf("host results differ: %s", cmd.Type)
		}
		if x.Battle != nil && (!x.Battle.Victory || len(x.Battle.Events) == 0) {
			t.Fatal("initial encounter is not playable")
		}
	}
}

func TestProgressionCanCompletePrototype(t *testing.T) {
	r, _, clock := setup(t)
	clock.now += 43200
	if result := send(r, domain.Command{Type: "idle.claim"}); !result.OK {
		t.Fatal(result.Code)
	}
	for id := int32(1); id <= 6; id++ {
		for level := 1; level < 10; level++ {
			if result := send(r, domain.Command{Type: "hero.level_up", HeroID: id}); !result.OK {
				t.Fatal(result.Code)
			}
		}
	}
	for stage := 1; stage <= 6; stage++ {
		result := send(r, domain.Command{Type: "campaign.battle"})
		if !result.OK || !result.Battle.Victory {
			t.Fatalf("cannot complete stage %d", stage)
		}
	}
	if got := send(r, domain.Command{Type: "campaign.battle"}); got.Code != "campaign_complete" {
		t.Fatal(got.Code)
	}
}

func TestCorruptSaveFailsClosed(t *testing.T) {
	store := &memoryStore{bytes: []byte(`{"state":{"schema":99}}`)}
	if _, err := application.New(data.Files, store, &fakeClock{}); err == nil {
		t.Fatal("corrupted save silently reset")
	}
}

// Tests keep a convenient domain view; production hosts exchange protobuf only.
func execute(r *application.Runtime, c domain.Command) domain.Response {
	p := r.Execute(&pb.Command{ProtocolVersion: application.ProtocolVersion, Id: c.ID, Type: c.Type, ExpectedRevision: int64(c.ExpectedRevision), HeroId: c.HeroID, EquipmentId: c.EquipmentID, Formation: c.Formation})
	result := domain.Response{ID: p.Id, OK: p.Code == "ok", Code: p.Code, Snapshot: snapshot(r)}
	if p.Battle != nil {
		b := p.Battle
		result.Battle = &domain.Battle{Stage: b.Stage, Victory: b.Victory, Gold: b.Gold, Experience: b.Experience}
		for _, e := range b.Events {
			result.Battle.Events = append(result.Battle.Events, domain.Event{Side: e.Side, Actor: int(e.Actor), Target: int(e.Target), Damage: e.Damage, Remaining: e.Remaining, SkillID: e.SkillId})
		}
	}
	return result
}
