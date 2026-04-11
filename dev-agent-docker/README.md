# Dev Agent Docker

`dev-agent-docker/` is an all-in-one development workstation container for Hermes-based workflows.

It is intentionally different from the main `docker/` directory:

- `docker/` is the official Hermes-in-Docker runtime described in the user docs.
- `dev-agent-docker/` is a developer-focused workspace container with SSH access, extra tools, and a background Hermes gateway.

## What It Includes

- Hermes CLI
- Hermes gateway running inside the container
- OpenCode
- Claude Code
- lark-cli
- SSH access for interactive development
- A bind-mounted host workspace at `/workspace`

## Usage

```bash
cd dev-agent-docker
cp .env.example .env
mkdir -p ~/code/workspace
docker compose up -d --build
ssh -p 2222 root@localhost
```

## Logs

```bash
docker compose logs -f dev-agent
```

or:

```bash
docker logs -f agent-dev
```

## Persistent Data

The container persists these locations with named volumes:

- `/root/.hermes`
- `/root/.opencode`
- `/root/.config`
- `/root/.local/share`
- `/root/.claude`
- `/root/.lark-cli`
- `/root/.ssh`

The host workspace is bind-mounted to `/workspace`.

## Notes

- This is a developer workstation container, not the primary project Docker runtime.
- `sshd` and `hermes gateway` run in the same container so installed tools and runtime state are shared.
