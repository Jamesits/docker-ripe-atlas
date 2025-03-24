# RIPE Atlas Docker Image

This is the [RIPE Atlas software probe](https://atlas.ripe.net/docs/software-probe/) packaged as a Docker image.

![Works - On My Machine](https://img.shields.io/badge/Works-On_My_Machine-2ea44f)
![Project Status - Feature Complete](https://img.shields.io/badge/Project_Status-Feature_Complete-2ea44f)
[![Docker Image Version](https://img.shields.io/docker/v/jamesits/ripe-atlas?label=Docker%20Hub&sort=semver)](http://hub.docker.com/r/jamesits/ripe-atlas)

## Usage

### Requirements

* 1 CPU core (of course)
* 20MiB memory
* 100MiB HDD
* A Linux installation with Docker installed
* Internet access

### Tags

The following prebuilt tags are available at [Docker Hub](https://hub.docker.com/r/jamesits/ripe-atlas):

- `latest`, `latest-probe`, `latest-anchor`: latest stable version
- `v{version}`, `v{version}-probe`, `v{version}-anchor`: matches upstream version
- `edge`, `edge-probe`, `edge-anchor`: whatever from the master branch

Since version 5090, we do not provide `-{arch}` tags anymore.

### Running

You can run the container manually with any OCI container runtime of your choice. There are some templates:

#### Using [Docker Compose](https://docs.docker.com/compose/)

An example [`docker-compose.yaml`](/docker-compose.yaml) is provided.

```shell
cd contrib/docker-compose
docker-compose pull
docker-compose up -d
```

#### Using [`podman-systemd.unit`](https://docs.podman.io/en/latest/markdown/podman-systemd.unit.5.html)

```shell
install --user=root --group=root --target /etc/containers/systemd/ -- contrib/podman-quadlet/*.container
systemctl reload
systemctl start ripe-atlas.service
```

### Registering the Probe

Fetch the generated public key:

```shell
cat /etc/ripe-atlas/probe_key.pub
```

[Register](https://atlas.ripe.net/apply/swprobe/) the probe with your public key. After the registration being manually processed, you'll see your new probe in your account.

## Building

If you don't want to use the prebuilt image hosted on the Docker Hub, you can build your own image.

```shell
DOCKER_BUILDKIT=1 docker build --tag localhost/ripe-atlas:latest-probe --target ripe-atlas-probe .
```

Note that building this container image requires [BuildKit](https://docs.docker.com/develop/develop-images/build_enhancements/).

## Caveats

### IPv6

[Docker 27.0.1](https://github.com/moby/moby/releases/tag/v27.0.1) enabled IPv6 (incl. `ip6tables` and NATv6) by default.

If you are on older versions: Docker does not enable IPv6 by default. If you want IPv6 support, some level of setup and a basic understanding of IPv6 is required. Swarm mode & some Kubernetes implementation supports IPv6 too with extra configuration.

#### Using native address assignment

If you happened to have a block of static IPv6 addresses routed to your host, you can directly assign one of the addresses to the container. Edit `/etc/docker/daemon.json` and add native IPv6 address blocks, then restart the Docker daemon. An example:

```json
{
  "ipv6": true,
  "fixed-cidr-v6": "2001:db8:a1a3::/48"
}
```

Notes:
- These config work on Docker for Linux only
- If `daemon.json` exists, merge the config lines instead of directly overwriting it; if it doesn't exist, create it manually
- For more info, see [the official doc](https://docs.docker.com/config/daemon/ipv6/)

#### Using NAT (NPTv6)

If your ISP does not conform to [BCOP 690](https://www.ripe.net/publications/docs/ripe-690) (very common), and/or your router cannot route smaller blocks of IPv6 to one server even if it has been assigned a block of valid IPv6 addresses (also very common), the method above might not work for you. As a workaround, you can setup NAT with either [Docker's builtin experimental IPv6 NAT support](https://blog.iphoting.com/blog/2021/02/10/ipv6-docker-docker-compose-and-shorewall6-ip6tables/), `robbertkl/docker-ipv6nat` or similar projects. Manual iptables/nftables NAT setup is also possible, but *hanc marginis exiguitas non caperet*.

Firstly, edit kernel parameters to enable IPv6 routing.

```shell
cat > /etc/sysctl.d/50-docker-ipv6.conf <<EOF
net.ipv6.conf.eth0.accept_ra=2
net.ipv6.conf.all.forwarding=1
net.ipv6.conf.default.forwarding=1
EOF
sysctl -p /etc/sysctl.d/50-docker-ipv6.conf
```

Notes:
- This potentially introduces more attack surface and might require you set up IPv6 firewall rules to make yourself safe
- This might break your network and your mileage may vary
- Swap `eth0` with your primary network adapter name
- If you use static IPv6 assignment instead of SLAAC, change `accept_ra` to `0`

Secondly, create a IPv6 NAT enabled network.

```shell
docker network create --ipv6 --subnet=fd00:a1a3::/48 ripe-atlas-network
docker run -d --restart=always -v /var/run/docker.sock:/var/run/docker.sock:ro -v /lib/modules:/lib/modules:ro --cap-drop=ALL --cap-add=NET_RAW --cap-add=NET_ADMIN --cap-add=SYS_MODULE --net=host --name=ipv6nat robbertkl/ipv6nat:latest
```

Finally, start the RIPE Atlas container with argument `--net=ripe-atlas-network`.

### Auto Update

Use this recipe for auto updating the docker container.

```shell
docker run --detach --restart=always -v /var/run/docker.sock:/var/run/docker.sock --name watchtower containrrr/watchtower --cleanup --label-enable
```

Then start the RIPE Atlas container with argument `--label=com.centurylinklabs.watchtower.enable=true`.

### Backup

Back up `/etc/ripe-atlas` is enough.

### Resetting the Probe

If the probe is acting weird or not connecting to the server for a prelonged time without any error logs, you can try resetting the probe's internal state by deleting everything in `/var/spool/ripe-atlas` and `/run/ripe-atlas` then restarting the container.

### Security

Upstream software does not correctly use Linux [capabilities(7)](https://man7.org/linux/man-pages/man7/capabilities.7.html) and tries to mess up everything by using `setuid` executables. So:

| Container Runtime | Container User | Network Namespace | Works | Caveats                                  |
|-------------------|----------------|-------------------|-------|------------------------------------------|
| root              | root           | separate          | YES   |                                          |
| root              | non-root       | separate          | NO    | daemons does not start                   |
| root              | root           | host              | ?     |                                          |
| root              | non-root       | host              | NO    | daemons does not start                   |
| rootless          | root           | separate          | YES   | traceroute might not work                |
| rootless          | non-root       | separate          | NO    | daemons does not start                   |
| rootless          | root           | host              | NO    | `eooqd: socket: Operation not permitted` |
| rootless          | non-root       | host              | NO    | daemons does not start                   |

When the host distro is Debian 10 or similarly old ones, you might need to add `--security-opt seccomp:unconfined` to the `docker run` command to make things work ([#19](https://github.com/Jamesits/docker-ripe-atlas/issues/19)). You should upgrade your host distro ASAP.

### Upgrading from 5080 to 5100 or Later

At version 5090, upstream introduced a lot changes that require manual intervention.

- You need to update the container startup arguments. See [Running](#running) for an example. Note that new permissions are required to make the directory initialization process work.
- The SSH keys are stored at `/etc/ripe-atlas` now. Please `mv /var/atlas-probe/etc /etc/ripe-atlas` and make sure they are owned by `101:999` (before subuid/subgid mapping, if applicable).
- `/var/atlas-probe` is not used anymore and should be removed.
- `/var/spool/ripe-atlas` and `/run/ripe-atlas` are now used to store probe runtime info.
- If you are still using `latest-{arch}` tags, please update to use only `latest`.
