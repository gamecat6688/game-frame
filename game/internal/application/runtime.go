package application

import (
	"encoding/json"
	"errors"
	"io/fs"
	"math"
	"sort"
	"sync"

	"gameframe/internal/domain"
	tables "gameframe/internal/generatedloaders"
	"gameframe/internal/ports"
	pb "gameframe/internal/protocol"
	"google.golang.org/protobuf/proto"
)

type Record struct {
	State    domain.State       `json:"state"`
	Receipts map[string]Receipt `json:"receipts"`
	Order    []string           `json:"order"`
}
type Receipt struct {
	Command  *pb.Command
	Response *pb.GameResponse
}
type Runtime struct {
	mu      sync.Mutex
	catalog *tables.Catalog
	store   ports.Store
	clock   ports.Clock
	record  Record
}

func New(source fs.FS, store ports.Store, clock ports.Clock) (*Runtime, error) {
	catalog, err := tables.Load(source)
	if err != nil {
		return nil, err
	}
	if catalog.Rules.Rows[1] == nil || len(catalog.Hero.Rows) < 5 || len(catalog.Stage.Rows) == 0 {
		return nil, errors.New("invalid catalog")
	}
	rules := catalog.Rules.Rows[1]
	if rules.Version == "" || rules.MaxLevel < 1 || rules.InitialGold < 0 || rules.InitialExperience < 0 || rules.LevelGold < 0 || rules.LevelExperience < 0 || rules.IdleCapSeconds < 0 || rules.IdleGoldPerMinute < 0 || rules.IdleExperiencePerMinute < 0 || rules.AttackPerLevel < 0 || rules.HealthPerLevel < 0 || rules.DefensePerLevel < 0 {
		return nil, errors.New("invalid growth rules")
	}
	for _, h := range catalog.Hero.Rows {
		skill := catalog.Skill.Rows[h.SkillID]
		if h.Attack < 0 || h.Health <= 0 || h.Defense < 0 || skill == nil || skill.Every <= 0 || skill.Multiplier <= 0 {
			return nil, errors.New("invalid hero or skill")
		}
	}
	for id := 1; id <= len(catalog.Stage.Rows); id++ {
		s := catalog.Stage.Rows[int32(id)]
		if s == nil || s.EnemyAttack < 0 || s.EnemyHealth <= 0 || s.EnemyDefense < 0 || s.Gold < 0 || s.Experience < 0 {
			return nil, errors.New("invalid campaign stage")
		}
	}
	r := &Runtime{catalog: catalog, store: store, clock: clock}
	raw, err := store.Load()
	if err == nil {
		legacy, loadErr := r.loadRecord(raw)
		if loadErr != nil {
			return nil, loadErr
		}
		if legacy {
			if err = r.saveRecord(r.record); err != nil {
				return nil, err
			}
		}
	} else if errors.Is(err, fs.ErrNotExist) {
		rule := catalog.Rules.Rows[1]
		r.record = Record{State: domain.State{Schema: 1, ConfigVersion: rule.Version, Revision: 1, Gold: int64(rule.InitialGold), Experience: int64(rule.InitialExperience), Stage: 1, IdleAt: clock.Unix(), Formation: []int32{1, 4, 2, 3, 5}, Equipment: []int32{101, 102, 103}}, Receipts: map[string]Receipt{}}
		ids := make([]int, 0, len(catalog.Hero.Rows))
		for id := range catalog.Hero.Rows {
			ids = append(ids, int(id))
		}
		sort.Ints(ids)
		for _, id := range ids {
			r.record.State.Heroes = append(r.record.State.Heroes, domain.Hero{ID: int32(id), Level: 1})
		}
		if err = r.validateSave(); err != nil {
			return nil, err
		}
		if err = r.saveRecord(r.record); err != nil {
			return nil, err
		}
	} else {
		return nil, err
	}
	if r.record.Receipts == nil {
		r.record.Receipts = map[string]Receipt{}
	}
	return r, nil
}

