package domain

type Hero struct {
	ID        int32 `json:"id"`
	Level     int32 `json:"level"`
	Equipment int32 `json:"equipment"`
}

type State struct {
	Schema        int     `json:"schema"`
	ConfigVersion string  `json:"config_version"`
	Revision      uint64  `json:"revision"`
	Gold          int64   `json:"gold"`
	Experience    int64   `json:"experience"`
	Stage         int32   `json:"stage"`
	Heroes        []Hero  `json:"heroes"`
	Formation     []int32 `json:"formation"`
	Equipment     []int32 `json:"equipment"`
	IdleAt        int64   `json:"idle_at"`
}

type Command struct {
	ID               string  `json:"id"`
	Type             string  `json:"type"`
	ExpectedRevision uint64  `json:"expected_revision"`
	HeroID           int32   `json:"hero_id"`
	EquipmentID      int32   `json:"equipment_id"`
	Formation        []int32 `json:"formation"`
}

type Event struct {
	Side      string `json:"side"`
	Actor     int    `json:"actor"`
	Target    int    `json:"target"`
	Damage    int64  `json:"damage"`
	Remaining int64  `json:"remaining"`
	SkillID   int32  `json:"skill_id"`
}

type Fighter struct {
	ID      int32 `json:"id"`
	Attack  int64 `json:"attack"`
	Health  int64 `json:"health"`
	Defense int64 `json:"defense"`
	SkillID int32 `json:"skill_id"`
}

type Battle struct {
	Stage      int32     `json:"stage"`
	Victory    bool      `json:"victory"`
	Allies     []Fighter `json:"allies"`
	Enemies    []Fighter `json:"enemies"`
	Events     []Event   `json:"events"`
	Gold       int64     `json:"gold"`
	Experience int64     `json:"experience"`
}

// Snapshot and Response describe the v1 JSON save receipt ONLY. Runtime/network
// responses use protocol.GameResponse with explicit public StateUpdate modules.
type Snapshot struct {
	State
	Stats          []Fighter `json:"stats"`
	IdleGold       int64     `json:"idle_gold"`
	IdleExperience int64     `json:"idle_experience"`
	ServerTime     int64     `json:"server_time"`
}

type Response struct {
	ID       string    `json:"id"`
	OK       bool      `json:"ok"`
	Code     string    `json:"code"`
	Snapshot *Snapshot `json:"snapshot,omitempty"`
	Battle   *Battle   `json:"battle,omitempty"`
}
