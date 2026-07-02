# Default project mounted into the container
project_dir := env_var_or_default("PROJECT_DIR", env_var("HOME") + "/src/agent-work-example")

default:
    just --list

build-base:
    docker compose build base

shell-base:
    PROJECT_DIR="{{project_dir}}" docker compose run --rm base bash

build-m2:
    docker compose build m2

shell-m2:
    PROJECT_DIR="{{project_dir}}" docker compose run --rm m2 bash

shell:
    just shell-m2

# Guard: refuse to mount an over-broad directory (home root or filesystem root)
# into the agent sandbox. Resolves relative paths/symlinks first so `.` and `~`
# can't sneak through.
_check-dir dir:
    #!/usr/bin/env bash
    set -euo pipefail
    d="$(cd "{{dir}}" 2>/dev/null && pwd)" || { echo "no such directory: {{dir}}" >&2; exit 1; }
    case "$d" in
      "$HOME"|/|/Users|/home)
        echo "refusing to mount '$d' — pick a specific project dir, not your home or the filesystem root" >&2
        exit 1;;
    esac

# Convenience: override the mounted project directory
# Example:
#   just shell-for ~/src/Macaulay2
#   just shell-for ~/src/worktrees/my-branch
shell-for dir: (_check-dir dir)
    PROJECT_DIR="{{dir}}" docker compose run --rm m2 bash

base-for dir: (_check-dir dir)
    PROJECT_DIR="{{dir}}" docker compose run --rm base bash

build-all:
    docker compose build base m2

# Run once after creating a new home/    
bootstrap-codex:
    docker compose run --rm base bash -lc \
      'curl -fsSL https://chatgpt.com/codex/install.sh | CODEX_NON_INTERACTIVE=1 sh'

check-ai:
    docker compose run --rm base bash -lc 'which codex && codex --version && which claude && claude --version'

codex-for dir: (_check-dir dir)
    PROJECT_DIR="{{dir}}" docker compose run --rm base bash -lc 'cd /workspace && codex'

claude-for dir: (_check-dir dir)
    PROJECT_DIR="{{dir}}" docker compose run --rm base bash -lc 'cd /workspace && claude'
