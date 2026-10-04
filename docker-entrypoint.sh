#!/usr/bin/env bash
set -euo pipefail

# Allow runtime override of the bind user UID/GID via PUID/PGID env vars, so
# files named writes to mounted volumes match a host user. This requires the
# container to start as root.

CURRENT_UID="$(id -u bind)"
CURRENT_GID="$(id -g bind)"
DESIRED_UID="${PUID:-$CURRENT_UID}"
DESIRED_GID="${PGID:-$CURRENT_GID}"

if [[ "${DESIRED_GID}" != "${CURRENT_GID}" ]]; then
  echo "Updating bind group GID: ${CURRENT_GID} -> ${DESIRED_GID}" >&2
  groupmod -o -g "${DESIRED_GID}" bind
fi

if [[ "${DESIRED_UID}" != "${CURRENT_UID}" ]]; then
  echo "Updating bind user UID: ${CURRENT_UID} -> ${DESIRED_UID}" >&2
  usermod -o -u "${DESIRED_UID}" bind
fi

# named needs to write to these; mounted volumes may arrive owned by someone else
for dir in /run/named /var/cache/bind /var/lib/bind /var/log/bind; do
  mkdir -p "${dir}"
  if [[ "$(stat -c '%u:%g' "${dir}")" != "${DESIRED_UID}:${DESIRED_GID}" ]]; then
    chown "${DESIRED_UID}:${DESIRED_GID}" "${dir}" || echo "Warning: could not chown ${dir}" >&2
  fi
done

# Generate a unique rndc key on first start (never baked into the image)
if [[ ! -f /etc/bind/rndc.key && -w /etc/bind ]]; then
  echo "Generating /etc/bind/rndc.key" >&2
  rndc-confgen -a -u bind
fi

echo "Starting BIND $(cat /etc/bind9-version)" >&2

# Pass flags straight to named, e.g. "-g -4". Anything else runs as a command.
if [[ $# -eq 0 || "$1" == -* ]]; then
  exec /usr/sbin/named -u "${BIND9_USER:-bind}" "$@"
fi
exec "$@"