func (r *Runtime) validateSave() error {
	s := r.record.State
	rule := r.catalog.Rules.Rows[1]
	if s.Schema != 1 || s.ConfigVersion != rule.Version {
		return errors.New("save version incompatible")
	}
	if s.Revision < 1 || s.Revision > math.MaxInt64 || s.IdleAt < 0 || s.Gold < 0 || s.Experience < 0 || s.Stage < 1 || int(s.Stage) > len(r.catalog.Stage.Rows)+1 {
		return errors.New("invalid save state")
	}
	seen := map[int32]bool{}
	owned := map[int32]bool{}
	for _, id := range s.Equipment {
		if r.catalog.Equipment.Rows[id] == nil || owned[id] {
			return errors.New("invalid inventory")
		}
		owned[id] = true
	}
	equipped := map[int32]bool{}
	for _, h := range s.Heroes {
		if r.catalog.Hero.Rows[h.ID] == nil || seen[h.ID] || h.Level < 1 || h.Level > rule.MaxLevel {
			return errors.New("invalid saved hero")
		}
		seen[h.ID] = true
		if h.Equipment != 0 {
			e := r.catalog.Equipment.Rows[h.Equipment]
			if e == nil || equipped[h.Equipment] || !contains(s.Equipment, h.Equipment) || h.Level < e.RequiredLevel {
				return errors.New("invalid saved equipment")
			}
			equipped[h.Equipment] = true
		}
	}
	if len(s.Formation) != 5 {
		return errors.New("invalid formation")
	}
	used := map[int32]bool{}
	for _, id := range s.Formation {
		if !seen[id] || used[id] {
			return errors.New("invalid formation")
		}
		used[id] = true
	}
	return nil
}

func clone[T any](value T) T {
	raw, _ := json.Marshal(value)
	var copied T
	_ = json.Unmarshal(raw, &copied)
	return copied
}
func contains(values []int32, id int32) bool {
	for _, v := range values {
		if v == id {
			return true
		}
	}
	return false
}

func (r *Runtime) Execute(cmd *pb.Command) *pb.GameResponse {
	r.mu.Lock()
	defer r.mu.Unlock()
	if cmd == nil {
		cmd = &pb.Command{}
	}
	fail := func(code string) *pb.GameResponse {
		update, _ := r.stateUpdate(domain.State{}, r.record.State, 0, true)
		return &pb.GameResponse{Id: cmd.Id, Code: code, Update: update}
	}
	if cmd.ProtocolVersion != ProtocolVersion {
		return fail("protocol_mismatch")
	}
	if cmd.Id == "" || len(cmd.Id) > 128 || cmd.ExpectedRevision < 0 || len(cmd.ProtoReflect().GetUnknown()) > 0 {
		return fail("invalid_request")
	}
	if !validArguments(cmd) {
		return fail("invalid_request")
	}
	if cmd.Type == "snapshot" || cmd.Type == "state.sync" {
		full := cmd.Type == "snapshot" || uint64(cmd.ExpectedRevision) != r.record.State.Revision
		update, _ := r.stateUpdate(r.record.State, r.record.State, 0, full)
		return &pb.GameResponse{Id: cmd.Id, Code: "ok", Update: update}
	}
	if receipt, ok := r.record.Receipts[cmd.Id]; ok {
		if !proto.Equal(receipt.Command, cmd) {
			return fail("request_conflict")
		}
		return proto.Clone(receipt.Response).(*pb.GameResponse)
	}
	if uint64(cmd.ExpectedRevision) != r.record.State.Revision {
		return fail("stale_state")
	}
	if r.record.State.Revision == math.MaxInt64 {
		return fail("revision_exhausted")
	}
	next := cloneRecord(r.record)
	dirty := dirtyModules(0)
	intent := domain.Command{ID: cmd.Id, Type: cmd.Type, ExpectedRevision: uint64(cmd.ExpectedRevision), HeroID: cmd.HeroId, EquipmentID: cmd.EquipmentId, Formation: cmd.Formation}
	battle, code := r.apply(&next.State, intent, &dirty)
	if code != "ok" {
		return fail(code)
	}
	if !dirtyCovers(r.record.State, next.State, dirty) {
		return fail("internal_error")
	}
	next.State.Revision++
	update, notifications := r.stateUpdate(r.record.State, next.State, dirty, false)
	response := &pb.GameResponse{Id: cmd.Id, Code: "ok", Update: update, Notifications: notifications, Battle: battleView(battle)}
	next.Receipts[cmd.Id] = Receipt{Command: proto.Clone(cmd).(*pb.Command), Response: response}
	next.Order = append(next.Order, cmd.Id)
	// Old retries remain rejected by expected_revision after receipt eviction.
	if len(next.Order) > 64 {
		delete(next.Receipts, next.Order[0])
		next.Order = next.Order[1:]
	}
	if err := r.saveRecord(next); err != nil {
		return fail("save_failed")
	}
	r.record = next
	dirty.CleanDirty()
	return proto.Clone(response).(*pb.GameResponse)
}

