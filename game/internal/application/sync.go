package application

import (
	"reflect"
	"sort"

	"gameframe/internal/domain"
	pb "gameframe/internal/protocol"
)

// Dirty modules live inside a transaction. They are discarded only after commit
// or rollback; constructing a response never clears changes before persistence.
type module uint8

const (
	walletModule module = iota
	heroesModule
	equipmentModule
	formationModule
	campaignModule
	idleModule
)

type dirtyModules uint64

func (d *dirtyModules) MakeDirty(modules ...module) {
	for _, m := range modules {
		*d |= 1 << m
	}
}
func (d dirtyModules) IsDirty(m module) bool { return d&(1<<m) != 0 }
func (d *dirtyModules) CleanDirty()          { *d = 0 }

func equipmentView(s domain.State) map[int32]*pb.EquipmentItem {
	items := make(map[int32]*pb.EquipmentItem, len(s.Equipment))
	for _, id := range s.Equipment {
		items[id] = &pb.EquipmentItem{Id: id}
	}
	for _, hero := range s.Heroes {
		if item := items[hero.Equipment]; item != nil {
			item.HeroId = hero.ID
		}
	}
	return items
}
func equipmentChanges(before, after domain.State) *pb.EquipmentChanges {
	a, b := equipmentView(before), equipmentView(after)
	changes := &pb.EquipmentChanges{}
	for id, item := range b {
		old := a[id]
		if old == nil || old.HeroId != item.HeroId {
			changes.Upsert = append(changes.Upsert, item)
		}
	}
	for id := range a {
		if b[id] == nil {
			changes.DeletedIds = append(changes.DeletedIds, id)
		}
	}
	sort.Slice(changes.Upsert, func(i, j int) bool { return changes.Upsert[i].Id < changes.Upsert[j].Id })
	sort.Slice(changes.DeletedIds, func(i, j int) bool { return changes.DeletedIds[i] < changes.DeletedIds[j] })
	return changes
}

func (r *Runtime) stateUpdate(before, after domain.State, dirty dirtyModules, full bool) (*pb.StateUpdate, []*pb.Notification) {
	u := &pb.StateUpdate{Revision: int64(after.Revision), ConfigVersion: after.ConfigVersion, ServerTime: r.clock.Unix()}
	if full || dirty.IsDirty(walletModule) {
		u.Wallet = &pb.WalletState{Gold: after.Gold, Experience: after.Experience}
	}
	if full || dirty.IsDirty(heroesModule) {
		u.Heroes = &pb.HeroesState{}
		for _, h := range after.Heroes {
			stats := r.stats(h)
			u.Heroes.Heroes = append(u.Heroes.Heroes, &pb.HeroState{Id: h.ID, Level: h.Level, Equipment: h.Equipment, Attack: stats.Attack, Health: stats.Health, Defense: stats.Defense, SkillId: stats.SkillID})
		}
	}
	var notifications []*pb.Notification
	if full {
		u.Equipment = &pb.EquipmentState{}
		items := equipmentView(after)
		for _, id := range after.Equipment {
			u.Equipment.Items = append(u.Equipment.Items, items[id])
		}
	} else if dirty.IsDirty(equipmentModule) {
		changes := equipmentChanges(before, after)
		if len(changes.Upsert)+len(changes.DeletedIds) > 0 {
			notifications = append(notifications, &pb.Notification{Equipment: changes})
		}
	}
	if full || dirty.IsDirty(formationModule) {
		u.Formation = &pb.FormationState{Slots: append([]int32(nil), after.Formation...)}
	}
	if full || dirty.IsDirty(campaignModule) {
		u.Campaign = &pb.CampaignState{Stage: after.Stage}
	}
	// Idle is a derived view and can change without a persistent-state revision.
	gold, xp := r.idle(after)
	u.Idle = &pb.IdleState{Gold: gold, Experience: xp}
	return u, notifications
}

func battleView(b *domain.Battle) *pb.Battle {
	if b == nil {
		return nil
	}
	v := &pb.Battle{Stage: b.Stage, Victory: b.Victory, Gold: b.Gold, Experience: b.Experience}
	convert := func(f domain.Fighter) *pb.Fighter {
		return &pb.Fighter{Id: f.ID, Attack: f.Attack, Health: f.Health, Defense: f.Defense, SkillId: f.SkillID}
	}
	for _, f := range b.Allies {
		v.Allies = append(v.Allies, convert(f))
	}
	for _, f := range b.Enemies {
		v.Enemies = append(v.Enemies, convert(f))
	}
	for _, e := range b.Events {
		v.Events = append(v.Events, &pb.BattleEvent{Side: e.Side, Actor: int32(e.Actor), Target: int32(e.Target), Damage: e.Damage, Remaining: e.Remaining, SkillId: e.SkillID})
	}
	return v
}

// assertDirtyCoverage is also exercised by tests to prevent new rules from
// silently changing an unmarked module and leaving the client's model stale.
func dirtyCovers(before, after domain.State, dirty dirtyModules) bool {
	return ((before.Gold == after.Gold && before.Experience == after.Experience) || dirty.IsDirty(walletModule)) &&
		(reflect.DeepEqual(before.Heroes, after.Heroes) || dirty.IsDirty(heroesModule)) &&
		(reflect.DeepEqual(equipmentView(before), equipmentView(after)) || dirty.IsDirty(equipmentModule)) &&
		(reflect.DeepEqual(before.Formation, after.Formation) || dirty.IsDirty(formationModule)) &&
		(before.Stage == after.Stage || dirty.IsDirty(campaignModule)) && (before.IdleAt == after.IdleAt || dirty.IsDirty(idleModule))
}
