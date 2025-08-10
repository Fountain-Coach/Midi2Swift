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
