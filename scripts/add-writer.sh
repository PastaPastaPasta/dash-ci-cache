#!/usr/bin/env bash
# Create a write credential and print it as "name:password" on stdout.
#
# Store the output as the CCACHE_REMOTE_AUTH secret of the repository that
# should write, e.g.:
#   ssh <cache-host> /srv/dash-ci-cache/scripts/add-writer.sh knst \
#     | gh secret set CCACHE_REMOTE_AUTH -R knst/dash
set -euo pipefail

name="${1:?usage: add-writer.sh <name>}"
if [[ ! "$name" =~ ^[A-Za-z0-9._-]+$ ]]; then
  echo "invalid writer name: $name" >&2
  exit 1
fi

cd "$(dirname "$0")/.."
htpasswd=auth/htpasswd
touch "$htpasswd"
if cut -d: -f1 "$htpasswd" | grep -qxF "$name"; then
  echo "writer '$name' already exists; run remove-writer.sh first to rotate it" >&2
  exit 1
fi

# The password is 192 random bits, so an unsalted SHA-1 entry is as strong as
# bcrypt here, and it keeps per-request verification cheap: bazel-remote checks
# the credential on every upload.
password="$(openssl rand -hex 24)"
hash="$(printf '%s' "$password" | openssl dgst -sha1 -binary | base64)"
echo "${name}:{SHA}${hash}" >> "$htpasswd"
# bazel-remote reads it as uid 1000, whatever umask this shell has.
chmod 0644 "$htpasswd"

docker compose restart bazel-remote >&2
echo "${name}:${password}"
