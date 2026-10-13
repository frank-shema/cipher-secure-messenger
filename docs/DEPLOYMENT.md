# Deployment

The relay runs as two Docker containers (relay + its own PostgreSQL 16) on a Hetzner Ubuntu host, published on port 8090. It replaced the original DigitalOcean droplet deployment on 2026-10-13 after that droplet was decommissioned.

| Item | Value |
|---|---|
| Relay | `http://138.201.153.167:8090` |
| Swagger UI | `http://138.201.153.167:8090/swagger-ui.html` |
| Health | `http://138.201.153.167:8090/actuator/health` |
| WebSocket | `ws://138.201.153.167:8090/ws` |
| Demo users | `alice` / `cipher-alice`, `bob` / `cipher-bob`, `echo` / `cipher-echo` |

## Layout on the server

```
/opt/cipher/
├── docker-compose.yml   # cipher-db (postgres:16-alpine, named volume) + relay (eclipse-temurin:21-jre), port 8090 → 8080
├── cipher-relay.jar     # built from main with: cd backend && mvn -DskipTests package
├── .env                 # mode 600 — profile, DATABASE_*, POSTGRES_PASSWORD, JWT_SECRET, ATTACHMENTS_PATH (never committed)
└── blobs/               # encrypted attachment blobs (opaque, UUID-named)
```

The relay and its database share a private Compose network; only port 8090 is published and
allowed through `ufw`. Nothing else on the host is touched. Memory is capped at 1.5 GB with
`-Xmx768m`.

## Profile choice

The server runs the `dev` profile with real secrets injected from `.env`. That profile is what
enables the demo seeder (`alice`, `bob`, `echo`) so reviewers can sign in immediately; the
`prod` profile disables seeding and has no defaults for any secret.

## Redeploy

```sh
cd backend && mvn -DskipTests package
scp target/cipher-relay-0.1.0-SNAPSHOT.jar root@138.201.153.167:/opt/cipher/cipher-relay.jar
ssh root@138.201.153.167 'cd /opt/cipher && docker compose restart relay'
```

## Pointing the app at the server

In the app, open Settings → Server URL and enter `http://138.201.153.167:8090`. The simulator
default remains `http://localhost:8080` for `make up`.

## Not yet wired

Attachment blobs live on a local Docker volume. An S3-compatible adapter (DigitalOcean Spaces)
slots in behind the `BlobStorage` port without touching the rest of the service.
