#!/bin/bash

# this creates an override file that makes the local user id and group available to the startup script so that 
# the devcontainer will use the same uid and gid as the local filesystem being mount into the devcontainer 

cat << YAML > docker-compose-dev.override.yml
services:
  application-devcontainer:
    build:
      args:
        - UID=$(id -u)
        - GID=$(id -g)
YAML
