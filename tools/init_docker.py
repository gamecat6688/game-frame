"""Create the local Compose secret once, without printing or replacing it."""
import argparse
import os
from pathlib import Path
import secrets

root = Path(__file__).resolve().parents[1]
parser = argparse.ArgumentParser()
parser.add_argument('--token-file', type=Path, default=root / 'runtime/docker/game-token')
args = parser.parse_args()
path = args.token_file.resolve()
path.parent.mkdir(parents=True, exist_ok=True)
try:
    # Compose file-backed secrets preserve file permissions; allow the container
    # UID to read its bind-mounted file. The source remains in ignored runtime/.
    descriptor = os.open(path, os.O_WRONLY | os.O_CREAT | os.O_EXCL, 0o644)
except FileExistsError:
    token = path.read_text(encoding='utf-8').strip()
    if not token or len(token.encode()) > 4096 or any(c in token for c in '\r\n\x00'):
        raise SystemExit(f'Existing token file is invalid; fix it explicitly: {path}')
    print(f'Kept existing Docker token: {path}')
else:
    with os.fdopen(descriptor, 'w', encoding='utf-8', newline='\n') as stream:
        stream.write(secrets.token_hex(32) + '\n')
    print(f'Created Docker token: {path}')
