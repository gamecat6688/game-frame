"""Real protobuf DLL / WebSocket / persistence / Godot tests, with isolated saves."""
from __future__ import annotations
import argparse
import base64
import ctypes
import hashlib
import json
import os
from pathlib import Path
import socket
import subprocess
import sys
import time
import urllib.error
import urllib.request
import websocket

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / 'build/protocol'))
from Command_pb2 import Command
from GameResponse_pb2 import GameResponse
from playerstate.PlayerRecord_pb2 import PlayerRecord
from storage.SaveEnvelope_pb2 import SaveEnvelope

def is_full(update):
    return all(update.HasField(name) for name in ('wallet', 'heroes', 'equipment', 'formation', 'campaign', 'idle'))


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--godot', required=True)
    parser.add_argument('--headless', action='store_true')
    args = parser.parse_args()
    run = ROOT / 'build' / ('integration-' + str(time.time_ns()))
    run.mkdir(parents=True)
    dll = ctypes.CDLL(str(ROOT / 'client/addons/game_bridge/bin/gamecore.dll'))
    dll.GameCall.argtypes = [ctypes.c_char_p]
    dll.GameCall.restype = ctypes.c_void_p
    dll.GameFree.argtypes = [ctypes.c_void_p]
    dll.GameFree.restype = None
    handles = []

    def call(request):
        pointer = dll.GameCall(json.dumps(request).encode())
        assert pointer, 'null DLL response'
        try:
            return json.loads(ctypes.string_at(pointer))
        finally:
            dll.GameFree(pointer)

    def open_local(path):
        result = call({'op': 'open', 'save_path': str(path)})
        assert result['ok'], result
        handles.append(result['handle'])
        return result['handle']

    def local(handle, command):
        result = call({'op': 'command', 'handle': handle,
                       'payload': base64.b64encode(command.SerializeToString()).decode()})
        assert result['ok'], result
        return GameResponse.FromString(base64.b64decode(result['payload']))

    def command(id, kind, revision=0, **fields):
        return Command(protocol_version=2, id=id, type=kind, expected_revision=revision, **fields)

    with socket.socket() as listener:
        listener.bind(('127.0.0.1', 0))
        port = listener.getsockname()[1]
    url = f'http://127.0.0.1:{port}'
    log = (run / 'server.log').open('w', encoding='utf-8')
    server = None
    ws = None

    def connect(token='prototype-local'):
        return websocket.create_connection(f'ws://127.0.0.1:{port}/ws', timeout=3,
                    header={'Authorization': 'Bearer ' + token}, subprotocols=['gameframe.v2'],
                    suppress_origin=True, http_no_proxy=['127.0.0.1'])

    def start_server():
        process = subprocess.Popen([str(ROOT / 'build/server.exe'), '-listen', f'127.0.0.1:{port}',
                    '-save', str(run / 'server.pb')], cwd=ROOT, stdout=log, stderr=subprocess.STDOUT,
                    creationflags=subprocess.CREATE_NO_WINDOW if os.name == 'nt' else 0)
        for _ in range(80):
            try:
                with urllib.request.urlopen(url + '/health', timeout=0.3) as response:
                    assert response.read() == b'ok'
                return process
            except (OSError, urllib.error.URLError):
                if process.poll() is not None: break
                time.sleep(0.05)
        process.terminate()
        process.wait(timeout=5)
        raise AssertionError('server failed to start')

    def remote_raw(raw):
        ws.send_binary(raw)
        response = ws.recv()
        assert isinstance(response, bytes), 'server must send a binary WebSocket message'
        return GameResponse.FromString(response)

    def remote(cmd):
        return remote_raw(cmd.SerializeToString())

    def canonical(response):
        copy = GameResponse()
        copy.CopyFrom(response)
        copy.update.server_time = 0
        copy.update.idle.gold = 0
        copy.update.idle.experience = 0
        return copy.SerializeToString(deterministic=True)

    try:
        server = start_server()
        ws = connect()
        assert ws.getsubprotocol() == 'gameframe.v2'
        original_socket = ws.sock
        handle = open_local(run / 'offline.pb')
        commands = [command('snapshot-0', 'snapshot'),
                    command('level-1', 'hero.level_up', 1, hero_id=1),
                    command('level-1', 'hero.level_up', 1, hero_id=1),
                    command('equip-1', 'equipment.equip', 2, hero_id=1, equipment_id=101),
                    command('formation-1', 'formation.save', 3, formation=[4, 1, 2, 3, 6]),
                    command('battle-1', 'campaign.battle', 4),
                    command('forged-result', 'campaign.report_win', 5)]
        replies = []
        for cmd in commands:
            a, b = local(handle, cmd), remote(cmd)
            assert canonical(a) == canonical(b), f'host parity failed: {cmd.type}'
            replies.append(a)
        assert is_full(replies[0].update)
        assert not is_full(replies[1].update) and replies[1].update.HasField('heroes')
        assert not replies[1].update.HasField('equipment')
        assert replies[3].notifications[0].equipment.upsert[0].hero_id == 1
        assert not replies[4].update.HasField('wallet')
        assert replies[5].battle.victory and replies[5].battle.events
        assert replies[6].code == 'unknown_command'
        assert not is_full(remote(command('heartbeat', 'state.sync', 5)).update)
        assert is_full(remote(command('gap', 'state.sync', 1)).update)
        raw = command('cheat', 'snapshot').SerializeToString() + b'\xa0\x06\x01'
        assert remote_raw(raw).code == 'invalid_request'
        assert remote_raw(b'\xff').code == 'invalid_request'

        assert ws.sock is original_socket, 'business requests must reuse one connection'
        for raw, opcode, expected_code in [(b'x' * 65537, websocket.ABNF.OPCODE_BINARY, 1009),
                                            ('{"gold":9999999}', websocket.ABNF.OPCODE_TEXT, 1003)]:
            rejected = connect()
            try:
                rejected.send(raw, opcode=opcode)
                kind, data = rejected.recv_data(control_frame=True)
                assert kind == websocket.ABNF.OPCODE_CLOSE and int.from_bytes(data[:2], 'big') == expected_code
            finally:
                rejected.close()
        try:
            invalid = connect(token='wrong')
        except websocket.WebSocketBadStatusException as error:
            assert error.status_code == 401
        else:
            invalid.close()
            raise AssertionError('invalid token accepted')
        try:
            urllib.request.urlopen(urllib.request.Request(url + '/command', data=b''), timeout=3)
        except urllib.error.HTTPError as error:
            assert error.code == 404, 'HTTP game-command route still exists'
        else:
            raise AssertionError('HTTP game-command route still exists')
        before = remote(command('balance', 'snapshot')).update
        assert before.wallet.gold == 1285 and before.revision == 5

        call({'op': 'close', 'handle': handle})
        handles.remove(handle)
        handle = open_local(run / 'offline.pb')
        assert canonical(local(handle, commands[1])) == canonical(replies[1]), 'DLL restart lost receipt'
        ws.close()
        server.terminate()
        server.wait(timeout=5)
        server = start_server()
        ws = connect()
        assert canonical(remote(commands[1])) == canonical(replies[1]), 'server restart lost receipt'
        assert remote(command('after-restart', 'snapshot')).update.revision == 5
        for name in ('offline.pb', 'server.pb'):
            envelope = SaveEnvelope.FromString((run / name).read_bytes())
            assert envelope.sha256 == hashlib.sha256(envelope.payload).digest()
            record = PlayerRecord.FromString(envelope.payload)
            assert record.schema_version == 3 and record.revision == 5 and len(record.receipts) == 4
            assert record.idle.last_claim_at > 0

        # Drop a connection after sending a mutation, deliberately discard its
        # reply, and resend the identical request on a fresh connection.
        lost = command('ws-lost-response', 'hero.level_up', 5, hero_id=2)
        ws.send_binary(lost.SerializeToString())
        for _ in range(100):
            saved = SaveEnvelope.FromString((run / 'server.pb').read_bytes())
            if PlayerRecord.FromString(saved.payload).revision == 6:
                break
            time.sleep(0.01)
        else:
            raise AssertionError('lost-response fixture did not commit')
        ws.shutdown()
        ws = connect()
        recovered = remote(lost)
        assert recovered.code == 'ok' and recovered.id == lost.id and recovered.update.revision == 6
        assert remote(lost) == recovered
        after = remote(command('recovered-state', 'snapshot')).update
        assert after.revision == 6 and after.heroes.heroes[1].level == 2, 'reconnect duplicated mutation'

        # Migrate a real v1 JSON fixture; keep its original file and receipt.
        seed = open_local(run / 'seed.pb')
        old_cmd = command('legacy-level', 'hero.level_up', 1, hero_id=1)
        assert local(seed, old_cmd).code == 'ok'
        view = local(seed, command('legacy-read', 'snapshot')).update
        state = {'schema': 1, 'config_version': view.config_version, 'revision': view.revision,
                 'gold': view.wallet.gold, 'experience': view.wallet.experience, 'stage': view.campaign.stage,
                 'heroes': [{'id': h.id, 'level': h.level, 'equipment': h.equipment} for h in view.heroes.heroes],
                 'formation': list(view.formation.slots), 'equipment': [e.id for e in view.equipment.items],
                 'idle_at': view.server_time}
        old_response = {'id': old_cmd.id, 'ok': True, 'code': 'ok', 'snapshot': dict(state, server_time=view.server_time,
                        idle_gold=view.idle.gold, idle_experience=view.idle.experience)}
        legacy = {'state': state, 'order': [old_cmd.id], 'receipts': {old_cmd.id: {
                    'command': {'id': old_cmd.id, 'type': old_cmd.type, 'expected_revision': 1, 'hero_id': 1},
                    'response': old_response}}}
        original = json.dumps(legacy).encode()
        legacy_path = run / 'migrated.json'
        legacy_path.write_bytes(original)
        migrated = open_local(run / 'migrated.pb')
        assert legacy_path.read_bytes() == original, 'migration changed its JSON source'
        assert (run / 'migrated.pb').exists()
        retry = local(migrated, old_cmd)
        assert retry.code == 'ok' and is_full(retry.update) and retry.update.revision == 2
        assert local(migrated, command('migrated-read', 'snapshot')).update.heroes.heroes[0].level == 2

        def run_godot(script, log_name, extra=(), headless=False):
            invocation = [args.godot, '--path', str(ROOT / 'client'), '--script', script]
            if headless: invocation.insert(1, '--headless')
            if extra: invocation += ['--', *extra]
            result = subprocess.run(invocation, cwd=ROOT, stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
                                    encoding='utf-8', errors='replace', timeout=90)
            (ROOT / 'build' / log_name).write_text(result.stdout, encoding='utf-8')
            print(result.stdout)
            assert result.returncode == 0 and 'ERROR:' not in result.stdout, script + ' failed'

        run_godot('res://tests/state_sync.gd', 'state-sync.log', headless=True)
        run_godot('res://tests/smoke.gd', 'ui-smoke.log',
                  ['--with-server', f'--server-url=ws://127.0.0.1:{port}/ws'], args.headless)
        print('INTEGRATION PASS: protobuf DLL/WebSocket parity, persistent connection, reconnect/replay, binary limits, auth, server/DLL restart, atomic receipts, JSON migration, state resync and static UI.')
    finally:
        if ws is not None: ws.close()
        for handle in handles: call({'op': 'close', 'handle': handle})
        if server is not None and server.poll() is None:
            server.terminate()
            server.wait(timeout=5)
        log.close()

if __name__ == '__main__':
    main()
