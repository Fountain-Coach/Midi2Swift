# status-quo.md

# Midi2Swift — what we built and why

## At a glance

* **Goal:** turn a concise, data-driven MIDI 2.0 spec (“seeds”) into a type-safe Swift library, verified by tests and built automatically in CI.
* **What we shipped:** a clean CI pipeline, a minimal but working **SwiftGen** generator that emits message types, test scaffolding (including a “golden vectors” smoke test), and release automation.
* **Status:** builds and tests are green locally and in CI; releases now draft automatically.

---

## Problem we’re solving

MIDI 2.0 uses **Universal MIDI Packets (UMP)** with well-defined message layouts. Hand-coding every message struct is repetitive and error-prone. We want to **generate** those Swift types from a machine-readable spec, keep them in sync with the spec over time, and verify that the code matches the spec using tests.

---

## Approach in one pipeline

```
spec/ (seeds) → MatrixBuilder → matrix.json → SwiftGen → Generated Swift
                                         ↘ ContractVerifier ↗
                                      Swift build + test (CI and local)
```

### Components

* **`MatrixBuilder`**
  Reads our spec “seeds” and produces `spec/matrix.json`. For now it writes a **seeds-only matrix** (no PDF parsing yet).
* **`SwiftGen` (MVP)**
  A minimal generator that parses args, reads `matrix.json`, and **emits Swift message types**. Current output: **21 message structs** (UMP/System Common scaffolding).
* **`ContractVerifier`**
  Validates that generated sources and the matrix agree. We run it in **non-strict (development)** mode today, with support for **STRICT\_FULL\_SPEC=1** later when the matrix and generators are complete.
* **Swift package (`swift/Midi2Swift`)**
  Targets like `Core`, `UMP`, `System`, etc. We added a **Generated/** subgroup under `Core` for SwiftGen output.
* **Tests**

  * `AcceptanceGatesTests` (simple “is the test rig alive?” sentinel)
  * `GoldenVectorsSmokeTests` that read **golden JSON vectors** (we fixed path resolution so the test finds `spec/golden` from CI and local runs).

---

## CI/CD we set up

### Build & test (macOS)

* **Runner:** `macos-14-arm64` with **Xcode 16.2 / Swift 6.0.3**.
* **Order of operations:**

  1. **Clean caches** to avoid SDK mismatches (we had a failure from committed `.build/` artifacts).
  2. `swift build -c debug` in `tools/` to build **MatrixBuilder**, **SwiftGen**, **ContractVerifier**.
  3. Run **MatrixBuilder** → `spec/matrix.json`.
  4. Run **SwiftGen** → `swift/Midi2Swift/Sources/Core/Generated`.
  5. Run **ContractVerifier** (non-strict).
  6. `swift build` and `swift test` for the package.

### Hardening & hygiene

* **Purged tracked build artifacts** and added repo-level ignores for `.build/` and `.swiftpm` both in the tools and the Swift package to prevent **macOS SDK mismatch** errors.
* Added a CI step to **rm -rf** those directories before each build (“belt & suspenders”).
* **Generator output** lives under `Core/Generated/` and is **ignored by git**; CI re-generates it each run.

### Releases

* **Release Drafter** runs on the default branch and assembles draft notes.
* We cut **v0.1.0** and created a **draft v0.1.1**. Publishing is a one-liner with `gh release edit <tag> --draft=false`.

---

## What changed compared to where we started

1. **From “stubs” to a real generator:**
   `SwiftGen` now actually reads the matrix and emits code (21 messages). It’s simple on purpose and ready to evolve.
2. **CI is stable and deterministic:**
   We removed committed build caches, hardened `.gitignore`, and added a pre-build clean. That fixed the “cannot load module 'System' built with SDK…” failures.
3. **Tests run where they should:**
   The golden vectors test now locates `spec/golden` robustly in **both** local and CI contexts.
4. **Releases are low-friction:**
   Draft notes appear automatically; publishing is explicit.

---

## How to work on it (local quickstart)

```bash
# build the tools
swift build -c debug --package-path tools

# produce the matrix from seeds
tools/.build/debug/MatrixBuilder --in spec --out spec/matrix.json

# (re)generate Swift into the Swift package target
rm -rf swift/Midi2Swift/Sources/Core/Generated
tools/.build/debug/SwiftGen --matrix spec/matrix.json --out swift/Midi2Swift/Sources/Core

# build & test the Swift package
swift build --package-path swift/Midi2Swift
swift test  --package-path swift/Midi2Swift
```

**Tip:** keep `Generated/` out of git; let CI and local builds create it.

---

## Repository layout (relevant bits)

```
.
├── spec/
│   ├── seeds/…              # data-driven spec fragments
│   ├── golden/…             # JSON test vectors
│   └── matrix.json          # built by MatrixBuilder
├── tools/                   # SwiftPM workspace for generators/verifiers
│   └── Sources/
│       ├── MatrixBuilder/
│       ├── SwiftGen/
│       └── ContractVerifier/
└── swift/Midi2Swift/        # the Swift package
    ├── Sources/
    │   └── Core/
    │       └── Generated/   # SwiftGen output (gitignored)
    └── Tests/
        └── AcceptanceGatesTests/
```

---

## Troubleshooting notes we already hit (and fixed)

* **“cannot load module 'System' built with SDK 'macosx15.5'…”**
  Cause: stale `.build/` artifacts were committed.
  Fix: purge tracked `.build/`/`.swiftpm`, hard-ignore them, and **clean in CI** before building.

* **“Could not find Package.swift in this directory”**
  Cause: running `swift build` in the repo root.
  Fix: specify `--package-path` (e.g., `swift build --package-path swift/Midi2Swift`).

* **Golden vectors not found**
  Cause: path resolution assumed a local path only.
  Fix: search ancestor directories for `spec/golden` so both local and CI runs pass.

* **Generator writing to a non-target path**
  Fix: point SwiftGen to `swift/Midi2Swift/Sources/Core` and use a `Generated` folder under an actual target.

---

## Why generate code at build time?

* **Single source of truth:** the spec seeds and matrix define layouts.
* **Consistency & safety:** generated structs reduce hand-written mistakes.
* **Velocity:** as the spec evolves, we regenerate rather than refactor by hand.
* **Reviewability:** we treat generated code as a build artifact; PRs focus on **spec** and **generator** changes.

---

## What’s next

* **Fill out the matrix**: expand beyond seeds to cover all UMP32/64 containers and System Common details.
* **Richer SwiftGen**: emit full encoders/decoders, validation, and doc comments from the spec.
* **Turn on strict verification**: enable `STRICT_FULL_SPEC=1` in CI once matrix & codegen are complete.
* **More golden tests**: add comprehensive vectors (round-trip, edge cases).
* **SwiftPM plugin (optional)**: replace ad-hoc generator steps with a plugin that runs automatically during builds.
* **Linux CI lane**: add Ubuntu builds to guarantee cross-platform support.

---

## TL;DR

We built a **repeatable, data-driven path** from MIDI 2.0 spec fragments to a **type-safe Swift library**, verified by tests and delivered by CI. The repo now has a working generator, stable builds, passing tests (including golden vectors), and automated release notes—setting the stage for fleshing out the full MIDI 2.0 surface area.