func validArguments(cmd *pb.Command) bool {
	switch cmd.Type {
	case "hero.level_up":
		return cmd.HeroId > 0 && cmd.EquipmentId == 0 && len(cmd.Formation) == 0
	case "equipment.equip":
		return cmd.HeroId > 0 && cmd.EquipmentId >= 0 && len(cmd.Formation) == 0
	case "formation.save":
		return cmd.HeroId == 0 && cmd.EquipmentId == 0
	default:
		return cmd.HeroId == 0 && cmd.EquipmentId == 0 && len(cmd.Formation) == 0
	}
}

func (r *Runtime) apply(s *domain.State, c domain.Command, dirty *dirtyModules) (*domain.Battle, string) {
	rule := r.catalog.Rules.Rows[1]
	index := -1
	for i, h := range s.Heroes {
		if h.ID == c.HeroID {
			index = i
			break
		}
	}
	switch c.Type {
	case "hero.level_up":
		if index < 0 {
			return nil, "invalid_hero"
		}
		h := &s.Heroes[index]
		if h.Level >= rule.MaxLevel {
			return nil, "max_level"
		}
		gold := int64(rule.LevelGold) * int64(h.Level)
		xp := int64(rule.LevelExperience) * int64(h.Level)
		if s.Gold < gold || s.Experience < xp {
			return nil, "insufficient_resources"
		}
		s.Gold -= gold
		s.Experience -= xp
		h.Level++
		dirty.MakeDirty(walletModule, heroesModule)
	case "equipment.equip":
		if index < 0 {
			return nil, "invalid_hero"
		}
		if c.EquipmentID == 0 {
			s.Heroes[index].Equipment = 0
			dirty.MakeDirty(heroesModule, equipmentModule)
			break
		}
		e := r.catalog.Equipment.Rows[c.EquipmentID]
		if e == nil || !contains(s.Equipment, c.EquipmentID) {
			return nil, "invalid_equipment"
		}
		if s.Heroes[index].Level < e.RequiredLevel {
			return nil, "level_required"
		}
		for _, h := range s.Heroes {
			if h.ID != c.HeroID && h.Equipment == c.EquipmentID {
				return nil, "equipment_in_use"
			}
		}
		s.Heroes[index].Equipment = c.EquipmentID
		dirty.MakeDirty(heroesModule, equipmentModule)
	case "formation.save":
		if len(c.Formation) != 5 {
			return nil, "invalid_formation"
		}
		used := map[int32]bool{}
		for _, id := range c.Formation {
			owned := false
			for _, h := range s.Heroes {
				if h.ID == id {
					owned = true
				}
			}
			if !owned || used[id] {
				return nil, "invalid_formation"
			}
			used[id] = true
		}
		s.Formation = append([]int32(nil), c.Formation...)
		dirty.MakeDirty(formationModule)
	case "idle.claim":
		gold, xp := r.idle(*s)
		if gold == 0 && xp == 0 {
			return nil, "nothing_to_claim"
		}
		s.Gold += gold
		s.Experience += xp
		s.IdleAt = r.clock.Unix()
		dirty.MakeDirty(walletModule, idleModule)
	case "campaign.battle":
		stage := r.catalog.Stage.Rows[s.Stage]
		if stage == nil {
			return nil, "campaign_complete"
		}
		b := r.battle(*s)
		if b.Victory {
			s.Gold += b.Gold
			s.Experience += b.Experience
			s.Stage++
			dirty.MakeDirty(walletModule, campaignModule)
		}
		return b, "ok"
	default:
		return nil, "unknown_command"
	}
	return nil, "ok"
}

