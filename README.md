# Self-Hosted GitHub Actions Runner

Runs one GitHub Actions runner for one repository, in Docker.

## Use it for another repository

Three changes. Everything else in this folder stays the same.

1. Put a token in `.env`. Create a classic token at
   https://github.com/settings/tokens/new with the `repo` scope and admin access
   to the repository.

   ```
   ACCESS_TOKEN=ghp_your_token_here
   ```

2. Change two lines in `compose.yml`.

   ```yaml
   REPO_URL: https://github.com/<owner>/<repository>
   RUNNER_NAME: <short unique name>
   ```

   Leave `RUNNER_SCOPE: repo` and `LABELS: ubuntu,docker` as they are.

3. Add a workflow to that repository. `runs-on` must match the labels.

   ```yaml
   name: Self Hosted Runner Test

   on:
     workflow_dispatch:

   jobs:
     test:
       runs-on: [self-hosted, linux, x64, ubuntu, docker]
       steps:
         - name: Check runner
           run: |
             echo "runner: $RUNNER_NAME"
             hostname
             docker version
   ```

   Commit it to the default branch, then run it from the Actions tab. The job ran
   on this machine when the log shows `runner: <your name>` and a hostname that
   is not `fv-az...`.

## Start it

```
docker compose up -d
docker compose logs -f
```

Wait for `Listening for Jobs`. Then check the repository under
Settings -> Actions -> Runners: the name from step 2 must show a green Idle dot.

The host can be Linux or Windows.

- Linux: install Docker Engine.
- Windows: install Docker Desktop with WSL2, and keep the default Linux
  containers mode. Windows containers mode cannot run this image.

The runner mounts `/var/run/docker.sock`. Docker Desktop provides the same path
inside Linux containers.

Run the runner on one host at a time. Before you start it on another machine,
delete the old offline entry in Settings -> Actions -> Runners.

## Change the repository or the name later

Both values are read only when the runner registers. After editing them:

```
docker compose down
rm -rf data
docker compose up -d
```

On Windows PowerShell:

```
docker compose down
Remove-Item -Recurse -Force .\data
docker compose up -d
```

Then delete the old runner in GitHub so it does not stay listed as offline.

## Problem and cause

| Problem | Cause |
|---|---|
| Job stays queued, "No runner matching labels" | `runs-on` does not match the labels. |
| Runner absent from the Runners page | Bad token, missing `repo` scope, or SSO not authorized. Check `docker compose logs`. |
| Runner listed but Offline | Container stopped. `docker compose restart`. |
| `docker: not found` in a job | Socket mount missing, or Docker Desktop is in Windows containers mode. |

## Security

Mounting `/var/run/docker.sock` gives the runner full control of the host's
Docker, so any workflow on this runner can control the host. Only use it on
repositories you control. Do not attach it to a public repository unless you
require approval for outside collaborators in Settings -> Actions -> General.
