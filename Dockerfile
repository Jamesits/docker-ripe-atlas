FROM debian:12-slim AS base

ARG ATLAS_UID=101 ATLAS_MEAS_UID=102 ATLAS_GID=999

# pre-create the required user and group so that their IDs are consistent
# https://github.com/RIPE-NCC/ripe-atlas-software-probe/blob/17566dd0129a47552556e1f355d33d0114124c60/config/common/ripe-atlas.users.conf.in
RUN adduser --system --uid $ATLAS_UID --home /run/ripe-atlas ripe-atlas \
	&& adduser --system --uid $ATLAS_MEAS_UID --home /var/spool/ripe-atlas ripe-atlas-measurement \
	&& groupadd --force --system --gid $ATLAS_GID ripe-atlas \
	&& usermod -aG ripe-atlas ripe-atlas \
	&& usermod -aG ripe-atlas ripe-atlas-measurement

# create the required directories
# https://github.com/RIPE-NCC/ripe-atlas-software-probe/blob/17566dd0129a47552556e1f355d33d0114124c60/config/common/ripe-atlas.run.conf.in
RUN install --owner=ripe-atlas-measurement --group=ripe-atlas --mode=0755 --directory /run/ripe-atlas \
	&& install --owner=ripe-atlas --group=ripe-atlas --mode=2775 --directory /var/spool/ripe-atlas

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
COPY ./ripe-atlas-software-probe /root/ripe-atlas-software-probe
RUN cd ripe-atlas-software-probe \
	&& dpkg-buildpackage -b -us -uc

######## artifacts ########
FROM scratch AS artifacts
LABEL image="ripe-atlas-artifacts"

COPY --from=builder /root/*.deb /

######## Release: ripe-atlas-anchor ########
FROM base as ripe-atlas-anchor

COPY --from=builder /root/ripe-atlas-common_*.deb /root/ripe-atlas-anchor_*.deb /tmp/
ARG DEBIAN_FRONTEND=noninteractive
RUN apt-get update -y \
	&& apt install -fy /tmp/ripe-atlas*.deb \
	&& rm -rf /var/lib/apt/lists/* /tmp/*.deb

COPY --chown=0:0 rootfs_overrides/. /

RUN mkdir -p /usr/share/factory/etc /usr/share/factory/run /usr/share/factory/var/spool \
	&& cp -rpv /etc/ripe-atlas /usr/share/factory/etc/ripe-atlas \
	&& cp -rpv /run/ripe-atlas /usr/share/factory/run/ripe-atlas \
	&& cp -rpv /var/spool/ripe-atlas /usr/share/factory/var/spool/ripe-atlas

WORKDIR /run/ripe-atlas
VOLUME [ "/etc/ripe-atlas", "/run/ripe-atlas", "/var/spool/ripe-atlas" ]
ENTRYPOINT [ "tini", "--", "entrypoint.sh" ]
CMD [ "ripe-atlas" ]

######## Release: ripe-atlas-probe ########
FROM base as ripe-atlas-probe

COPY --from=builder /root/ripe-atlas-common_*.deb /root/ripe-atlas-probe_*.deb /tmp/
ARG DEBIAN_FRONTEND=noninteractive
RUN apt-get update -y \
	&& apt install -fy /tmp/ripe-atlas-*.deb \
	&& rm -rf /var/lib/apt/lists/* /tmp/*.deb

COPY --chown=0:0 rootfs_overrides/. /

RUN mkdir -p /usr/share/factory/etc /usr/share/factory/run /usr/share/factory/var/spool \
	&& cp -rpv /etc/ripe-atlas /usr/share/factory/etc/ripe-atlas \
	&& cp -rpv /run/ripe-atlas /usr/share/factory/run/ripe-atlas \
	&& cp -rpv /var/spool/ripe-atlas /usr/share/factory/var/spool/ripe-atlas

WORKDIR /run/ripe-atlas
VOLUME [ "/etc/ripe-atlas", "/run/ripe-atlas", "/var/spool/ripe-atlas" ]
ENTRYPOINT [ "tini", "--", "entrypoint.sh" ]
CMD [ "ripe-atlas" ]