func (r *Runtime) stats(h domain.Hero) domain.Fighter {
	row := r.catalog.Hero.Rows[h.ID]
	rule := r.catalog.Rules.Rows[1]
	level := int64(h.Level - 1)
	f := domain.Fighter{ID: h.ID, Attack: int64(row.Attack) + level*int64(rule.AttackPerLevel), Health: int64(row.Health) + level*int64(rule.HealthPerLevel), Defense: int64(row.Defense) + level*int64(rule.DefensePerLevel), SkillID: row.SkillID}
	if e := r.catalog.Equipment.Rows[h.Equipment]; e != nil {
		f.Attack += int64(e.Attack)
		f.Health += int64(e.Health)
	}
	return f
}
func (r *Runtime) idle(s domain.State) (int64, int64) {
	elapsed := max(int64(0), r.clock.Unix()-s.IdleAt)
	rule := r.catalog.Rules.Rows[1]
	elapsed = min(elapsed, int64(rule.IdleCapSeconds))
	// A fixed rate avoids retroactively applying a newly unlocked stage multiplier.
	return elapsed * int64(rule.IdleGoldPerMinute) / 60, elapsed * int64(rule.IdleExperiencePerMinute) / 60
}
func (r *Runtime) battle(s domain.State) *domain.Battle {
	stage := r.catalog.Stage.Rows[s.Stage]
	b := &domain.Battle{Stage: s.Stage, Events: []domain.Event{}}
	for _, id := range s.Formation {
		for _, h := range s.Heroes {
			if h.ID == id {
				b.Allies = append(b.Allies, r.stats(h))
			}
		}
	}
	for i := 0; i < 5; i++ {
		b.Enemies = append(b.Enemies, domain.Fighter{ID: int32(i + 1), Attack: int64(stage.EnemyAttack), Health: int64(stage.EnemyHealth), Defense: int64(stage.EnemyDefense)})
	}
	a := clone(b.Allies)
	e := clone(b.Enemies)
	first := func(team []domain.Fighter) int {
		for i, f := range team {
			if f.Health > 0 {
				return i
			}
		}
		return -1
	}
	for round := 1; round <= 40 && first(a) >= 0 && first(e) >= 0; round++ {
		for i := 0; i < 5; i++ {
			if a[i].Health > 0 {
				target := first(e)
				if target < 0 {
					break
				}
				damage := a[i].Attack
				skill := int32(0)
				if sk := r.catalog.Skill.Rows[a[i].SkillID]; sk != nil && int32(round)%sk.Every == 0 {
					damage = damage * int64(sk.Multiplier) / 100
					skill = sk.ID
				}
				damage = max(int64(1), damage-e[target].Defense)
				e[target].Health = max(int64(0), e[target].Health-damage)
				b.Events = append(b.Events, domain.Event{Side: "ally", Actor: i, Target: target, Damage: damage, Remaining: e[target].Health, SkillID: skill})
			}
			if e[i].Health > 0 {
				target := first(a)
				if target < 0 {
					break
				}
				damage := max(int64(1), e[i].Attack-a[target].Defense)
				a[target].Health = max(int64(0), a[target].Health-damage)
				b.Events = append(b.Events, domain.Event{Side: "enemy", Actor: i, Target: target, Damage: damage, Remaining: a[target].Health})
			}
		}
	}
	b.Victory = first(e) < 0
	if b.Victory {
		b.Gold = int64(stage.Gold)
		b.Experience = int64(stage.Experience)
	}
	return b
}
