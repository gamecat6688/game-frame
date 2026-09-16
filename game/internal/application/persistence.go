package application

import (
	"bytes"
	"crypto/sha256"
	"encoding/json"
	"errors"
	"math"

	"gameframe/internal/domain"
	db "gameframe/internal/persistence"
	pb "gameframe/internal/protocol"
	"google.golang.org/protobuf/proto"
)

const saveMagic = "EMBER_PLAYER"
const saveSchemaVersion = 3

func cloneRecord(record Record) Record {
	result := Record{State: clone(record.State), Receipts: make(map[string]Receipt, len(record.Receipts)), Order: append([]string(nil), record.Order...)}
	// Existing receipts are immutable. New receipt values and returned responses
	// are cloned at the boundary, never edited in-place.
	for id, receipt := range record.Receipts {
		result.Receipts[id] = receipt
	}
	return result
}

// SaveToDB persists the current committed record through the configured Store.
// File storage is the prototype backend; a SQL Store can replace it later.
func (r *Runtime) SaveToDB() error {
	r.mu.Lock()
	defer r.mu.Unlock()
	return r.saveRecord(r.record)
}

// Commands pass their candidate record here BEFORE assigning r.record. State
// and exactly-once receipts therefore share one durable commit.
func (r *Runtime) saveRecord(record Record) error {
	s := record.State
	player := &db.PlayerRecord{SchemaVersion: saveSchemaVersion, ConfigVersion: s.ConfigVersion, Revision: int64(s.Revision),
		Wallet: &db.WalletDbo{Gold: s.Gold, Experience: s.Experience}, Heroes: &db.HeroesDbo{},
		Equipment: &db.EquipmentDbo{OwnedIds: s.Equipment}, Formation: &db.FormationDbo{Slots: s.Formation},
		Campaign: &db.CampaignDbo{Stage: s.Stage}, Idle: &db.IdleDbo{LastClaimAt: s.IdleAt}}
	for _, h := range s.Heroes {
		player.Heroes.Heroes = append(player.Heroes.Heroes, &db.HeroDbo{Id: h.ID, Level: h.Level, EquipmentId: h.Equipment})
	}
	for _, id := range record.Order {
		receipt := record.Receipts[id]
		player.Receipts = append(player.Receipts, &db.RequestReceipt{Command: receipt.Command, Response: receipt.Response})
	}
	payload, err := (proto.MarshalOptions{Deterministic: true}).Marshal(player)
	if err != nil {
		return err
	}
	digest := sha256.Sum256(payload)
	raw, err := proto.Marshal(&db.SaveEnvelope{Magic: saveMagic, FormatVersion: 1, Payload: payload, Sha256: digest[:]})
	if err != nil {
		return err
	}
	return r.store.Save(raw)
}

