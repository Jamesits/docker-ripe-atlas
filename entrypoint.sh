#!/usr/bin/env bash
set -Eeuo pipefail

CONFIG_FILE="/var/atlas-probe/state/config.txt"
declare -a OPTIONS=(
	"RXTXRPT"
)

# create essential files and fix permission
mkdir -p /var/atlas-probe/status
chown -R atlas:atlas /var/atlas-probe/status
mkdir -p /var/atlas-probe/etc
chown -R atlas:atlas /var/atlas-probe/etc
mkdir -p /var/atlas-probe/state
chown -R atlas:atlas /var/atlas-probe/state
echo "CHECK_ATLASDATA_TMPFS=no" > "${CONFIG_FILE}"

# set probe configuration
for OPT in "${OPTIONS[@]}"; do
	if [ ! -z "${!OPT+x}" ]; then
		echo "Option ${OPT}=${!OPT}"
		echo "${OPT}=${!OPT}" >> "${CONFIG_FILE}"
	fi
done

exec gosu atlas:atlas "$@"

