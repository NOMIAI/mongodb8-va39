"""Patch only the pinned MongoDB r8.0.32 AArch64 allocator configuration."""
import hashlib
from pathlib import Path
import sys

path = Path(sys.argv[1])
bits = int(sys.argv[2])
if bits not in (39, 48):
    raise SystemExit('Only the VA39 experiment and VA48 control are supported')
original = path.read_bytes()
expected = '33a20992eb06f9e7b833f4530738f4c558bd6d6b0a1114de96a55d8f13802b48'
normalized = original.replace(b'\r\n', b'\n')
if hashlib.sha256(normalized).hexdigest() != expected:
    raise SystemExit('Source hash mismatch: re-review the pinned version before patching')
old = b'''#elif defined __aarch64__ && defined __linux__
// According to Documentation/arm64/memory.txt of kernel 3.16,
// AARCH64 kernel supports 48-bit virtual addresses for both user and kernel.
inline constexpr int kAddressBits = 48;'''
if b'\r\n' in original:
    old = old.replace(b'\n', b'\r\n')
if original.count(old) != 1:
    raise SystemExit('AArch64 configuration does not match exactly once')
new = old.replace(b'kAddressBits = 48;', f'kAddressBits = {bits};'.encode())
updated = original.replace(old, new, 1)
path.write_bytes(updated)
print(f'AArch64 kAddressBits={bits}; original={expected}; patched={hashlib.sha256(updated).hexdigest()}')
