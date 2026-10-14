#!/usr/bin/env bash
set -euo pipefail
repository="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
test_root="$(mktemp -d "${TMPDIR:-/tmp}/engineering-standards-test.XXXXXX")"
cleanup() {
  case "$test_root" in
    "${TMPDIR:-/tmp}"/engineering-standards-test.*) rm -rf -- "$test_root" ;;
    *) echo 'Unsafe test cleanup target.' >&2 ;;
  esac
}
trap cleanup EXIT
origin="$test_root/origin.git"
source_repo="$test_root/source"
profile_directory="$test_root/Codex Home"
git init --bare --initial-branch=main "$origin" >/dev/null
git clone "$origin" "$source_repo" >/dev/null 2>&1
git -C "$source_repo" config user.name 'Standards Test'
git -C "$source_repo" config user.email 'standards-test@example.invalid'
printf '# Test standards\n' > "$source_repo/00-规范目录.md"
git -C "$source_repo" add .
git -C "$source_repo" commit -m 'initial fixture' >/dev/null
git -C "$source_repo" push -u origin main >/dev/null 2>&1
mkdir -p "$profile_directory"
printf '# Personal instructions\nKeep these unchanged.\n' > "$profile_directory/AGENTS.md"
bash "$repository/scripts/install.sh" "$origin" "$profile_directory" >/dev/null 2>&1
grep -q 'Keep these unchanged.' "$profile_directory/AGENTS.md"
cp "$profile_directory/AGENTS.md" "$test_root/installed.md"
bash "$repository/scripts/install.sh" "$origin" "$profile_directory" >/dev/null 2>&1
cmp "$profile_directory/AGENTS.md" "$test_root/installed.md"
[ "$(find "$profile_directory/standards-backups" -type f | wc -l | tr -d ' ')" -eq 1 ]
printf '# Remote update\n' > "$source_repo/new-rule.md"
git -C "$source_repo" add .
git -C "$source_repo" commit -m 'remote update' >/dev/null
git -C "$source_repo" push >/dev/null 2>&1
bash "$repository/scripts/sync.sh" "$origin" "$profile_directory" >/dev/null 2>&1
[ -f "$profile_directory/standards/new-rule.md" ]
printf 'preserve draft' > "$profile_directory/standards/local-draft.md"
if bash "$repository/scripts/sync.sh" "$origin" "$profile_directory" >/dev/null 2>&1; then exit 1; fi
[ "$(cat "$profile_directory/standards/local-draft.md")" = 'preserve draft' ]
rm -- "$profile_directory/standards/local-draft.md"
if bash "$repository/scripts/install.sh" "$test_root/wrong.git" "$profile_directory" >/dev/null 2>&1; then exit 1; fi
printf '# Active override\n' > "$profile_directory/AGENTS.override.md"
if bash "$repository/scripts/install.sh" "$origin" "$profile_directory" >/dev/null 2>&1; then exit 1; fi
rm -- "$profile_directory/AGENTS.override.md"
cmp "$profile_directory/AGENTS.md" "$test_root/installed.md"
checkout="$profile_directory/standards"
git -C "$checkout" config user.name 'Standards Test'
git -C "$checkout" config user.email 'standards-test@example.invalid'
printf 'local' > "$checkout/local.md"
git -C "$checkout" add .
git -C "$checkout" commit -m 'local commit' >/dev/null
local_head="$(git -C "$checkout" rev-parse HEAD)"
if bash "$repository/scripts/sync.sh" "$origin" "$profile_directory" >/dev/null 2>&1; then exit 1; fi
printf 'remote' > "$source_repo/remote.md"
git -C "$source_repo" add .
git -C "$source_repo" commit -m 'diverge remote' >/dev/null
git -C "$source_repo" push >/dev/null 2>&1
if bash "$repository/scripts/sync.sh" "$origin" "$profile_directory" >/dev/null 2>&1; then exit 1; fi
[ "$(git -C "$checkout" rev-parse HEAD)" = "$local_head" ]
git -C "$checkout" checkout --detach >/dev/null 2>&1
if bash "$repository/scripts/sync.sh" "$origin" "$profile_directory" >/dev/null 2>&1; then exit 1; fi
echo 'Passed Bash installation, idempotence, backup, fast-forward and local change protection.'