func (r *Runtime) loadRecord(raw []byte) (legacy bool, err error) {
	if len(raw) > 16<<20 {
		return false, errors.New("save exceeds size limit")
	}
	if bytes.HasPrefix(bytes.TrimSpace(raw), []byte("{")) {
		return true, r.loadLegacy(raw)
	}
	envelope := &db.SaveEnvelope{}
	if proto.Unmarshal(raw, envelope) != nil || envelope.Magic != saveMagic || envelope.FormatVersion != 1 {
		return false, errors.New("invalid save envelope")
	}
	digest := sha256.Sum256(envelope.Payload)
	if !bytes.Equal(digest[:], envelope.Sha256) {
		return false, errors.New("save checksum mismatch")
	}
	player := &db.PlayerRecord{}
	if proto.Unmarshal(envelope.Payload, player) != nil || player.SchemaVersion != saveSchemaVersion || player.Revision < 1 || player.Wallet == nil || player.Heroes == nil || player.Equipment == nil || player.Formation == nil || player.Campaign == nil || player.Idle == nil {
		return false, errors.New("invalid player record")
	}
	s := domain.State{Schema: 1, ConfigVersion: player.ConfigVersion, Revision: uint64(player.Revision), Gold: player.Wallet.Gold, Experience: player.Wallet.Experience,
		Stage: player.Campaign.Stage, Formation: player.Formation.Slots, Equipment: player.Equipment.OwnedIds, IdleAt: player.Idle.LastClaimAt}
	for _, h := range player.Heroes.Heroes {
		if h == nil {
			return false, errors.New("nil saved hero")
		}
		s.Heroes = append(s.Heroes, domain.Hero{ID: h.Id, Level: h.Level, Equipment: h.EquipmentId})
	}
	r.record = Record{State: s, Receipts: map[string]Receipt{}}
	if err := r.validateSave(); err != nil {
		return false, err
	}
	if len(player.Receipts) > 64 {
		return false, errors.New("too many receipts")
	}
	for _, receipt := range player.Receipts {
		if receipt.Command == nil || receipt.Response == nil || receipt.Command.Id == "" || receipt.Command.Id != receipt.Response.Id || receipt.Command.ProtocolVersion != ProtocolVersion || len(receipt.Command.ProtoReflect().GetUnknown()) > 0 || receipt.Response.Code != "ok" || len(receipt.Response.ProtoReflect().GetUnknown()) > 0 || receipt.Response.Update == nil || receipt.Response.Update.Revision < 1 || receipt.Response.Update.Revision > player.Revision || r.record.Receipts[receipt.Command.Id].Command != nil {
			return false, errors.New("invalid persisted receipt")
		}
		r.record.Order = append(r.record.Order, receipt.Command.Id)
		r.record.Receipts[receipt.Command.Id] = Receipt{Command: receipt.Command, Response: receipt.Response}
	}
	return false, nil
}

// v1 JSON saves had full snapshots in each receipt. Convert those snapshots to
// full protobuf updates, retaining IDs and parameters so old retries stay safe.
func (r *Runtime) loadLegacy(raw []byte) error {
	var old struct {
		State    domain.State `json:"state"`
		Receipts map[string]struct {
			Command  domain.Command  `json:"command"`
			Response domain.Response `json:"response"`
		} `json:"receipts"`
		Order []string `json:"order"`
	}
	if err := json.Unmarshal(raw, &old); err != nil {
		return err
	}
	r.record = Record{State: old.State, Receipts: map[string]Receipt{}}
	if old.State.Revision > math.MaxInt64 || len(old.Order) > 64 {
		return errors.New("invalid legacy revision or receipts")
	}
	if err := r.validateSave(); err != nil {
		return err
	}
	if len(old.Receipts) != len(old.Order) {
		return errors.New("invalid legacy receipt count")
	}
	for _, id := range old.Order {
		receipt, ok := old.Receipts[id]
		if !ok || id == "" || receipt.Command.ID != id || receipt.Response.ID != id || !receipt.Response.OK || receipt.Response.Code != "ok" || receipt.Response.Snapshot == nil || receipt.Command.ExpectedRevision > math.MaxInt64 || r.record.Receipts[id].Command != nil {
			return errors.New("invalid legacy receipt")
		}
		// Validate historical snapshots before deriving stats from their IDs.
		current := r.record.State
		r.record.State = receipt.Response.Snapshot.State
		err := r.validateSave()
		r.record.State = current
		if err != nil || receipt.Response.Snapshot.Revision > current.Revision {
			return errors.New("invalid legacy snapshot")
		}
		update, _ := r.stateUpdate(domain.State{}, receipt.Response.Snapshot.State, 0, true)
		update.ServerTime = receipt.Response.Snapshot.ServerTime
		update.Idle = &pb.IdleState{Gold: receipt.Response.Snapshot.IdleGold, Experience: receipt.Response.Snapshot.IdleExperience}
		cmd := receipt.Command
		response := &pb.GameResponse{Id: id, Code: receipt.Response.Code, Update: update, Battle: battleView(receipt.Response.Battle)}
		r.record.Receipts[id] = Receipt{Command: &pb.Command{ProtocolVersion: ProtocolVersion, Id: id, Type: cmd.Type, ExpectedRevision: int64(cmd.ExpectedRevision), HeroId: cmd.HeroID, EquipmentId: cmd.EquipmentID, Formation: cmd.Formation}, Response: response}
		r.record.Order = append(r.record.Order, id)
	}
	return nil
}
