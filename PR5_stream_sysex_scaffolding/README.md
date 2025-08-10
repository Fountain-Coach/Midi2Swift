# Midi2Swift

**License:** MIT  
**Goal:** A *complete* Swift 6 implementation of the MIDI 2.0 specification generated from the authoritative PDFs in `spec/sources`.  
**Policy:** Either **full-spec** conformance or the **build fails**. No partial builds.

## What’s in here
- `spec/` – canonical spec matrix & sources (SHA-256 of each PDF)
- `tools/` – SwiftPM executables: `MatrixBuilder`, `ContractVerifier`, `SwiftGen`
- `swift/Midi2Swift/` – Swift package: modules Core, UMP, System, ChannelVoice, Stream, MIDI_CI, Profiles, PropertyExchange, ClipFile
- `.github/workflows/ci.yml` – strict CI that fails unless 100% coverage

## One-command check
```bash
make assert-full-spec
# or
STRICT_FULL_SPEC=1 swift test --package-path swift/Midi2Swift
```

## Acceptance gates (must pass)
1. 100% of the specification matrix is present in code *and* tests.
2. All golden vectors & CI/Profiles/PE sequences pass.
3. Reserved-bit & range invariants enforced.
4. No stubs, `fatalError`, `TODO`, or `TBD` in generated sources.
5. Reproducibility: deterministic codegen; PDF SHA-256s recorded.

> Until the matrix is populated and generators are run, tests will fail by design.

## Building the spec matrix locally
```bash
make tools
make matrix   # writes spec/matrix.json from spec/sources/checksums.json
make assert-full-spec
```

## Code generation
```bash
make tools
make matrix
make codegen   # emits generated Swift into swift/Midi2Swift/Sources
make assert-full-spec
```

## Generated artifacts policy
The following files/folders are **generated** and **should not be committed**:
- `spec/matrix.json`, `spec/coverage.json`, `spec/coverage.html`
- `swift/Midi2Swift/Sources/**/Generated/**`

CI enforces this: if any of the above appear as tracked files, the build fails.
Use:
```bash
make clean   # removes generated files
```

## Stream & SysEx scaffolding
This PR adds a **transport-agnostic SysEx sequencer** (`Stream/SysExSequencer.swift`) that splits and rejoins payloads
for SysEx7/SysEx8 chunking. Mapping to UMP words will be wired once the matrix contains the normative layouts.
