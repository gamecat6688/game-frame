# Package: gameframe.protocol

const GDScriptUtils = preload("res://addons/protobuf/proto/GDScriptUtils.gd")
const Message = preload("res://addons/protobuf/proto/Message.gd")
const Wire = preload("res://protobuf/runtime/wire.gd")
const CampaignState = preload("res://protobuf/generated/api/gamestate/campaign/CampaignState.proto.gd").CampaignState
const EquipmentState = preload("res://protobuf/generated/api/gamestate/equipment/EquipmentState.proto.gd").EquipmentState
const FormationState = preload("res://protobuf/generated/api/gamestate/formation/FormationState.proto.gd").FormationState
const HeroesState = preload("res://protobuf/generated/api/gamestate/heroes/HeroesState.proto.gd").HeroesState
const IdleState = preload("res://protobuf/generated/api/gamestate/idle/IdleState.proto.gd").IdleState
const WalletState = preload("res://protobuf/generated/api/gamestate/wallet/WalletState.proto.gd").WalletState

class StateUpdate extends Message:
	#1 : revision
	var revision: int = 0

	#2 : config_version
	var config_version: String = ""

	#3 : server_time
	var server_time: int = 0

	#4 : wallet
	var wallet: WalletState = null

	#5 : heroes
	var heroes: HeroesState = null

	#6 : equipment
	var equipment: EquipmentState = null

	#7 : formation
	var formation: FormationState = null

	#8 : campaign
	var campaign: CampaignState = null

	#9 : idle
	var idle: IdleState = null


	## Init message field values to default value
	func Init() -> void:
		self.revision = 0
		self.config_version = ""
		self.server_time = 0
		self.wallet = null
		self.heroes = null
		self.equipment = null
		self.formation = null
		self.campaign = null
		self.idle = null

	## Create a new message instance
	## Returns: Message - New message instance
	func New() -> Message:
		var msg = StateUpdate.new()
		return msg

	## Message ProtoName
	## Returns: String - ProtoName
	func ProtoName() -> String:
		return "gameframe.protocol.StateUpdate"

	func MergeFrom(other : Message) -> void:
		if other is StateUpdate:
			self.revision += other.revision
			self.config_version += other.config_version
			self.server_time += other.server_time
			if other.wallet != null:
				if self.wallet == null:
					self.wallet = WalletState.new()
				self.wallet.MergeFrom(other.wallet)
			else:
				self.wallet = null
			if other.heroes != null:
				if self.heroes == null:
					self.heroes = HeroesState.new()
				self.heroes.MergeFrom(other.heroes)
			else:
				self.heroes = null
			if other.equipment != null:
				if self.equipment == null:
					self.equipment = EquipmentState.new()
				self.equipment.MergeFrom(other.equipment)
			else:
				self.equipment = null
			if other.formation != null:
				if self.formation == null:
					self.formation = FormationState.new()
				self.formation.MergeFrom(other.formation)
			else:
				self.formation = null
			if other.campaign != null:
				if self.campaign == null:
					self.campaign = CampaignState.new()
				self.campaign.MergeFrom(other.campaign)
			else:
				self.campaign = null
			if other.idle != null:
				if self.idle == null:
					self.idle = IdleState.new()
				self.idle.MergeFrom(other.idle)
			else:
				self.idle = null
 
	func SerializeToBytes(buffer: PackedByteArray = PackedByteArray()) -> PackedByteArray:
		if self.revision != 0:
			GDScriptUtils.encode_tag(buffer, 1, 3)
			GDScriptUtils.encode_varint(buffer, self.revision)
		if self.config_version != "":
			GDScriptUtils.encode_tag(buffer, 2, 9)
			GDScriptUtils.encode_string(buffer, self.config_version)
		if self.server_time != 0:
			GDScriptUtils.encode_tag(buffer, 3, 3)
			GDScriptUtils.encode_varint(buffer, self.server_time)
		if self.wallet != null:
			GDScriptUtils.encode_tag(buffer, 4, 11)
			GDScriptUtils.encode_message(buffer, self.wallet)
		if self.heroes != null:
			GDScriptUtils.encode_tag(buffer, 5, 11)
			GDScriptUtils.encode_message(buffer, self.heroes)
		if self.equipment != null:
			GDScriptUtils.encode_tag(buffer, 6, 11)
			GDScriptUtils.encode_message(buffer, self.equipment)
		if self.formation != null:
			GDScriptUtils.encode_tag(buffer, 7, 11)
			GDScriptUtils.encode_message(buffer, self.formation)
		if self.campaign != null:
			GDScriptUtils.encode_tag(buffer, 8, 11)
			GDScriptUtils.encode_message(buffer, self.campaign)
		if self.idle != null:
			GDScriptUtils.encode_tag(buffer, 9, 11)
			GDScriptUtils.encode_message(buffer, self.idle)
		return buffer
 
	func ParseFromBytes(data: PackedByteArray) -> int:
		if not Wire.validate(data, {1: 0, 2: 2, 3: 0, 4: 2, 5: 2, 6: 2, 7: 2, 8: 2, 9: 2}):
			return -1

		var size = data.size()
		var pos = 0
 
		while pos < size:
			var tag = GDScriptUtils.decode_tag(data, pos)
			var field_number = tag[GDScriptUtils.VALUE_KEY]
			pos += tag[GDScriptUtils.SIZE_KEY]
 
			match field_number:
				1:
					var field_value = GDScriptUtils.decode_varint(data, pos, self)
					if field_value[GDScriptUtils.SIZE_KEY] <= 0:
						return -1
					self.revision = field_value[GDScriptUtils.VALUE_KEY]
					pos += field_value[GDScriptUtils.SIZE_KEY]
				2:
					var field_value = GDScriptUtils.decode_string(data, pos, self)
					if field_value[GDScriptUtils.SIZE_KEY] <= 0:
						return -1
					self.config_version = field_value[GDScriptUtils.VALUE_KEY]
					pos += field_value[GDScriptUtils.SIZE_KEY]
				3:
					var field_value = GDScriptUtils.decode_varint(data, pos, self)
					if field_value[GDScriptUtils.SIZE_KEY] <= 0:
						return -1
					self.server_time = field_value[GDScriptUtils.VALUE_KEY]
					pos += field_value[GDScriptUtils.SIZE_KEY]
				4:
					if self.wallet == null:
						self.wallet = WalletState.new()
					self.wallet.Init()
					var field_value = Wire.decode_message(data, pos, self.wallet)
					if field_value[GDScriptUtils.SIZE_KEY] <= 0:
						return -1
					self.wallet = field_value[GDScriptUtils.VALUE_KEY]
					pos += field_value[GDScriptUtils.SIZE_KEY]
				5:
					if self.heroes == null:
						self.heroes = HeroesState.new()
					self.heroes.Init()
					var field_value = Wire.decode_message(data, pos, self.heroes)
					if field_value[GDScriptUtils.SIZE_KEY] <= 0:
						return -1
					self.heroes = field_value[GDScriptUtils.VALUE_KEY]
					pos += field_value[GDScriptUtils.SIZE_KEY]
				6:
					if self.equipment == null:
						self.equipment = EquipmentState.new()
					self.equipment.Init()
					var field_value = Wire.decode_message(data, pos, self.equipment)
					if field_value[GDScriptUtils.SIZE_KEY] <= 0:
						return -1
					self.equipment = field_value[GDScriptUtils.VALUE_KEY]
					pos += field_value[GDScriptUtils.SIZE_KEY]
				7:
					if self.formation == null:
						self.formation = FormationState.new()
					self.formation.Init()
					var field_value = Wire.decode_message(data, pos, self.formation)
					if field_value[GDScriptUtils.SIZE_KEY] <= 0:
						return -1
					self.formation = field_value[GDScriptUtils.VALUE_KEY]
					pos += field_value[GDScriptUtils.SIZE_KEY]
				8:
					if self.campaign == null:
						self.campaign = CampaignState.new()
					self.campaign.Init()
					var field_value = Wire.decode_message(data, pos, self.campaign)
					if field_value[GDScriptUtils.SIZE_KEY] <= 0:
						return -1
					self.campaign = field_value[GDScriptUtils.VALUE_KEY]
					pos += field_value[GDScriptUtils.SIZE_KEY]
				9:
					if self.idle == null:
						self.idle = IdleState.new()
					self.idle.Init()
					var field_value = Wire.decode_message(data, pos, self.idle)
					if field_value[GDScriptUtils.SIZE_KEY] <= 0:
						return -1
					self.idle = field_value[GDScriptUtils.VALUE_KEY]
					pos += field_value[GDScriptUtils.SIZE_KEY]
				_:
					return -1

		return pos

	func SerializeToDictionary() -> Dictionary:
		var dict = {}
		dict["revision"] = self.revision
		dict["config_version"] = self.config_version
		dict["server_time"] = self.server_time
		if self.wallet != null:
			dict["wallet"] = self.wallet.SerializeToDictionary()
		if self.heroes != null:
			dict["heroes"] = self.heroes.SerializeToDictionary()
		if self.equipment != null:
			dict["equipment"] = self.equipment.SerializeToDictionary()
		if self.formation != null:
			dict["formation"] = self.formation.SerializeToDictionary()
		if self.campaign != null:
			dict["campaign"] = self.campaign.SerializeToDictionary()
		if self.idle != null:
			dict["idle"] = self.idle.SerializeToDictionary()
		return dict

	func ParseFromDictionary(dict: Dictionary) -> void:
		if dict == null:
			return

		if dict.has("revision"):
			self.revision = dict.get("revision")
		if dict.has("config_version"):
			self.config_version = dict.get("config_version")
		if dict.has("server_time"):
			self.server_time = dict.get("server_time")
		if dict.has("wallet"):
			if self.wallet == null:
				self.wallet = WalletState.new()
			self.wallet.Init()
			self.wallet.ParseFromDictionary(dict.get("wallet"))
		else:
			self.wallet = null
		if dict.has("heroes"):
			if self.heroes == null:
				self.heroes = HeroesState.new()
			self.heroes.Init()
			self.heroes.ParseFromDictionary(dict.get("heroes"))
		else:
			self.heroes = null
		if dict.has("equipment"):
			if self.equipment == null:
				self.equipment = EquipmentState.new()
			self.equipment.Init()
			self.equipment.ParseFromDictionary(dict.get("equipment"))
		else:
			self.equipment = null
		if dict.has("formation"):
			if self.formation == null:
				self.formation = FormationState.new()
			self.formation.Init()
			self.formation.ParseFromDictionary(dict.get("formation"))
		else:
			self.formation = null
		if dict.has("campaign"):
			if self.campaign == null:
				self.campaign = CampaignState.new()
			self.campaign.Init()
			self.campaign.ParseFromDictionary(dict.get("campaign"))
		else:
			self.campaign = null
		if dict.has("idle"):
			if self.idle == null:
				self.idle = IdleState.new()
			self.idle.Init()
			self.idle.ParseFromDictionary(dict.get("idle"))
		else:
			self.idle = null

# =========================================

