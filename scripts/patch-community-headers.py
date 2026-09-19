"""Remove unavailable Enterprise labels from the pinned community header manifest."""
from pathlib import Path
import hashlib
import re
import sys
p = Path(sys.argv[1])
raw = p.read_bytes()
normalized = raw.replace(b'\r\n', b'\n')
digest = hashlib.sha256(normalized).hexdigest()
expected_counts = {
    '7acbe912da99095369ef3a2357531dbd8491fb4d1198acff64ea7ce0857ee20e': 89,
    'b531fce26d132624dc90fe9214c93fce97323a2d1777c3d8eba51cd33950ef54': 1,
}
patched_sha = '1d7e3c8058992f8bba3032c99a2c127c0d4191caf82f747352039ee43a09f913'
if digest == patched_sha:
    print('Community header manifest already patched')
    raise SystemExit(0)
if digest not in expected_counts:
    raise SystemExit('Unexpected src/BUILD.bazel hash; review source before patching')
pattern = rb'^        "//src/mongo/db/modules/enterprise[/:][^"\r\n]+",\n'
updated, count = re.subn(pattern, b'', normalized, flags=re.M)
if (count != expected_counts[digest] or hashlib.sha256(updated).hexdigest() != patched_sha
        or b'//src/mongo/db/modules/enterprise' in updated):
    raise SystemExit('Unexpected community header manifest transformation')
if b'\r\n' in raw:
    updated = updated.replace(b'\n', b'\r\n')
p.write_bytes(updated)
print(f'Removed {count} remaining unavailable Enterprise header labels for build_enterprise=False')
