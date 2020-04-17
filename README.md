# RIPE Atlas Docker Image

This is the [RIPE Atlas software probe](https://atlas.ripe.net/docs/software-probe/) packaged as a Docker image.

[![Build Status](https://dev.azure.com/nekomimiswitch/General/_apis/build/status/docker-ripe-atlas?branchName=master)](https://dev.azure.com/nekomimiswitch/General/_build/latest?definitionId=83&branchName=master)

## Running

```shell
docker run \
	--restart=unless-stopped \
	--memory=256m \
	--cap-add=SYS_ADMIN --cap-add=CAP_NET_RAW --cap-add=CAP_CHOWN \
	--mount type=tmpfs,destination=/var/atlasdata \
	--mount type=bind,src=/var/atlas-probe/etc,dst=/var/atlas-probe/etc \
	--mount type=bind,src=/var/atlas-probe/status,dst=/var/atlas-probe/status \
	jamesits/ripe-atlas:latest
```
