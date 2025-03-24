#!/usr/bin/env bash
set -Eeuo pipefail

CONFIG_FILE="/etc/ripe-atlas/config.txt"
declare -a OPTIONS=(
	"RXTXRPT"
	"HTTP_POST_PORT"
	"TELNETD_PORT"
)
# When set to 1, the script will ignore all permissions and ownership issues.
ENTRYPOINT_DO_NOT_SET_USER="${ENTRYPOINT_DO_NOT_SET_USER:-0}"
# When set to 1, the script will not write to the config file. You must provide your own config file.
ENTRYPOINT_SKIP_CONFIG_FILE="${ENTRYPOINT_SKIP_CONFIG_FILE:-0}"

# test essential syscalls
if ! sleep 0 >/dev/null 2>&1; then
	>&2 printf "[entrypoint.sh]: WARNING: clock_nanosleep or clock_nanosleep_time64 is not available on the system. You might experience weird behavior.\n"
fi

# detect legacy volume mounts
if [ -d "/var/atlas-probe" ]; then
	>&2 printf "[entrypoint.sh]: WARNING: You are using a legacy volume mount. Please migrate your configuration.\n\tPlease refer to the documentation: https://github.com/Jamesits/docker-ripe-atlas?tab=readme-ov-file#upgrading-from-5080-to-5100-or-later\n"
	sleep 3
	# I considered using symlinks, but symlink might destroy the destination files if both legacy volumes and new volumes are mounted.
	cp -rpnv /var/atlas-probe/etc/. /etc/ripe-atlas/ || [ "${ENTRYPOINT_DO_NOT_SET_USER}" == "1" ]
fi

# create essential directories and try to fix their permissions
function init_dir() {
	if [ -z "$( ls -A "$1" )" ]; then
		>&2 printf "[entrypoint.sh]: Initializing directory %s\n" "$1"
		mkdir -p -- "$1"
		cp -rpv -- "/usr/share/factory/$1/." "$1" || [ "${ENTRYPOINT_DO_NOT_SET_USER}" == "1" ]
	else
		# try to copy missing files only, but do not overwrite existing files
		cp -rpnv -- "/usr/share/factory/$1/." "$1" || [ "${ENTRYPOINT_DO_NOT_SET_USER}" == "1" ]
	fi
	chmod "$2" -- "$1" || [ "${ENTRYPOINT_DO_NOT_SET_USER}" == "1" ]
	chown "$3:$4" -- "$1" || [ "${ENTRYPOINT_DO_NOT_SET_USER}" == "1" ]
}
init_dir "/run/ripe-atlas" "775" "ripe-atlas-measurement" "ripe-atlas"
init_dir "/var/spool/ripe-atlas" "2775" "ripe-atlas" "ripe-atlas"
init_dir "/etc/ripe-atlas" "755" "ripe-atlas" "ripe-atlas"

# set probe configuration
if [ ! -f "/etc/ripe-atlas/mode.atlasswprobe" ]; then
	printf "prod\n" > "/etc/ripe-atlas/mode.atlasswprobe"
fi
if [ "${ENTRYPOINT_SKIP_CONFIG_FILE}" != "1" ]; then
	printf "CHECK_ATLASDATA_TMPFS=no\n" > "${CONFIG_FILE}"
	for OPT in "${OPTIONS[@]}"; do
		if [ ! -z "${!OPT+x}" ]; then
			>&2 printf "[entrypoint.sh]: Setting option %s=%s\n" "${OPT}" "${!OPT}"
			printf "%s=%s\n" "${OPT}" "${!OPT}" >> "${CONFIG_FILE}"
		fi
	done
else
	>&2 printf "[entrypoint.sh]: Skipping config file creation\n"
fi

>&2 printf "[entrypoint.sh]: Done\n"
if [ "$1" = "ripe-atlas" ] && [ "${ENTRYPOINT_DO_NOT_SET_USER}" != "1" ]; then
	exec setpriv --reuid="ripe-atlas" --regid="ripe-atlas" --init-groups --ambient-caps=+NET_RAW -- "$@"
else
	>&2 printf "[entrypoint.sh]: Continuing as the current user\n"
	exec "$@"
fi
