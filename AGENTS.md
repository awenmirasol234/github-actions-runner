# Project: self-hosted GitHub Actions runner

One Docker container that runs a GitHub Actions runner for exactly one
repository. The runner executes that repository's jobs on this machine.

## Files

- `compose.yml` - the only service. Image `myoung34/github-runner:latest`.
- `.env` - real values. Git ignored. Never commit.
- `.env.example` - example values shown to new users.
- `README.md` - user guide for reusing this folder on another repository.
- `.github/workflows/runner-test.yml` - manual test job for the runner.
- `data/` - created at runtime. Holds the runner identity: `.runner`,
  `.credentials`, work folders. Git ignored.

## Current values

- `REPO_URL` - the one repository served. Set in `.env`.
- `RUNNER_NAME` - the name shown in GitHub runner settings.
- `RUNNER_SCOPE` - `repo`, fixed in `compose.yml`.
- `LABELS` - `ubuntu,docker`, fixed in `compose.yml`. GitHub adds
  `self-hosted, linux, x64`.
- `ACCESS_TOKEN` - classic PAT with `repo` scope, or fine-grained with
  Administration read/write on that one repo.

`compose.yml` requires the three `.env` values. It fails to start when one is
missing. There are no fallbacks.

## How it works

1. Container starts and reads `REPO_URL` and `ACCESS_TOKEN`.
2. It requests a short-lived registration token from GitHub for that repo.
3. It registers once, then stores its identity in `data/`.
4. It polls that repo's job queue using the stored identity. The token is not
   used again unless re-registration is needed.
5. A job runs only if the workflow is in that repo and `runs-on` matches the
   labels.

Changing `REPO_URL` or `RUNNER_NAME` does nothing until the identity is reset:

```
docker compose down
rm -rf data
docker compose up -d
```

## Hosts

The runner is always a Linux container:

- Linux host: Docker Engine.
- Windows host: Docker Desktop, WSL2, Linux containers mode. Windows
  containers mode cannot run this image.

The container mounts `/var/run/docker.sock`, so jobs can use Docker. This also
gives any workflow on the runner full control of the host. Only use it on
repositories that are fully trusted.

One repository and one host at a time. For a second repo or host, copy the
folder and use a different `RUNNER_NAME`.

## Commands

```
docker compose up -d
docker compose logs -f
docker compose exec github-runner docker version
docker compose config -q
```

## Do not

- Do not commit `.env`.
- Do not put the token in `compose.yml` or `.env.example`.
- Do not attach this runner to a public repository without strict fork approval.
