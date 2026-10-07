#!/usr/bin/env bash
# Revoke a write credential created by add-writer.sh.
set -euo pipefail

name="${1:?usage: remove-writer.sh <name>}"

cd "$(dirname "$0")/.."
htpasswd=auth/htpasswd
if ! grep -q "^${name}:" "$htpasswd"; then
  echo "no writer named '$name'" >&2
  exit 1
fi

grep -v "^${name}:" "$htpasswd" > "$htpasswd.new" || true
mv "$htpasswd.new" "$htpasswd"
docker compose restart bazel-remote
