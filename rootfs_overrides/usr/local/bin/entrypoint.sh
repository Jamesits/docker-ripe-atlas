#!/usr/bin/env bash
set -Eeuo pipefail

CONFIG_FILE="/etc/ripe-atlas/config.txt"
declare -a OPTIONS=(
	"RXTXRPT"
	"HTTP_POST_PORT"
	"TELNETD_PORT"
)
ATLAS_UID="${ATLAS_UID:-101}"
ATLAS_MEAS_UID="${ATLAS_MEAS_UID:-102}"
ATLAS_GID="${ATLAS_GID:-999}"

# test essential syscalls
if ! sleep 0 >/dev/null 2>&1; then
	>&2 printf "WARNING: clock_nanosleep or clock_nanosleep_time64 is not available on the system\n"
fi

# detect legacy volume mounts
if [ -d "/var/atlas-probe" ]; then
	>&2 printf "WARNING: You are using a legacy volume mount. Please migrate your configuration.\n"
	# I considered using symlinks, but symlink might destroy the destination files if both legacy volumes and new volumes are mounted.
	cp -rv /var/atlas-probe/etc/. /etc/ripe-atlas/ || true
fi

# create essential files and fix permission
chmod 775 -- /run/ripe-atlas || true
chown ripe-atlas-measurement:ripe-atlas -- /run/ripe-atlas || true
chmod 2775 -- /var/spool/ripe-atlas || true
chown ripe-atlas:ripe-atlas -- /var/spool/ripe-atlas || true
chmod 755 -- /etc/ripe-atlas || true
chown ripe-atlas:ripe-atlas -- /etc/ripe-atlas || true

# set probe configuration
echo "prod" > "/etc/ripe-atlas/mode"
echo "CHECK_ATLASDATA_TMPFS=no" > "${CONFIG_FILE}"
for OPT in "${OPTIONS[@]}"; do
	if [ ! -z "${!OPT+x}" ]; then
		echo "Option ${OPT}=${!OPT}"
		echo "${OPT}=${!OPT}" >> "${CONFIG_FILE}"
	fi
done

if [ "$1" = "ripe-atlas" ]; then
	exec setpriv --reuid=$ATLAS_UID --regid=$ATLAS_GID --init-groups "$@"
else
	exec "$@"
fi
