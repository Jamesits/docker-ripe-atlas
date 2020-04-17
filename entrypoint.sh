#!/usr/bin/env bash
set -Eeuo pipefail

chown -R atlas:atlas /var/atlas-probe/status
chown -R atlas:atlas /var/atlas-probe/etc

exec gosu atlas:atlas "$@"
