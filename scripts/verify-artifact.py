"""Verify a completed native build before producing its downloadable archive."""
import hashlib
import json
from pathlib import Path
import struct
import sys

root = Path(sys.argv[1])
commit = '8f1f561d203201f9f19e832374813f46cfe0dc29'
assert (root / 'exit-code.txt').read_text().strip() == '0', 'Build failed'
state = json.loads((root / 'container-state.json').read_text())
assert state['Status'] == 'exited' and not state['OOMKilled']
assert state['ExitCode'] == 0, 'Container did not exit successfully'
assert (root / 'SOURCE_COMMIT').read_text().strip() == commit
binary = root / 'mongod'
with binary.open('rb') as stream:
    header = stream.read(64)
assert header[:6] == b'\x7fELF\x02\x01', 'Not a 64-bit little-endian ELF'
assert struct.unpack_from('<H', header, 18)[0] == 183, 'Not AArch64'
assert binary.stat().st_size > 10_000_000, 'Unexpectedly small mongod'
runtime = (root / 'runtime-check.txt').read_text()
assert 'not found' not in runtime, 'Unresolved runtime library'
assert 'db version v8.0.32' in runtime, 'Incorrect MongoDB version'
info = json.loads(runtime[runtime.index('Build Info:') + len('Build Info:'):].strip())
assert info['version'] == '8.0.32' and info['gitVersion'] == commit
assert info['allocator'] == 'tcmalloc-google', 'Wrong allocator'
proof = (root / 'patched-source-sha256.txt').read_text()
assert '64a1565a2d22e0ca16e518ef166680124ab639294cc72ec8e38d83e9cb6b69b0' in proof
assert '1d7e3c8058992f8bba3032c99a2c127c0d4191caf82f747352039ee43a09f913' in proof
patch = (root / 'va39.patch').read_text()
assert '+inline constexpr int kAddressBits = 39;' in patch
with binary.open('rb') as stream:
    digest = hashlib.file_digest(stream, 'sha256').hexdigest()
result = dict(version='8.0.32', commit=commit, architecture='aarch64',
              allocator=info['allocator'], address_bits=39,
              sha256=digest, bytes=binary.stat().st_size,
              nas_database_validation='NOT PERFORMED')
(root / 'verification.json').write_text(json.dumps(result, indent=2) + '\n', encoding='utf-8')
names = ['mongod', 'SOURCE_COMMIT', 'va39.patch', 'community-build.patch',
         'patched-source-sha256.txt', 'build-options.txt', 'runtime-check.txt', 'verification.json']
lines = []
for name in names:
    with (root / name).open('rb') as stream:
        lines.append(f'{hashlib.file_digest(stream, "sha256").hexdigest()}  {name}\n')
(root / 'SHA256SUMS').write_text(''.join(lines), encoding='utf-8')
print(json.dumps(result, indent=2))
