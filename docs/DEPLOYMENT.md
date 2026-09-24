# Deployment

The relay is deployed as a single Docker container on an Ubuntu 24.04 droplet (DigitalOcean, `fra1`).

| Item | Value |
|---|---|
| Relay | `http://104.248.131.165:8080` |
| Swagger UI | `http://104.248.131.165:8080/swagger-ui.html` |
| Health | `http://104.248.131.165:8080/actuator/health` |
| WebSocket | `ws://104.248.131.165:8080/ws` |
| Demo users | `alice` / `cipher-alice`, `bob` / `cipher-bob`, `echo` / `cipher-echo` |

## Layout on the server

```
/opt/cipher/
├── docker-compose.yml   # eclipse-temurin:21-jre running the jar, joined to the database network
├── cipher-relay.jar     # built from main with: cd backend && mvn -DskipTests package
├── .env                 # mode 600 — profile, DATABASE_*, JWT_SECRET, ATTACHMENTS_PATH (never committed)
└── blobs/               # encrypted attachment blobs (opaque, UUID-named)
```

The container joins the existing `backend_chibuku-net` Docker network and talks to the shared
PostgreSQL 16 container over the private network. The relay has its own `cipher` database and
role; nothing else on that instance is touched. Memory is capped at 900 MB with `-Xmx512m`.

## Profile choice

The server runs the `dev` profile with real secrets injected from `.env`. That profile is what
enables the demo seeder (`alice`, `bob`, `echo`) so reviewers can sign in immediately; the
`prod` profile disables seeding and has no defaults for any secret.

## Redeploy

```sh
cd backend && mvn -DskipTests package
scp target/cipher-relay-0.1.0-SNAPSHOT.jar root@104.248.131.165:/opt/cipher/cipher-relay.jar
ssh root@104.248.131.165 'cd /opt/cipher && docker compose restart relay'
```

## Pointing the app at the server

In the app, open Settings → Server URL and enter `http://104.248.131.165:8080`. The simulator
default remains `http://localhost:8080` for `make up`.

## Not yet wired

Attachment blobs live on a local Docker volume. An S3-compatible adapter (DigitalOcean Spaces)
slots in behind the `BlobStorage` port without touching the rest of the service.
