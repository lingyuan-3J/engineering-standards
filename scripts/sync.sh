#!/usr/bin/env bash
set -euo pipefail
script_directory="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
source "$script_directory/lib.sh"
repository_url="${1:-https://github.com/lingyuan-3J/engineering-standards.git}"
codex_directory="$(standards_home "${2:-}")"
directory="$codex_directory/standards"
assert_standards_repository "$directory" "$repository_url"
[ -z "$(git -C "$directory" status --porcelain)" ] || { echo 'Uncommitted standards changes found; nothing overwritten.' >&2; exit 1; }
branch="$(git -C "$directory" symbolic-ref --quiet --short HEAD)"
upstream="$(git -C "$directory" rev-parse --abbrev-ref '@{upstream}')"
[ "$upstream" = "origin/$branch" ] || { echo "Unexpected upstream: $upstream" >&2; exit 1; }
git -C "$directory" fetch origin
[ "$(git -C "$directory" rev-list --count "$upstream..HEAD")" -eq 0 ] || { echo 'Local commits are ahead or diverged; resolve before syncing.' >&2; exit 1; }
git -C "$directory" merge --ff-only "$upstream"
update_standards_entry "$codex_directory"
printf 'Synced shared standards: %s. Explicitly reread them in active chats.\n' "$(git -C "$directory" rev-parse --short HEAD)"
