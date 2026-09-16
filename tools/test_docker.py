"""Check the real Compose image with an isolated, disposable save volume."""
from pathlib import Path
import json
import os
import re
import subprocess
import sys
import time
import urllib.request

import websocket

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / 'build/protocol'))
from Command_pb2 import Command
from GameResponse_pb2 import GameResponse


def main():
    project = 'game-frame-smoke-' + str(time.time_ns())
    assert re.fullmatch(r'game-frame-smoke-\d+', project)
    env = dict(os.environ, GAME_BIND_IP='127.0.0.1', GAME_PORT='0')
    ws = None

    def compose(*arguments, timeout=90):
        return subprocess.check_output(['docker', 'compose', '-p', project, *arguments], cwd=ROOT,
                                       env=env, text=True, encoding='utf-8', timeout=timeout).strip()

    def endpoint():
        return compose('port', 'server', '18080').splitlines()[0]

    def connect(address, token):
        return websocket.create_connection('ws://' + address + '/ws', timeout=5,
                header={'Authorization': 'Bearer ' + token}, subprotocols=['gameframe.v2'],
                suppress_origin=True, http_no_proxy=['127.0.0.1'])

    def execute(command):
        ws.send_binary(command.SerializeToString())
        raw = ws.recv()
        assert isinstance(raw, bytes)
        response = GameResponse.FromString(raw)
        assert response.id == command.id
        return response

    try:
        config = json.loads(compose('config', '--format', 'json'))
        token = Path(config['secrets']['game_token']['file']).read_text(encoding='utf-8').strip()
        compose('up', '-d', '--no-build', '--wait', '--wait-timeout', '45')
        address = endpoint()
        with urllib.request.urlopen('http://' + address + '/health', timeout=3) as response:
            assert response.read() == b'ok'
        identifier = compose('ps', '-q', 'server')
        inspection = json.loads(subprocess.check_output(['docker', 'inspect', identifier], text=True))[0]
        assert inspection['State']['Health']['Status'] == 'healthy'
        assert inspection['Config']['User'] == '10001:10001'
        assert inspection['HostConfig']['ReadonlyRootfs']
        volume = next(m for m in inspection['Mounts'] if m['Destination'] == '/data')
        assert volume['Type'] == 'volume' and volume['Name'].startswith(project + '_')
        try:
            rejected = connect(address, 'invalid-token')
        except websocket.WebSocketBadStatusException as error:
            assert error.status_code == 401
        else:
            rejected.close()
            raise AssertionError('container accepted an invalid token')

        ws = connect(address, token)
        first = execute(Command(protocol_version=2, id='container-initial', type='snapshot'))
        assert first.code == 'ok' and first.update.revision == 1
        command = Command(protocol_version=2, id='container-level', type='hero.level_up',
                          expected_revision=1, hero_id=1)
        committed = execute(command)
        assert committed.code == 'ok' and committed.update.revision == 2
        assert committed.update.heroes.heroes[0].level == 2
        ws.close()
        ws = None

        # Recreate the container, retaining only the named volume. This verifies
        # persistence independently of the old container filesystem and process.
        compose('up', '-d', '--no-build', '--force-recreate', '--wait', '--wait-timeout', '45')
        assert compose('ps', '-q', 'server') != identifier
        ws = connect(endpoint(), token)
        assert execute(command) == committed, 'container recreation lost idempotency receipt'
        current = execute(Command(protocol_version=2, id='container-restored', type='snapshot'))
        assert current.code == 'ok' and current.update.revision == 2
        assert current.update.wallet == committed.update.wallet
        assert current.update.heroes.heroes[0].level == 2
        print('DOCKER PASS: non-root/read-only container, healthcheck, authenticated WebSocket, mutation, named-volume recovery and idempotent replay after recreation.')
    except Exception:
        print(compose('logs', '--no-color', '--tail', '60'), file=sys.stderr)
        raise
    finally:
        if ws is not None:
            ws.close()
        # The generated test project owns all resources removed here. Never use
        # this cleanup command against the user's default game-frame deployment.
        compose('down', '--volumes', '--remove-orphans')


if __name__ == '__main__':
    main()
