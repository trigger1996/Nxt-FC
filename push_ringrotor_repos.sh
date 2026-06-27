#!/bin/bash
set -euo pipefail

REMOTE="${REMOTE:-mygithub}"
BRANCH="${BRANCH:-ringrotor-variable-demo}"
DRY_RUN=0

usage() {
	echo "Usage: $0 [--dry-run] [--remote <name>] [--branch <name>]"
	echo
	echo "Push the ring-rotor demo repositories in dependency order:"
	echo "  1. PX4-Autopilot/Tools/simulation/gz"
	echo "  2. PX4-Autopilot"
	echo "  3. Nxt-FC"
}

while [ "$#" -gt 0 ]; do
	case "$1" in
		--dry-run)
			DRY_RUN=1
			shift
			;;
		--remote)
			REMOTE="$2"
			shift 2
			;;
		--branch)
			BRANCH="$2"
			shift 2
			;;
		-h|--help)
			usage
			exit 0
			;;
		*)
			echo "Unknown argument: $1" >&2
			usage >&2
			exit 2
			;;
	esac
done

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

repo_status() {
	local repo_dir="$1"
	git -C "$repo_dir" status --porcelain
}

require_clean() {
	local repo_dir="$1"
	local name="$2"

	if [ -n "$(repo_status "$repo_dir")" ]; then
		echo "Refusing to push $name: working tree has uncommitted changes." >&2
		git -C "$repo_dir" status --short >&2
		exit 1
	fi
}

push_if_needed() {
	local name="$1"
	local repo_dir="$2"

	require_clean "$repo_dir" "$name"

	if ! git -C "$repo_dir" remote get-url "$REMOTE" >/dev/null 2>&1; then
		echo "Skipping $name: remote '$REMOTE' is not configured."
		return
	fi

	local local_sha
	local remote_sha
	local_sha="$(git -C "$repo_dir" rev-parse HEAD)"
	remote_sha="$(git -C "$repo_dir" ls-remote "$REMOTE" "refs/heads/$BRANCH" | awk '{print $1}')"

	if [ "$local_sha" = "$remote_sha" ]; then
		echo "Up to date: $name ($BRANCH @ ${local_sha:0:10})"
		return
	fi

	if [ -z "$remote_sha" ]; then
		echo "Remote branch missing: $name $REMOTE/$BRANCH"
	else
		echo "Pushing $name: ${remote_sha:0:10} -> ${local_sha:0:10}"
	fi

	if [ "$DRY_RUN" -eq 1 ]; then
		git -C "$repo_dir" push --dry-run "$REMOTE" "HEAD:$BRANCH"
	else
		git -C "$repo_dir" push "$REMOTE" "HEAD:$BRANCH"
	fi
}

push_if_needed "PX4-gazebo-models" "$ROOT_DIR/PX4-Autopilot/Tools/simulation/gz"
push_if_needed "PX4-Autopilot" "$ROOT_DIR/PX4-Autopilot"
push_if_needed "Nxt-FC" "$ROOT_DIR"

echo "Done."
