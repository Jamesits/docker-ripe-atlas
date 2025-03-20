FROM debian:12-slim AS base

# pre-create the required user and group so that their IDs are consistent
ARG ATLAS_UID=101
ARG ATLAS_MEAS_UID=102
ARG ATLAS_GID=999
RUN adduser --system --uid $ATLAS_UID ripe-atlas \
	&& adduser --system --uid $ATLAS_MEAS_UID ripe-atlas-measurement \
	&& groupadd --force --system --gid $ATLAS_GID ripe-atlas \
	&& usermod -aG ripe-atlas ripe-atlas \
	&& usermod -aG ripe-atlas ripe-atlas-measurement

# install common packages
ARG DEBIAN_FRONTEND=noninteractive
RUN apt-get update -y \
	&& apt-get install -y libcap2-bin iproute2 openssh-client procps net-tools tini \
	&& rm -rf /var/lib/apt/lists/*

######## builder ########
FROM base AS builder

ARG DEBIAN_FRONTEND=noninteractive
# Note: systemd must exist for the package to build; otherwise systemd unit templates will fail to generate
RUN apt-get update -y \
	&& apt-get install -y git build-essential debhelper libssl-dev autotools-dev systemd \
	&& rm -rf /var/lib/apt/lists/*

WORKDIR /root
COPY --link ./ripe-atlas-software-probe /root/ripe-atlas-software-probe
RUN cd ripe-atlas-software-probe \
	&& dpkg-buildpackage -b -us -uc

######## artifacts ########
FROM scratch AS artifacts
LABEL image="ripe-atlas-artifacts"

COPY --link --from=builder /root/*.deb /

######## Release: ripe-atlas-anchor ########
FROM base as ripe-atlas-anchor

COPY --link --from=builder /root/ripe-atlas-common_*.deb /root/ripe-atlas-anchor_*.deb /tmp/
ARG DEBIAN_FRONTEND=noninteractive
RUN apt-get update -y \
	&& apt install -fy /tmp/ripe-atlas*.deb \
	&& rm -rf /var/lib/apt/lists/* /tmp/*.deb

COPY --link --chown=0:0 rootfs_overrides/. /
WORKDIR /run/ripe-atlas
VOLUME [ "/etc/ripe-atlas", "/run/ripe-atlas/status" ]
ENTRYPOINT [ "tini", "--", "entrypoint.sh" ]
CMD [ "ripe-atlas" ]

######## Release: ripe-atlas-probe ########
FROM base as ripe-atlas-probe

COPY --link --from=builder /root/ripe-atlas-common_*.deb /root/ripe-atlas-probe_*.deb /tmp/
ARG DEBIAN_FRONTEND=noninteractive
RUN apt-get update -y \
	&& apt install -fy /tmp/ripe-atlas-*.deb \
	&& rm -rf /var/lib/apt/lists/* /tmp/*.deb

COPY --link --chown=0:0 rootfs_overrides/. /
WORKDIR /run/ripe-atlas
VOLUME [ "/etc/ripe-atlas", "/run/ripe-atlas/status" ]
ENTRYPOINT [ "tini", "--", "entrypoint.sh" ]
CMD [ "ripe-atlas" ]
