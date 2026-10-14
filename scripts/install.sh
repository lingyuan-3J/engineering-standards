#!/usr/bin/env bash
set -euo pipefail
script_directory="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
source "$script_directory/lib.sh"
repository_url="${1:-https://github.com/lingyuan-3J/engineering-standards.git}"
codex_directory="$(standards_home "${2:-}")"
command -v git >/dev/null
mkdir -p "$codex_directory"
directory="$codex_directory/standards"
if [ ! -e "$directory" ]; then git clone "$repository_url" "$directory"; fi
assert_standards_repository "$directory" "$repository_url"
update_standards_entry "$codex_directory"
printf 'Installed shared standards: %s (%s). Personal instructions preserved.\n' "$directory" "$(git -C "$directory" rev-parse --short HEAD)"
printf 'Explicitly reread standards in active chats.\n'
