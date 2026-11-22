# Cheatsheet

## First time

```
copy .env.example .env      # Windows
cp .env.example .env        # Linux
```

Edit `.env`, three values, all required:

```
ACCESS_TOKEN=ghp_...        # classic PAT, repo scope
REPO_URL=https://github.com/owner/repo
RUNNER_NAME=my-runner
```

Start and watch:

```
docker compose build
docker compose up -d
docker compose logs -f      # wait for "Listening for Jobs"
```

Check: repo -> Settings -> Actions -> Runners -> green **Idle**.

Prove Docker works inside the runner:

```
docker compose exec github-runner docker version
```

## Workflow snippet

Build on a GitHub machine, deploy on the runner:

```yaml
name: CI/CD

on:
  push:
    branches: [main]
  workflow_dispatch:

concurrency:
  group: deploy-main
  cancel-in-progress: false      # queue, never overlap

permissions:
  contents: read
  packages: write

env:
  IMAGE: ghcr.io/owner/repo    # must be lowercase

jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - run: echo "real test command here"

  build:
    needs: test
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: docker/login-action@v3
        with:
          registry: ghcr.io
          username: ${{ github.actor }}
          password: ${{ secrets.GITHUB_TOKEN }}
      - uses: docker/build-push-action@v6
        with:
          context: .
          push: true
          tags: |
            ${{ env.IMAGE }}:${{ github.sha }}
            ${{ env.IMAGE }}:latest

  deploy:
    needs: build
    if: github.ref == 'refs/heads/main'
    runs-on: [self-hosted, linux, x64, ubuntu, docker]
    steps:
      - uses: actions/checkout@v4
      - uses: docker/login-action@v3
        with:
          registry: ghcr.io
          username: ${{ github.actor }}
          password: ${{ secrets.GITHUB_TOKEN }}
      - name: Deploy or roll back
        env:
          IMAGE_TAG: ${{ github.sha }}
        run: |
          set -euo pipefail
          STATE=/tmp/runner/deploy-state
          mkdir -p "$STATE"
          PREV=$(cat "$STATE/app" 2>/dev/null || true)
          docker compose pull
          if docker compose up -d --wait --wait-timeout 120; then
            echo "$IMAGE_TAG" > "$STATE/app"
          else
            echo "health failed, rolling back to ${PREV:-none}"
            if [ -n "$PREV" ]; then
              IMAGE_TAG="$PREV" docker compose up -d --wait --wait-timeout 120
            fi
            exit 1
          fi
```

The app's `compose.yml` must use the tag and define a healthcheck:

```yaml
services:
  app:
    image: ghcr.io/owner/repo:${IMAGE_TAG:?IMAGE_TAG is not set}
    healthcheck:
      test: ["CMD", "curl", "-fsS", "http://localhost:8080/health"]
      interval: 5s
      retries: 12
```

`runs-on` is the only line that selects the runner. It must contain
`self-hosted`. The health path must really exist, or `--wait` cannot judge.

## Labels on this runner

```
self-hosted, linux, x64, ubuntu, docker
```

First three come from GitHub. `ubuntu,docker` come from `LABELS` in
`compose.yml`.

## Daily commands

```
docker compose ps
docker compose logs -f
docker compose restart
docker compose exec github-runner docker version
```

## Change repo or name

Values are read only at registration. Reset the identity:

```
docker compose down
rm -rf data
docker compose up -d
```

Windows PowerShell:

```
docker compose down
Remove-Item -Recurse -Force .\data
docker compose up -d
```

Then delete the old offline entry in Settings -> Actions -> Runners.

## Connectivity health check

```bash
docker exec -it <container_name> bash
# inside:
curl -fsS http://localhost:<port>/health
```

## If it does not work

| See | Do |
|---|---|
| Job queued, "No runner matching labels" | Fix `runs-on`, keep `self-hosted` |
| No "Run workflow" button | Workflow file must be on the default branch |
| Runner missing in Settings | Check `docker compose logs`, token or `repo` scope |
| Runner Offline | `docker compose ps`, then `docker compose restart` |
| Image build fails | Check Docker Desktop connectivity and the build output |
| `docker: not found` in a job | Socket missing, or Desktop is in Windows containers mode |
| Job ran on `fv-az...` | `self-hosted` missing from `runs-on` |

## Facts

- One container serves one repository.
- Identity lives in `data/`. Delete it to re-register.
- The token is only used at registration. Expiry does not stop a running runner.
- `/var/run/docker.sock` gives jobs full control of the host. Trusted repos only.
