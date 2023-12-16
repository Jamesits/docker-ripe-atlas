#!/usr/bin/env bash
set -Eeuo pipefail

CONFIG_FILE="/var/atlas-probe/state/config.txt"
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
export ATLAS_GID="${ATLAS_GID:-999}"

usermod -u $ATLAS_UID atlas
groupmod -g $ATLAS_GID atlas
chown -R atlas:atlas /var/atlas-probe || true
chown -R atlas:atlas /var/atlasdata || true

# create essential files and fix permission
mkdir -p /var/atlas-probe/status
chown -R atlas:atlas /var/atlas-probe/status || true
mkdir -p /var/atlas-probe/etc
chown -R atlas:atlas /var/atlas-probe/etc || true
mkdir -p /var/atlas-probe/state
chown -R atlas:atlas /var/atlas-probe/state || true
echo "CHECK_ATLASDATA_TMPFS=no" > "${CONFIG_FILE}"

# set probe configuration
for OPT in "${OPTIONS[@]}"; do
	if [ ! -z "${!OPT+x}" ]; then
		echo "Option ${OPT}=${!OPT}"
		echo "${OPT}=${!OPT}" >> "${CONFIG_FILE}"
	fi
done

exec setpriv --reuid=$ATLAS_UID --regid=$ATLAS_GID --init-groups "$@"
