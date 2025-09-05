#!/usr/bin/env bash
# configure container for development

container_root=/application
echo Dev container root is $container_root

echo Setting up git
# we'll copy the developer's gitconfig into place so we can safely update it inside the container w/o affecting the user
cp -f /tmp/host/gitconfig ~/.gitconfig

# and append some defaults to that file using the usual git mechanism
git config --global pull.rebase false
git config --global --add safe.directory '*'

## point to the place the user's aws credentials are mounted to withih the dev container
# persisting them so that the user doesn't have to log in every time the container restarts
echo Setting up AWS credentials
ln -s /tmp/host/dot-aws/ ~/.aws

# install node modules to our local cache
echo Setting up node_modules
node_modules=$container_root/application/node_modules
sudo chown $LOGNAME $node_modules
mkdir -p $node_modules/.yarn_cache/

# point to local cache in the shell
echo Setting up .zshrc
cat << ZSHRC >> ~/.zshrc
export YARN_CACHE_FOLDER=$node_modules/.yarn_cache/
export PATH=$PATH:$node_modules/.bin
ZSHRC

# Install any other dependencies
echo "Running yarn install"
cd application
source /opt/nvm/nvm.sh # this comes in from the base container and gives everybode the same node
nvm use 20
YARN_CACHE_FOLDER=$node_modules/.yarn_cache yarn install

# Done
echo Done with container configuration
