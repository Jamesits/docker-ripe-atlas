#!/usr/bin/env bash
set -Eeuo pipefail

CONFIG_FILE="/etc/ripe-atlas/config.txt"
declare -a OPTIONS=(
	"RXTXRPT"
	"HTTP_POST_PORT"
	"TELNETD_PORT"
)

# test essential syscalls
if ! sleep 0 >/dev/null 2>&1; then
	>&2 echo "WARNING: clock_nanosleep or clock_nanosleep_time64 is not available on the system"
fi

export ATLAS_UID="${ATLAS_UID:-101}"
export ATLAS_MEAS_UID="${ATLAS_MEAS_UID:-102}"
export ATLAS_GID="${ATLAS_GID:-999}"

usermod -u $ATLAS_UID ripe-atlas
usermod -u $ATLAS_MEAS_UID ripe-atlas-measurement
groupmod -g $ATLAS_GID ripe-atlas

# create essential files and fix permission
mkdir -p /run/ripe-atlas
chmod -R 775 /run/ripe-atlas || true
chown -R ripe-atlas:ripe-atlas /run/ripe-atlas || true
mkdir -p /var/spool/ripe-atlas
chown -R ripe-atlas:ripe-atlas /var/spool/ripe-atlas || true
mkdir -p /etc/ripe-atlas
echo "CHECK_ATLASDATA_TMPFS=no" > "${CONFIG_FILE}"
echo "prod" > "/etc/ripe-atlas/mode"
chown -R ripe-atlas:ripe-atlas /etc/ripe-atlas || true

# set probe configuration
for OPT in "${OPTIONS[@]}"; do
	if [ ! -z "${!OPT+x}" ]; then
		echo "Option ${OPT}=${!OPT}"
		echo "${OPT}=${!OPT}" >> "${CONFIG_FILE}"
	fi
done

exec setpriv --reuid=$ATLAS_UID --regid=$ATLAS_GID --init-groups "$@"
