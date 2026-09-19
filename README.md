# MongoDB 8.0.32 ARM64 VA39

Experimental native ARM64 build for Synology DS423. This repository builds only
`install-mongod`; it does not deploy a database or publish a container registry image.
No complete MongoDB validation on the NAS has been performed yet.

## Fixed inputs

- Official MongoDB tag `r8.0.32`, commit `8f1f561d203201f9f19e832374813f46cfe0dc29`.
- Original ARM64 MongoDB runtime from the Xuanyuan mirror, pinned by image digest
  in both Dockerfiles. The image contains MongoDB 8.0.32.
- AArch64 TCMalloc `kAddressBits`: 48 to 39, with original/patched SHA-256 guards.
- Community header manifest: remove 89 unavailable Enterprise header labels,
  also guarded by hashes. This second patch is needed for this pinned community build.
- Upstream Bazel installer and locked dependencies from that source commit.
- GitHub Actions pinned to commit SHAs. APT packages are not snapshot-pinned, so
  the result is not claimed to be bit-for-bit reproducible.

## Run

Open **Actions → MongoDB 8.0.32 ARM64 VA39 → Run workflow** on the default branch.
Only manual dispatch is enabled. Use a public repository's `ubuntu-24.04-arm`
runner (4 vCPU / 16 GB RAM); the preflight rejects x86 and hosts with under roughly
12 GB RAM. This uses native ARM execution, not QEMU. The host need not use VA39;
final behavior on a VA39 NAS must be validated separately.

The initial concurrency is **2**, with a 1536 MiB Bazel Java heap and a 12 GiB
container memory cap. Four CPUs do not prove that four concurrent MongoDB C++
compilations fit in RAM. Increase concurrency only after measuring peak memory.

The command retains `--config=local`, explicit version/commit, community mode,
`--allocator=tcmalloc-google`, `--debug_symbols=False`, and `--fission=no`.
Omitting these can reintroduce previously diagnosed build failures. The existing
PC build already targets only `install-mongod`; narrowing the target is not a new
speedup. The benefit here is native ARM64 execution.

## Cache and limits

The runner checks free space before restoring cache and before compilation.
Source and the builder's home are cached in `.ci-work`, mounted at stable container
paths. Cache keys include the build scripts and Dockerfile; caches from the PC are
not automatically imported. Cache reuse and a successful full build remain to be
verified on GitHub. Cache saves consume the repository's Actions cache quota.

The compilation deadline is five hours after the first preflight, including
restore and environment setup. This reserves time under the six-hour job limit
for stopping the builder, saving cache and uploading evidence. Hard cancellation,
runner loss, a full disk or an upload failure can still prevent cache preservation.
No automatic retry or scheduling is configured. On disk exhaustion or timeout,
keep the evidence and use an adequately sized native ARM64 VM instead of repeatedly
running the same CI configuration. The same container/scripts can be reused there.

## Outputs and verification

Every run attempts to upload `build-evidence-*`, including logs, exit status and
container state. Only a successful compile and verification produces the
`mongodb-8.0.32-arm64-va39` artifact, containing a tarball and its SHA-256.
The tarball preserves executable permissions. Extract it into `out/`, then run
`sha256sum -c SHA256SUMS` from that directory.

Verification checks exited status, no OOM, ELF AArch64, version, source commit,
allocator, patched-source hashes and shared-library resolution in the **original
runtime image**, not just in the compiler container. `Dockerfile.runtime` replaces
only `mongod` and adds build evidence while preserving the upstream entrypoint and
runtime libraries. The workflow builds this image locally but does not push it.

CI success is not NAS acceptance. Before application use, test on the NAS with a
new independent data directory: `buildInfo`, replica set, transaction commit/abort,
indexes, sustained concurrent read/write, restart persistence, crash recovery and
database validation. Then test actual Ayakaleaf document collaboration, history
and LaTeX compilation. Preserve the prior database for rollback.

MongoDB source and derived binaries remain subject to the upstream SSPL and
third-party licenses. This repository is not an official MongoDB release.

## References

- [Pinned MongoDB build instructions](https://github.com/mongodb/mongo/blob/r8.0.32/docs/building.md)
- [GitHub runner specifications](https://docs.github.com/en/actions/reference/runners/github-hosted-runners)
- [Actions time and cache limits](https://docs.github.com/en/actions/reference/limits)
