#!/usr/bin/env bash
set -Eeuo pipefail

CONFIG_FILE="/etc/ripe-atlas/config.txt"
declare -a OPTIONS=(
	"RXTXRPT"
	"HTTP_POST_PORT"
	"TELNETD_PORT"
)
ENTRYPOINT_DO_NOT_SET_USER="${ENTRYPOINT_DO_NOT_SET_USER:-0}"

# test essential syscalls
if ! sleep 0 >/dev/null 2>&1; then
	>&2 printf "[entrypoint.sh]: WARNING: clock_nanosleep or clock_nanosleep_time64 is not available on the system. You might experience weird behavior.\n"
fi

# detect legacy volume mounts
if [ -d "/var/atlas-probe" ]; then
	>&2 printf "[entrypoint.sh]: WARNING: You are using a legacy volume mount. Please migrate your configuration.\n"
	# I considered using symlinks, but symlink might destroy the destination files if both legacy volumes and new volumes are mounted.
	cp -rv /var/atlas-probe/etc/. /etc/ripe-atlas/ || true
fi

# create essential directories and try to fix their permissions
chmod 775 -- /run/ripe-atlas || true
chown ripe-atlas-measurement:ripe-atlas -- /run/ripe-atlas || true
chmod 2775 -- /var/spool/ripe-atlas || true
chown ripe-atlas:ripe-atlas -- /var/spool/ripe-atlas || true
chmod 755 -- /etc/ripe-atlas || true
chown ripe-atlas:ripe-atlas -- /etc/ripe-atlas || true

# set probe configuration
printf "prod\n" > "/etc/ripe-atlas/mode"
printf "CHECK_ATLASDATA_TMPFS=no\n" > "${CONFIG_FILE}"
for OPT in "${OPTIONS[@]}"; do
	if [ ! -z "${!OPT+x}" ]; then
		>&2 printf "[entrypoint.sh]: Setting option %s=%s\n" "${OPT}" "${!OPT}"
		printf "%s=%s\n" "${OPT}" "${!OPT}" >> "${CONFIG_FILE}"
	fi
done

>&2 printf "[entrypoint.sh]: Done\n"
if [ "$1" = "ripe-atlas" ] && [ "${ENTRYPOINT_DO_NOT_SET_USER}" != "1" ]; then
	exec setpriv --reuid="ripe-atlas" --regid="ripe-atlas" --init-groups --ambient-caps=+NET_RAW -- "$@"
else
	>&2 printf "[entrypoint.sh]: Continuing as the current user\n"
	exec "$@"
fi
