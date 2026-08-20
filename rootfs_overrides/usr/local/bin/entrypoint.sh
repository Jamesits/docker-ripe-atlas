#!/usr/bin/env bash
set -Eeuo pipefail

CONFIG_FILE="/etc/ripe-atlas/config.txt"
# the config file as shipped in the image, containing the defaults the package's postinst set
CONFIG_FILE_FACTORY="/usr/share/factory/etc/ripe-atlas/config.txt"
MODE_FILE="/etc/ripe-atlas/mode"
STATUS_DIR="/run/ripe-atlas/status"
VERSION_FILE="/usr/share/ripe-atlas/FIRMWARE_APPS_VERSION"
VERSION_STAMP="/run/ripe-atlas/.version"
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

# cleanup
rm -fv -- /etc/ripe-atlas/reg_servers.sh

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

# the Debian package wipes the status files whenever the package version changes (postrm "upgrade").
# A container restart is indistinguishable from an upgrade, so compare the version installed in the
# image against the one recorded in the runtime directory.
if [ -f "${VERSION_FILE}" ] && ! cmp -s -- "${VERSION_FILE}" "${VERSION_STAMP}"; then
	>&2 printf "[entrypoint.sh]: Probe version changed to %s, cleaning up %s\n" "$( cat -- "${VERSION_FILE}" )" "${STATUS_DIR}"
	rm -fv -- "${STATUS_DIR}"/* || [ "${ENTRYPOINT_DO_NOT_SET_USER}" == "1" ]
	cp -pv -- "${VERSION_FILE}" "${VERSION_STAMP}" || [ "${ENTRYPOINT_DO_NOT_SET_USER}" == "1" ]
fi

# set probe configuration
if [ "${ENTRYPOINT_SKIP_CONFIG_FILE}" != "1" ]; then
	# mode
	# the Debian package stages a migrated mode file as "mode.atlasswprobe" and renames it in postinst;
	# the probe itself only ever reads "mode"
	if [ -f "${MODE_FILE}.atlasswprobe" ]; then
		mv -v -- "${MODE_FILE}.atlasswprobe" "${MODE_FILE}"
	fi
	if [ ! -f "${MODE_FILE}" ]; then
		printf "prod\n" > "${MODE_FILE}"
	fi

	# keep the defaults the package shipped (the anchor package sets RXTXRPT=yes), except for the
	# options we are about to set ourselves
	if [ -f "${CONFIG_FILE_FACTORY}" ]; then
		>&2 printf "[entrypoint.sh]: Inheriting default options from %s\n" "${CONFIG_FILE_FACTORY}"
		OPTIONS_RE="$( IFS="|"; printf "%s" "${OPTIONS[*]}" )"
		# grep exits 1 when the file only contains options we manage ourselves
		grep -vE "^[[:space:]]*(${OPTIONS_RE})=" -- "${CONFIG_FILE_FACTORY}" >> "${CONFIG_FILE}" || true
	fi
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
