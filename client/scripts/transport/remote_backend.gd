class_name RemoteBackend
extends RefCounted

signal received(payload: PackedByteArray)
signal failed(code: String)
signal opened(reconnected: bool)

const TIMEOUT := 5.0
const MAX_REQUEST_FAILURES := 3
var _peer: WebSocketPeer
var _active := false
var _url := ""
var _token := ""
var _ready := false
var _ever_opened := false
var _pending := PackedByteArray()
var _request_failures := 0
var _connect_elapsed := 0.0
var _request_elapsed := 0.0
var _retry_wait := 0.0
var _backoff := 1.0

func open(url: String, token: String) -> void:
	close()
	_url = url
	_token = token
	_active = true
	_ever_opened = false
	_retry_wait = 0.0
	_backoff = 1.0
	# Connection starts in poll(), after Session has queued its first command.

func close() -> void:
	_active = false
	if _peer != null: _peer.close(-1)
	_peer = null
	_ready = false
	_pending = PackedByteArray()

func is_open() -> bool:
	return _ready and _peer != null and _peer.get_ready_state() == WebSocketPeer.STATE_OPEN

func execute(payload: PackedByteArray) -> void:
	if not _active:
		failed.emit("network_error")
		return
	_pending = payload
	_request_failures = 0
	_request_elapsed = 0.0
	if is_open(): _write_pending()

func acknowledge() -> void:
	_pending = PackedByteArray()
	_request_elapsed = 0.0
	_request_failures = 0

func poll(delta: float) -> void:
	if not _active: return
	if _peer == null:
		_retry_wait -= delta
		if _retry_wait > 0.0: return
		_connect()
		if _peer == null: return
	var peer := _peer
	peer.poll()
	match peer.get_ready_state():
		WebSocketPeer.STATE_CONNECTING:
			_connect_elapsed += delta
			if _connect_elapsed >= TIMEOUT: _disconnected()
		WebSocketPeer.STATE_OPEN:
			if not _ready:
				if peer.get_selected_protocol() != GameProtocol.SUBPROTOCOL:
					_terminal_failure("protocol_mismatch")
					return
				_ready = true
				_backoff = 1.0
				var reconnected := _ever_opened
				_ever_opened = true
				if not _pending.is_empty(): _write_pending()
				if _peer != peer: return
				opened.emit(reconnected)
			while _active and _peer == peer and peer.get_available_packet_count() > 0:
				var payload := peer.get_packet()
				if peer.was_string_packet() or payload.size() > 1048576:
					_terminal_failure("invalid_response")
					return
				received.emit(payload)
			if _peer != peer: return
			if not _pending.is_empty():
				_request_elapsed += delta
				if _request_elapsed >= TIMEOUT: _disconnected()
		WebSocketPeer.STATE_CLOSING, WebSocketPeer.STATE_CLOSED:
			_disconnected()

func _connect() -> void:
	if not (_url.begins_with("ws://") or _url.begins_with("wss://")):
		_terminal_failure("network_error")
		return
	_peer = WebSocketPeer.new()
	_peer.supported_protocols = PackedStringArray([GameProtocol.SUBPROTOCOL])
	_peer.handshake_headers = PackedStringArray(["Authorization: Bearer " + _token])
	_peer.heartbeat_interval = 10.0
	_peer.inbound_buffer_size = 2097152
	_peer.outbound_buffer_size = 131072
	_peer.max_queued_packets = 64
	_connect_elapsed = 0.0
	if _peer.connect_to_url(_url) != OK: _disconnected()

func _write_pending() -> void:
	_request_elapsed = 0.0
	if _peer.send(_pending, WebSocketPeer.WRITE_MODE_BINARY) != OK: _disconnected()

func _disconnected() -> void:
	if _peer != null: _peer.close(-1)
	_peer = null
	_ready = false
	_retry_wait = _backoff
	_backoff = minf(_backoff * 2.0, 8.0)
	if not _pending.is_empty():
		_request_failures += 1
		if _request_failures >= MAX_REQUEST_FAILURES:
			acknowledge()
			failed.emit("network_error")
	# Reconnect in the background even after a request exhausts its retries.

func _terminal_failure(code: String) -> void:
	close()
	failed.emit(code)
