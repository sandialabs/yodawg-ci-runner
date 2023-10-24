**How to build a gitlab-runner container with podman**

In the top directory of a fresh checkout:

```
$ podman build . -t ci-runner
```

**How to register the runner with GitLab**

In order for GitLab to know about a runner it must be registered with GitLab. The registration is done by running the GitLab runner container in iteractive mode and entering data provided by GitLab. The registration results in a config.toml file on the runner's host and a runner entry on GitLab. 

To start the GitLab runner container in registration mode:

```
# Run the container and generate a new config.toml, enter URL and token when prompted
$ docker run --rm -it -v ./config:/etc/gitlab-runner ci-runner register
```
Note the "-v ./config:/etc/gitlab-runner" argument for the above command. This maps the config directory on the host into the runner. This is where the the config.toml file will be placed. The config.toml file contains registration info and will be used by the GitLab runner container when it is started as a persistent container.

The registration will look something like the following:

```
$ docker run --rm -it -v ./config:/etc/gitlab-runner ci-runner register
Runtime platform                                    arch=amd64 os=linux pid=7 revision=4b9e985a version=14.4.0
Running in system-mode.                            
                                                   
Enter the GitLab instance URL (for example, https://gitlab.com/):
<gitlab-instance-url>
Enter the registration token:
<runner-token>
Enter a description for the runner:
[3047acd9f5be]: My runner
Enter tags for the runner (comma-separated):
x86_64
Registering runner... succeeded                     runner=QUWENMX2
Enter an executor: docker, parallels, virtualbox, docker-ssh+machine, custom, docker-ssh, shell, ssh, docker+machine, kubernetes:
shell
Runner registered successfully. Feel free to start it, but if it's running already the config should be automatically reloaded! 
$
```

The first two things that you will be prompted for are the "GitLab URL" and "registration token". These can be found in your GitLab project at "Settings -> CI/CD -> Runners", under "Set up a specific runner manually". The next 3 entries: "description", "tags" and "executor" you will provide. The "description" is for you to identify the runner. The "tags" are used by GitLab to identify characteristics of the runner, like what architecture it is. In the above example x86_64 is used. When GitLab gets this info during registration it knows that it can send x86_64 jobs to this runner. The "executor" entry tells GitLab what mode the build we be run in.

Upon successful registration you will find a config.toml file in the config directory and you should see your runner listed in "Available specific runners" in "Settings -> CI/CD -> Runners".

The config.toml file should look similar to the following:

```
$ cat config/config.toml 
concurrent = 1
check_interval = 0

[session_server]
  session_timeout = 1800

[[runners]]
  name = "My runner"
  url = "<gitlabhost>"
  token = "AbCd1efghijklmnop"
  executor = "shell"
  [runners.custom_build_dir]
  [runners.cache]
    [runners.cache.s3]
    [runners.cache.gcs]
    [runners.cache.azure]
$
```

Note that the token is an access token, like a SSH private key, and this file should be protected accordingly.

If you want more information of how the regsitration process works checkout:
- https://docs.gitlab.com/runner/register/

**How to start the podman container**

To start the container such that it is persistent and handles build requests from GitLab:

```
$ podman run -d --rm --privileged --name=gitlab-runner \
	--net=host --security-opt label=disable --security-opt seccomp=unconfined --device /dev/fuse:rw \
	-v ./config:/etc/gitlab-runner \
	ci-runner

```

Note the "-v ./config:/etc/gitlab-runner" argument for the above command. This maps the config directory on the host into the runner.

