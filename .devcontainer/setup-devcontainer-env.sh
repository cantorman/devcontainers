#!/bin/bash

# this just creates the file env so the docker compose file can see it even on startup
# fill in the correct values the first time you connect to it
if [[ ! -f devcontainer.env ]]; then
cat << DCENV > devcontainer.env
AWS_ACCESS_KEY_ID=dumb
AWS_SECRET_ACCESS_KEY=dumber
AWS_REGION=us-east-1
# append secrets here.  Do not commit.
DCENV
fi
