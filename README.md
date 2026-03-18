# meshcentral-ha-platform

> **Status: Stage 1 / Work in Progress**
>
> This repository is actively evolving. The current codebase is a stage-1 foundation for a larger MeshCentral platform, not the final shape of the project. Expect the architecture, automation, and operational model to keep changing as later stages are implemented.

`meshcentral-ha-platform` is a deployment-first MeshCentral project for AWS EC2. Stage 1 focuses on a practical CI/CD baseline: build a custom MeshCentral image, publish it to GHCR, deploy it to a Linux host with Docker Compose, and keep the pinned upstream base image digest in sync through GitHub Actions.

## Stage 1 Goals

- Run MeshCentral in containers on a Linux EC2 host.
- Put Nginx in front of MeshCentral as the reverse proxy.
- Build and publish a custom MeshCentral image through GitHub Actions.
- Deploy updates automatically from `main`.
- Track upstream MeshCentral image changes through a scheduled/manual sync workflow.
- Keep the repo as the source of truth for what gets deployed.

## What Exists Today

- A custom Docker image based on the official MeshCentral image, with a container health check.
- A GitHub Actions CI/CD pipeline that builds the image, pushes it to GHCR, and deploys it to EC2.
- A separate upstream-sync workflow that checks for new upstream MeshCentral image digests and updates the pinned digest in-repo.
- An in-place deployment script with health-check validation and rollback to the previously running image if startup fails.
- Persistent bind-mounted storage for MeshCentral data and backups via `./data` and `./backups`.
- A simple Nginx reverse proxy in front of the MeshCentral container.

## Work In Progress / Not Yet Implemented

- Automated backup execution and retention management during deploys.
- Blue-green or dual-slot deployment.
- Terraform- or Ansible-based infrastructure provisioning.
- More mature host provisioning and operational hardening.
- A polished local-development workflow. The repo is currently optimized for CI/CD and deployment more than daily app development.

## Architecture And Flow

### Normal Deploy Flow

1. A push to `main` triggers `.github/workflows/deploy.yml`.
2. GitHub Actions builds the custom image from `docker/Dockerfile`.
3. The image is pushed to GHCR with `latest` and `sha-<commit>` tags.
4. The workflow copies the deployment files to `~/meshcentral` on the EC2 host.
5. The workflow connects over SSH and runs `scripts/deploy.sh`.
6. The deploy script renders `data/config.json`, pulls the target image, recreates the stack, checks container health, and rolls back if the new image fails.

### Upstream Sync Flow

1. `.github/workflows/meshcentral-upstream-sync.yml` runs on a daily schedule or manual dispatch.
2. The workflow checks the latest upstream digest for the MeshCentral base image.
3. If the digest changed, it updates the pinned `FROM ...@sha256:...` line in `docker/Dockerfile`.
4. The workflow commits that change directly to `main` using `BOT_PUSH_TOKEN`.
5. That bot commit triggers the normal deploy pipeline, keeping Git history as the deployment source of truth.

### Runtime Layout

- `docker-compose.yml` defines the `meshcentral` and `nginx` services.
- `config/config.template.json` is rendered into `data/config.json` by the deploy script.
- `./data` stores MeshCentral runtime data.
- `./backups` is reserved for backup artifacts, although backup automation is not implemented yet.

## Important Files

- `docker/Dockerfile`: custom MeshCentral image pinned to a specific upstream digest.
- `.github/workflows/deploy.yml`: build, publish, and deploy workflow for `main`.
- `.github/workflows/meshcentral-upstream-sync.yml`: upstream digest sync workflow.
- `scripts/deploy.sh`: host-side deployment, health-check, and rollback logic.
- `scripts/check_meshcentral_upstream.sh`: helper script for upstream digest comparison and Dockerfile updates.
- `docker-compose.yml`: runtime service definition for MeshCentral and Nginx.
- `nginx/meshcentral.conf`: Nginx reverse proxy config.
- `config/config.template.json`: MeshCentral config template rendered during deploy.

## GitHub Secrets

The current workflows expect these repository secrets:

- `GHCR_TOKEN`: token used by GitHub Actions to push images to GHCR.
- `BOT_PUSH_TOKEN`: token used by the upstream-sync workflow to push a bot commit to `main`.
- `EC2_HOST`: hostname or IP of the deployment target.
- `EC2_USER`: SSH user on the EC2 host.
- `EC2_SSH_KEY`: private key for the deployment user.
- `GHCR_PULL_USERNAME`: optional GHCR username used by the EC2 host for private pulls.
- `GHCR_PULL_TOKEN`: optional GHCR token used by the EC2 host for private pulls.

## EC2 Host Requirements

The current deployment flow assumes the EC2 host already has:

- Docker Engine with Docker Compose support.
- `envsubst` installed.
- A user that can run Docker commands.
- SSH access for the GitHub Actions runner.
- A writable deployment directory at `~/meshcentral` or permission for the workflow to create it.

## Local Smoke Testing

This repository is currently deployment-first, but you can still do a basic local smoke test.

1. Build the custom image:

```bash
docker build -t meshcentral-local -f docker/Dockerfile .
```

2. Create local runtime directories:

```bash
mkdir -p data backups
```

3. Render a local config file:

```bash
SERVER_IP=127.0.0.1 envsubst < config/config.template.json > data/config.json
```

4. Start the stack:

```bash
IMAGE_URI=meshcentral-local docker compose up -d
```

This is only a smoke-test path. The main supported path today is the GitHub Actions deployment flow.

## Current Limitations

- The current deploy strategy is in-place recreate plus rollback, not blue-green.
- The current persistence model is bind-mounted host storage, not named Docker volumes.
- The upstream-sync workflow depends on `BOT_PUSH_TOKEN` being configured correctly.
- The deploy script currently renders config from the host's detected public IP and assumes a fairly simple single-host setup.

## Roadmap

### Stage 1

- CI/CD foundation for building, publishing, and deploying a custom MeshCentral container.
- Scheduled/manual upstream digest sync to keep the pinned base image current.
- Basic health-check validation and rollback.

### Stage 2

- Provisioning and repeatability improvements with Terraform and Ansible.
- Cleaner host bootstrap and environment setup.
- Stronger separation between infrastructure setup and application deployment.

### Stage 3

- Automated backup workflows and retention.
- Blue-green or other lower-downtime deployment strategies.
- Stronger operational hardening, observability, and release controls.

## Notes

This repository is intentionally iterative. The current stage is useful, but incomplete by design. As later stages are implemented, parts of the workflow, runtime model, and documentation will be replaced rather than preserved for compatibility.
