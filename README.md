# RIPE Atlas Docker Image

This is the [RIPE Atlas software probe](https://atlas.ripe.net/docs/software-probe/) packaged as a Docker image.

[![Build Status](https://dev.azure.com/nekomimiswitch/General/_apis/build/status/docker-ripe-atlas?branchName=master)](https://dev.azure.com/nekomimiswitch/General/_build/latest?definitionId=83&branchName=master)

## Running

First we start the container:

```shell
docker run -d \
	--restart=unless-stopped \
	--memory=256m \
	--cap-add=SYS_ADMIN --cap-add=CAP_NET_RAW --cap-add=CAP_CHOWN \
	--mount type=tmpfs,destination=/var/atlasdata \
	--mount type=bind,src=/var/atlas-probe/etc,dst=/var/atlas-probe/etc \
	--mount type=bind,src=/var/atlas-probe/status,dst=/var/atlas-probe/status \
	--name ripe-atlas \
	jamesits/ripe-atlas:latest
```

Then we fetch the generated public key:

```
cat /var/atlas-probe/etc/probe_key.pub
```

[Register](https://atlas.ripe.net/apply/swprobe/) the probe with your public key.


