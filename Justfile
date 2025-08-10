# Use bash shell for portability
set shell := ["bash", "-cu"]

# Project root
ROOT := justfile_directory()

_help:
  @echo "Available recipes:"
  @echo "  build [ARGS...]        # SwiftPM build (sandbox-safe)"
  @echo "  release [ARGS...]      # SwiftPM release build"
  @echo "  test [ARGS...]         # SwiftPM test (sandbox-safe)"
  @echo "  run [ARGS...]          # Run tn (debug) with args"
  @echo "  run-release [ARGS...]  # Run tn (release) with args"
  @echo "  fmt                    # Format sources in-place"
  @echo "  fmt-check              # Check formatting (no changes)"
  @echo "  lint                   # Lint with SwiftLint"
  @echo "  lint-fix               # Autocorrect with SwiftLint"
  @echo "  clean                  # Clean local caches/build"
  @echo "  ci                     # Lint, format-check, build, test"

# Default recipe
default: _help

# Build/test/run via sandbox-safe wrapper
build *ARGS:
  bin/spm build {{ARGS}}

release *ARGS:
  bin/spm release {{ARGS}}

test *ARGS:
  bin/spm test {{ARGS}}

# Run tn by default; pass args to tn
run *ARGS:
  bin/spm run tn {{ARGS}}

run-release *ARGS:
  bin/spm run-release tn {{ARGS}}

# Formatting & linting
fmt:
  bin/format

fmt-check:
  bin/format --check

lint:
  bin/lint

lint-fix:
  bin/lint fix

clean:
  bin/spm clean

# Basic CI pipeline suitable for local runs without escalation
ci:
  bin/format --check
  bin/lint
  bin/spm build
  bin/spm test
