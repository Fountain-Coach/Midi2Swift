# Midi2Swift • agent.md

## Mission

Implement and ship a Swift library that encodes/decodes MIDI 2.0 UMP messages. The pipeline is **spec → matrix → SwiftGen → Sources → tests → release** with CI enforcing cleanliness and draft releases.

## Repository map

* `spec/` — inputs and golden vectors (`spec/golden/*.json`)
* `tools/` — SwiftPM workspace for generators

  * `tools/Sources/MatrixBuilder/`
  * `tools/Sources/SwiftGen/`
  * `tools/Sources/ContractVerifier/`
* `swift/Midi2Swift/` — SwiftPM package for the library

  * `Sources/Core/` (place generated code under `Core/Generated/`)
  * `Tests/AcceptanceGatesTests/*`
* `.github/` — CI and release-drafter

## Required environment

* macOS with Xcode 16.2 (Swift 6.0.3) and/or Ubuntu 24.04 with Swift 6.x
* GitHub CLI (`gh`) authenticated
* No build caches tracked in git (`.build`, `.swiftpm`)

## Rules (non-negotiable)

1. **Do not commit** anything under `.build/` or `.swiftpm/`.
2. Generated files live in `swift/Midi2Swift/Sources/Core/Generated/`. Delete this folder before committing changes.
3. When building the library from repo root, always pass `--package-path swift/Midi2Swift`.
4. The generator must be built with `--package-path tools`.
5. Tests must pass locally and in CI before merging.
6. Keep PRs focused (1 feature or area).

---

## Standard routines

### R1: Clean workspace

```
rm -rf swift/Midi2Swift/.build swift/Midi2Swift/.swiftpm tools/.build tools/.swiftpm
git status --porcelain
```

### R2: Build generators

```
swift build -c debug --package-path tools
```

### R3: Produce/refresh matrix

```
tools/.build/debug/MatrixBuilder --in spec --out spec/matrix.json
```

### R4: Run SwiftGen into the correct target

```
rm -rf swift/Midi2Swift/Sources/Core/Generated
tools/.build/debug/SwiftGen --matrix spec/matrix.json --out swift/Midi2Swift/Sources/Core
```

### R5: Build and test the library

```
swift build --package-path swift/Midi2Swift
swift test  --package-path swift/Midi2Swift
```

### R6: Create PR

```
git switch -c <feature-branch>
git add tools/Sources/SwiftGen main.swift spec/matrix.json swift/Midi2Swift/Sources/Core/Generated
git commit -m "<scope>: <concise change>"
git push -u origin <feature-branch>
gh pr create -B main -H <feature-branch> -t "<title>" -b "<why + what + how tested>"
```

### R7: Merge and verify release notes

```
gh pr merge <PR#> --merge --delete-branch
git switch main
git pull --ff-only
gh run list --workflow "Release notes (draft)" --limit 1
gh release list --limit 5
```

Publish when ready:

```
gh release edit <TAG> --draft=false
```

---

## Task playbooks

### T1: Extend matrix coverage (e.g., Channel Voice 1.0)

**Goal:** Add message definitions to `spec/` and `spec/matrix.json`, regenerate sources, tests pass.

Steps:

```
git switch -c feat/matrix-channel-voice-10
swift build -c debug --package-path tools
tools/.build/debug/MatrixBuilder --in spec --out spec/matrix.json
tools/.build/debug/SwiftGen --matrix spec/matrix.json --out swift/Midi2Swift/Sources/Core
swift build --package-path swift/Midi2Swift
swift test  --package-path swift/Midi2Swift
git add spec/matrix.json swift/Midi2Swift/Sources/Core/Generated
git commit -m "matrix: add Channel Voice 1.0 messages; regen sources"
git push -u origin feat/matrix-channel-voice-10
gh pr create -B main -H feat/matrix-channel-voice-10 -t "Matrix: Channel Voice 1.0" -b "Adds definitions and regenerates sources."
```

**Acceptance:** generator emits new structs, compile OK, tests green.

### T2: Upgrade SwiftGen (bitfields, enums, pack/unpack)

**Goal:** Emit strongly-typed fields, packing/unpacking, doc comments.

Steps are same as R2–R6.
**Acceptance:** for covered messages, round-trip pack→unpack matches input (add tests under `AcceptanceGatesTests`).

### T3: Golden vectors for a domain

**Goal:** Add valid and edge-case vectors under `spec/golden`, verify parsing tests.

Steps:

```
git switch -c feat/golden-system-common
git add spec/golden/*.json
git commit -m "golden: add system common vectors"
swift test --package-path swift/Midi2Swift
git push -u origin feat/golden-system-common
gh pr create -B main -H feat/golden-system-common -t "Golden: system common" -b "Adds vectors and smoke test passes."
```

**Acceptance:** new vectors parsed; smoke test passes; extend to round-trip when generator supports encode.

### T4: Enable strict ContractVerifier for a covered area

**Goal:** Turn strict checks ON for areas with complete coverage.

Steps:

```
git switch -c feat/strict-<area>
# flip flag or scope checks in tools/Sources/ContractVerifier
swift build -c debug --package-path tools
.build/debug/ContractVerifier --matrix spec/matrix.json --golden spec/golden --sources ../swift/Midi2Swift/Sources
swift test --package-path swift/Midi2Swift
git add tools/Sources/ContractVerifier
git commit -m "verifier(strict): enable for <area>"
git push -u origin feat/strict-<area>
gh pr create -B main -H feat/strict-<area> -t "Verifier: strict <area>" -b "Strict checks now pass for <area>."
```

### T5: Linux CI lane

**Goal:** Add Ubuntu job mirroring macOS steps.

Files to touch: `.github/workflows/ci.yml`.
**Acceptance:** both jobs green, no path/case-sensitivity issues.

---

## Definition of Done (per PR)

* Generators build; sources regenerate deterministically.
* Library builds; tests pass locally and in CI.
* No `.build/` or `.swiftpm/` files staged.
* Generated code resides only in `Sources/Core/Generated/`.
* PR explains **what**, **why**, **how verified**.

---

## Common pitfalls & fixes

* **“Could not find Package.swift”**
  Run library commands with `--package-path swift/Midi2Swift`.

* **SDK mismatch (e.g., “cannot load module 'System' built with SDK macosx15.5…”)**
  Remove caches locally and in CI:

  ```
  rm -rf swift/Midi2Swift/.build swift/Midi2Swift/.swiftpm tools/.build tools/.swiftpm
  ```

  CI already does this before build.

* **Generated code in wrong location**
  The `--out` for SwiftGen must be `swift/Midi2Swift/Sources/Core`.

* **Golden path missing**
  Golden tests search ancestors for `spec/golden`. Ensure vectors are under `spec/golden/*.json`.

---

## Roadmap (agent priorities)

1. Matrix → Channel Voice 1.0 → Channel Voice 2.0 → System RT/Common → SysEx8 → UMP64 → MIDI-CI.
2. SwiftGen → bitfields/enums → pack/unpack → validations → docs.
3. ContractVerifier → strict per area + round-trip.
4. Golden vectors: 10–20 per area (valid + edge/invalid).
5. Linux CI.

---

## PR title/body templates

**Title:** `SwiftGen: pack/unpack for Channel Voice 1.0`
**Body (short):**

* What: add bitfield packing/unpacking + docs for CV 1.0
* Why: enable round-trip tests and real use
* Test: regenerated sources, added vectors, tests green (macOS+Linux)

