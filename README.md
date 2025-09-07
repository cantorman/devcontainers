# Devcontainers
Here is how I solved the "Works only on my machine" problem using Devcontainers.
I have stripped my solution (which spans a number of steps, files, and systems) down to its essentials and
I'll walk you through them here.  I have gone through the files themselves and added supplementary comments,
but *this* document is to serve as the roadmap.

## The "Works Only On My Machine" problem
This problem arises in development due to the complexity of modern software solutions.  Applications requre setup which is the
process of assembling all the bits and configuring them to work together.  Further, the bits change over time, get upgraded
augmented, deprecated, replaced.  Or not.  Then there are various environments, build systems, test frameworks, monitoring solutions and so forth that also all need to be configured.

Now assume you have a team of hundreds of developers, or maybe just a few, with all the attendant communications problems that large or small organiations have.  Correct information rots the moment it is created because of this process of constant change, so documentation requires continuous update.

So we as a culture of engineers have invented *infrastucture as code* to deal with this issue in *production*, where all the components and
configurations can be assembled and configured ("deployed") using some reproducible process.

What if we could apply the same rigor to the development environment?  That's devcontainers, or systems like it.

## Solution: Software defined development environment
Devcontainers are a project that was created to address the works-on-my-machine problem.  (See https://containers.dev)
The principle is that you configure a docker container that runs your app in development mode, and to this you add
whatever you need to actually do development inside the container itself.  So you have all the bits for the application, and all the bits for the development environment, wrapped up into a repeatable Docker container.  And by gosh it works.
It does the right thing.  Reproducibly.  Iteratively.

## The Right Thing - hook up to IDE
VSCode supports this idea with a plugin that detects that you have a particular directory, `.devcontainer`, in your project, and does the following:

* It calls the devcontainer boot sequence to create your devcontainer, building it along the way if it needs to
* It connects you to the container in a shell so you can develop and test directly in the environment.
* Because this environment was defined in software, it is precisely the same environment as the rest
of your team, because it's all the same code of course.
* For added power, you want to make the devcontainer be as close to what's in production as possible.  Obviously there will be some differences of scale and authentication and so forth, but you can go a long way.

## The magic: pull the app source into the user's home dir and mount that inside the devcontainer

One powerful addition I implemented is to _mount_ the source
that you are compiling directly into the devcontainer.  Dockerfiles provide for this and it works well if you iron out the wrinkles
as I will show.  The system I am presenting does this from within your home directory on your laptop that is running `docker compose`.  You can bring along other things from your home directory, for example, AWS credentials, git config, and so forth.  This makes the transition from host to container much more seamless.

If you do *not* mount the source into the devcontainer, then you have a separate independent repository that must be pushed and pulled every time the container is restart lest you lose work.  Container restarts must at least happen what anyone on your team pushes changes to your app.  You environment becomes stateful and that's a hassle.

Mounting directly into the devcontainer decouples the code and the environment so that you can reboot the container when there is new code or whenever you decide, and you don't have to do anything other than pull, i.e. you don't have to push first.

### Filesystem Permissions
The filesystem permissions have to be set right or you won't be able to edit files in the source.  Rather than making everything world writable in your home filesystem, the system determines the user and group id you are using on your laptop and propagates these into the devcontainer so that when you connect to it your process in the devcontainer uses them too.  Then everything just works out nicely.

**Note:** This connection depends on functionally equivalent filesystem semantics between the host and container.  So for example, when using a Windows host with an NTFS filesystem mounted into a Linux container, extra care must be taken to create an experience that is satisfactory to the developer in terms of functionality and maintenance.  Much depends on the implementation of the mount functionality.

# Walkthrough
* `.devcontainer/` - This folder is the heart of the system and requires a `devcontainer.json` file.
* `devcontainer.json` - This defines an orchestration layer which describes how the system is going to run, including which flavor of containerization (`docker` vs. `docker compose`) and where to mount the user's home directory.  I set it up to use `docker compose` instead of plain `docker` so that I could take advantage of override files, and of the service based semantics of the compose file, `docker-compose-dev.yml`.

## Files referenced in `devcontainer.json`
* `setup-devcontainer-env.sh` - Runs on the host. This persists the desired environment to the filesystem in a way the compose file can consume.
* `create-compose-override.sh` - Also runs on the host.  This is the file that acquires the User and Group IDs from the host operating system and persists them to the filesystem in the format of a compose override file, `docker-compose-dev.override.yml` so that `docker compose` can consume it and apply these IDs to the system after the compose file is applied, during boot.  The override file is listed in `.gitignore` so that it will *not* be commited.
* `docker-compose-dev.yml` - This file defines the service that is the application.  (Not shown but possible: Sidecars.)  It defines:
  * The mounting of the user's home directory into the container, so that the container can see the source, and things like `.gitconfig` and `.aws`
  * A local cache volume for `node_modules` - this is requred for node apps that have large dependency lists in `package.json`; if not cached, `node_modules` must be regenerated each time. ( You can't use the `node_modules` in the home directory unless the container and the laptop and exactly the same, since `npm install` may create architecture-specific files in `node_modules`. ). Before I realized this was necessary, teams were enduring 15 minute startup times for a complicated node project, which was completely unacceptable.
  * Ways to specify the environment in the container, either through Docker args or through the `devcontainer.env` file.
* `config-container.sh` which runs inside the container and does final adjustments credentials and source control for which it uses the above mounts.  It configures the container's shell to persist settings, arranges to use the mounts that have the credentials and configurations from the laptop, and populates the `node_modules` cache.  Though this script runs on each startup, if the cache is populated already the subsequent runs are quick.

## Mounts referenced in `devcontainer.json`:
* The user's home dir `~/.aws` on the laptop: mounted into a path under /tmp in the container so that `config-container.sh` can symlink it in the the _devcontainers_ user home dir 
* The user's home dir `~/.gitconfig` on the laptop: mounted into a (different) path under /tmp in the container so that `config-container.sh` can copy it to the the _devcontainer's_ user home dir as their ~/.gitconfig, where it can be updated as needed.  This allows simple `.gitconfig` settings to be propagated into the container - remotes, aliases, branchs, etc.
* `config-container.sh` in the laptop source: mounted to yet another path in /tmp where it can be findable during the boot sequencing.
* `Dockerfile.dev` - This is the dockerfile from which the devcontainer is built.  Among other things, it consumes the User and Group IDs from the laptop and ensures they exist in the container.  It also uses and ENTRYPOINT that does `sleep infinity` so that the container only exits when told to do so.

## Other Files
The rest of the files and directories you see - `application/Dockerfile`, `.gitignore`, `.dockerignore`, `package.json` are basically illustrative placeholders that point to a more fleshed out project.  It is important to note that since all these are in source control, the resultant environment is completely reproducible (except of course for things like secrets) 

# Benefits
* This system provides a solution to the Works on My Machine problem. It defines and implements a software-reproducible development environment.  
* You can augment it with things like pre-commit to shift the process left and get more done and at a higher quality than what might have been pushed to the  CI/CD system.
* You can easily accomplish standardization on whatever libraries or versions your security team requests.
* Unit tests are easier in the software defined environment, and with the addition of sidecars some amount of integration testing, TDD or even BDD is totally possible.
