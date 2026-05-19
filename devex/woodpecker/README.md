# Forgejo + Woodpecker Bootstrap Guide

## Generate Agent Secret

```bash
openssl rand -hex 32
```

Use the generated value for:

```bash
WOODPECKER_AGENT_SECRET=
```

in your `.env` file.

---

## Start Forgejo First

```bash
docker compose up -d forgejo
```

Open Forgejo:

```text
http://localhost:3000
```

Create your initial Forgejo admin user.

---

## Create OAuth Application for Woodpecker

In Forgejo:

```text
User Settings → Applications → OAuth2 Applications → Create Application
```

Use this callback URL:

```text
http://localhost:8000/authorize
```

After creating the OAuth app, copy the generated:

* Client ID
* Client Secret

into your `.env` file:

```bash
WOODPECKER_FORGEJO_CLIENT=your-client-id
WOODPECKER_FORGEJO_SECRET=your-client-secret
```

---

## Start Full Stack

```bash
docker compose up -d
```

Woodpecker UI:

```text
http://localhost:8000
```

---

## Tiny Test Pipeline

Create `.woodpecker.yml` in your repo root:

```yaml
steps:
  smoke:
    image: alpine:3.20
    commands:
      - echo "Woodpecker works"
      - uname -a
```

Commit and push.

Then:

1. Open Woodpecker
2. Activate the repository
3. Trigger the pipeline

---

## Important Networking Gotcha

`FORGEJO_ROOT_URL` must be reachable from:

* the browser
* Woodpecker server
* Woodpecker agent

For a VM or remote host, do not leave it as `localhost`.

Use the VM hostname or IP instead:

```bash
FORGEJO_DOMAIN=my-dev-vm
FORGEJO_ROOT_URL=http://my-dev-vm:3000
WOODPECKER_HOST=http://my-dev-vm:8000
```

If these URLs are wrong, OAuth redirects and repo webhooks will fail in weird and annoying ways.

---

## Useful Notes

Forgejo Docker config supports:

```text
FORGEJO__section__key
```

style environment variables.

Woodpecker Forgejo integration uses:

```text
WOODPECKER_FORGEJO_*
```

variables.

---

## Handy Commands

View logs:

```bash
docker compose logs -f forgejo
docker compose logs -f woodpecker-server
docker compose logs -f woodpecker-agent
```

Restart stack:

```bash
docker compose restart
```

Stop stack:

```bash
docker compose down
```

Destroy everything including data:

```bash
docker compose down -v
```

(Nuclear option. Deletes Forgejo repos, users, and CI state.)
