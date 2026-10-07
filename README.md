# dash-ci-cache

Shared [ccache](https://ccache.dev) remote storage for
[dashpay/dash](https://github.com/dashpay/dash) CI, served at
`https://cache.thepasta.org`.

CI restores its own GitHub Actions cache first and asks this server only for
objects that cache doesn't have. Trusted runs also write what they compile, so
a pull request can reuse objects its author's fork already built.

## How it works

- [bazel-remote](https://github.com/buchgr/bazel-remote) stores entries under
  `/ac/` (ccache's `bazel` layout) and evicts the least recently used ones once
  the cache reaches `MAX_SIZE_GIB` (default 250).
- Reads are public. The content is compiler output for public source code.
- Writes need HTTP basic auth from `auth/htpasswd`. Each writing repository
  gets its own credential, so one can be revoked without touching the others.
- `cloudflared` connects out to Cloudflare. The host publishes no ports.

On the CI side, dashpay/dash only passes its `CCACHE_REMOTE_AUTH` secret to
push runs and to pull requests whose author, actor and head repository owner
are all allowlisted. Every other run reads only.

## Deploy

On the Proxmox host (unprivileged LXC with Docker, i.e. `nesting=1,keyctl=1`):

```sh
git clone https://github.com/PastaPastaPasta/dash-ci-cache /srv/dash-ci-cache
cd /srv/dash-ci-cache
mkdir -p auth && touch auth/htpasswd
# DATA_DIR defaults to ./data; point it at a dedicated mount instead.
mkdir -p /srv/cache-data && chown 1000:1000 /srv/cache-data
umask 077 && printf 'DATA_DIR=/srv/cache-data\nTUNNEL_TOKEN=<token>\n' > .env
docker compose up -d
```

Keep `DATA_DIR` on its own dataset with compression off: ccache entries are already
zstd-compressed.

Copy `proxmox/ct.fw` to `/etc/pve/firewall/<vmid>.fw` on the host after
filling in your router address and IPv6 prefix. The CT then reaches the
internet but not the LAN.

In Cloudflare Zero Trust, create a tunnel whose public hostname
`cache.thepasta.org` points at `http://bazel-remote:8080`, and put its token in
`.env`.

## Writers

```sh
# Create a credential and store it as the repository's secret.
ssh <cache-host> /srv/dash-ci-cache/scripts/add-writer.sh dashpay-ci \
  | gh secret set CCACHE_REMOTE_AUTH -R dashpay/dash

# Revoke it.
ssh <cache-host> /srv/dash-ci-cache/scripts/remove-writer.sh dashpay-ci
```

A fork without the secret still reads from the cache.

## If something bad was written

Entries can't be traced back to a writer, but everything regenerates on the
next build. Revoke the writer, then:

```sh
docker compose stop bazel-remote && rm -rf /srv/cache-data/* && docker compose start bazel-remote
```

## Checks

```sh
curl -fsS https://cache.thepasta.org/status        # cache size and item count
curl -s -o /dev/null -w '%{http_code}\n' -X PUT --data x \
  https://cache.thepasta.org/ac/$(printf %064d 0)   # 401 without credentials
```
