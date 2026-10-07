#!/usr/bin/env bash
# Revoke a write credential created by add-writer.sh.
set -euo pipefail

name="${1:?usage: remove-writer.sh <name>}"

cd "$(dirname "$0")/.."
htpasswd=auth/htpasswd
if ! cut -d: -f1 "$htpasswd" | grep -qxF "$name"; then
  echo "no writer named '$name'" >&2
  exit 1
fi

awk -F: -v n="$name" '$1 != n' "$htpasswd" > "$htpasswd.new"
mv "$htpasswd.new" "$htpasswd"
docker compose restart bazel-remote
