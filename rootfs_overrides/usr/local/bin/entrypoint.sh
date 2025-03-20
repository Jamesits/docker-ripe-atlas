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
function init_dir() {
	if [ -z "$( ls -A "$1" )" ]; then
		>&2 printf "[entrypoint.sh]: Initializing directory %s\n" "$1"
		mkdir -p -- "$1"
		cp -rpv -- "/usr/share/factory/$1/." "$1"
	else
		# try to copy missing files only, but do not overwrite existing files
		cp -rpnv -- "/usr/share/factory/$1/." "$1"
	fi
	chmod "$2" -- "$1" || true
	chown "$3:$4" -- "$1" || true
}
init_dir "/run/ripe-atlas" "775" "ripe-atlas-measurement" "ripe-atlas"
init_dir "/var/spool/ripe-atlas" "2775" "ripe-atlas" "ripe-atlas"
init_dir "/etc/ripe-atlas" "755" "ripe-atlas" "ripe-atlas"

# set probe configuration
printf "prod\n" > "/etc/ripe-atlas/mode.atlasswprobe"
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
