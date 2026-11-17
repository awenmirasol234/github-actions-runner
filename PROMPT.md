# Prompt: align a repo with the self-hosted runner

Paste the block below to an agent. Replace `<owner/app>` and the health port and
path before use.

```
Goal: make repo <owner/app> build on GitHub-hosted runners and deploy on the
self-hosted runner in C:\Dev\github-actions-runner.

Read first in C:\Dev\github-actions-runner: AGENTS.md, README.md, CHEATSHEET.md.

Part 1 - point the runner at the app repo
1. Edit .env: REPO_URL=https://github.com/<owner>/<app>, set RUNNER_NAME,
   keep the existing ACCESS_TOKEN (classic PAT, repo scope, admin on the repo).
2. Run: docker compose down, delete .\data, docker compose up -d.
3. Run: docker compose exec github-runner docker version. It must print a
   server version.
4. Confirm in GitHub: repo -> Settings -> Actions -> Runners -> green Idle.

Part 2 - align the app repo
5. Add a compose file with image ghcr.io/<owner>/<app>:${IMAGE_TAG:?...},
   a real healthcheck, and named volumes for data (not ./data).
6. Add .github/workflows/ci-cd.yml. Use the snippet in CHEATSHEET.md as is.
   Fill: IMAGE (lowercase), test command, health port and path.
7. Commit to main.

Part 3 - prove it
8. Push a commit. test and build must pass on ubuntu-latest, deploy must run on
   the self-hosted runner.
9. Break the health endpoint on purpose and push again. The deploy must fail,
   roll back to the previous SHA, and exit non-zero.
10. Restore it, push again, confirm a good deploy.

Rules
- Never commit .env. Never put the token in compose.yml or a workflow file.
- Use secrets.GITHUB_TOKEN for GHCR login. Only main may deploy.
- Keep self-hosted only in the deploy job.
- Report each step as done, failed, or skipped.

Done when: the runner shows Idle for <owner/app>, a normal push deploys, and a
broken healthcheck rolls back.
```
