# WebProxy Server

WebProxy Server is a distributed cache engine for organizational systems. It authenticates users against your own authentication service, groups them into clusters, and relays resource requests and responses only within the matching cluster.

## How It Works

The runtime is intentionally small:

1. The frontend [WebProxy client](https://www.npmjs.com/package/webproxy-client) opens the websocket endpoint.
2. The client sends an authentication token with `/s <token>`.
3. The server calls your authentication service using `AUTHENTICATION_URL`.
4. If the token is valid, the user is cached and added to a cluster, based on the user's organization and network.
5. Resource requests are broadcast only to peers in the same cluster.
6. Responses are routed back to the requesting user.

## Environment Variables

All configuration is read from environment variables, centralized in `src/webproxy_server/environment.gleam`.

| Variable | Required | Default | Description |
| --- | --- | --- | --- |
| `AUTHENTICATION_URL` | Yes | — | Full HTTPS URL of your authentication endpoint. Must start with `https://`. The server refuses to start without a valid value. See [Authentication Service](#authentication-service). |
| `PORT` | No | `8080` | TCP port the server binds to. Falls back to `8080` when unset or invalid. |
| `AUTHORIZED_ADMINISTRATOR_IPS` | No | `[]` | JSON array of IP addresses allowed to use the `/upgrade` intervention command. See [Administrator IPs](#administrator-ips). |
| `USE_NATIVE_CONNECTION_IP` | No | `false` | When `false` (the default, for deployments behind a reverse proxy), the client IP is read from the `X-Forwarded-For` header, falling back to `X-Real-IP`. When `true`, or when neither header is present, the transport-level connection IP is used. Accepts `true`/`1` for true; any other value is false. See [Client IP Resolution](#client-ip-resolution). |

### Client IP Resolution

The server identifies each connecting client by IP, which feeds authorization and the [Administrator IPs](#administrator-ips) gate. Because the server usually sits behind a reverse proxy, by default it trusts the `X-Forwarded-For` header (falling back to `X-Real-IP`) rather than the raw socket address.

- **`USE_NATIVE_CONNECTION_IP` unset or `false`** → use `X-Forwarded-For`, then `X-Real-IP`, then the transport-level connection IP if neither header is present.
- **`USE_NATIVE_CONNECTION_IP=true`** → always use the transport-level connection IP, ignoring the headers. Use this only when clients connect directly, since forwarded headers can be spoofed when not set by a trusted proxy.

### Administrator IPs

`AUTHORIZED_ADMINISTRATOR_IPS` is a JSON string holding an array of IP addresses, for example `["10.0.0.5", "10.0.0.6"]`. It gates the `/upgrade` command on top of the existing SysAdmin check, so a SysAdmin must also connect from an authorized IP to enter intervention mode.

- **Unset, empty, or malformed** → the list is treated as empty and **no one** is allowed to upgrade.
- **Contains `"*"`** → **any** IP address is allowed to upgrade. The server prints a warning at boot because this is potentially dangerous.
- **Otherwise** → only the listed IP addresses are allowed to upgrade.

## Authentication Service

Set `AUTHENTICATION_URL` to the full HTTPS URL of your authentication endpoint.

The WebProxy sends a `GET` request to that URL with these headers:

- `Authorization: <user token>`
- `Accept: application/json`

Your service should return a non-2xx response for an invalid token. For a valid token, return a JSON user object with this shape:

```json
{
  "id": "string",
  "displayName": "string",
  "organization_id": "string",
  "scopes": ["string"],
  "isAdmin": false
}
```

Field details:

- `id`: unique user identifier
- `displayName`: human-readable username, such as an email address
- `organization_id`: the user's organization identifier
- `scopes`: array of scopes granted to the user
- `isAdmin`: whether the user is a trusted internal SysAdmin

**VERY IMPORTANT**:

- Only trusted internal users should have `isAdmin: true`.
- The server treats `isAdmin: true` users as SysAdmins, which unlocks special intervention commands.
- `created_at` is added by the server at decode time and is not required from the auth service.

## Clustering And Data Sharing

Users are partitioned into clusters using their `organization_id` and the client network identity captured from the websocket connection.

In practice, the current implementation hashes the pair `(organization_id, client IP address)` into a cluster id. Users only share cache traffic with peers that resolve to the same cluster id, so data never leaves the organization-and-network boundary that produced that cluster.

If you need a different grouping rule, update the cluster id generation in `src/webproxy_server/cluster.gleam`.

## HTTP Endpoints

| Method | Path | What it does |
| --- | --- | --- |
| `GET` | `/health` | Returns `200` with `{"status":"UP"}` for liveness checks. |
| `GET` | `/ws` | Upgrades the connection to a websocket and starts the WebProxy protocol. |

## Websocket Protocol

### Client To Server

| Message | Who can send it | What it does |
| --- | --- | --- |
| `ping` | Any connected client | Returns `pong`. Useful as a lightweight heartbeat. |
| `/s <auth_token>` | Unauthenticated client | Authenticates the user, joins the cluster, and replies with `subscribed` on success. |
| `/r <resource_name>` | Authenticated client | Requests a resource from peers in the same cluster. The server queues the request and forwards it to connected peers. |
| `/p <resource_id> <response_json>` | Authenticated client | Provides a response for a previously requested resource. The server routes the response back to the original requester. |
| `/upgrade` | Authenticated SysAdmin from an authorized IP | Switches the connection into intervention mode. Non-admin users, and SysAdmins connecting from an IP not listed in `AUTHORIZED_ADMINISTRATOR_IPS`, are rejected. |
| `/su-drop <table> <value>` | Intervention mode only | Deletes a single value from a table. See [Intervention Commands](#intervention-commands). |
| `/su-clinfo [<cluster_id> \| user <display_name>]` | Intervention mode only | Reports cluster membership. See [Intervention Commands](#intervention-commands). |
| `/su-invalidate <resource_name> [user <display_name> \| cluster <cluster_id>]` | Intervention mode only | Forces connected clients to evict a cached resource. See [Intervention Commands](#intervention-commands). |

### Server To Client

| Message | Who receives it | What it does |
| --- | --- | --- |
| `pong` | The client that sent `ping` | Heartbeat response. |
| `subscribed` | The client that sent `/s <auth_token>` | Confirms successful authentication and cluster membership. |
| `/r {resource request json}` | Peers in the same cluster | Broadcasts a resource petition containing `resourceId`, `scopes`, and `resourceName`. |
| `/p <resource_name> <response_json>` | The original requester | Delivers the response payload for the pending resource. |
| `Successfully upgraded. You are now in intervention mode.` | A SysAdmin that sent `/upgrade` | Confirms that the connection has been upgraded. |
| `/d <resource_name>` | Clients targeted by `/su-invalidate` | Instructs the client to evict the named resource from its cache. |

### Intervention Commands

Once a SysAdmin connection has entered intervention mode with `/upgrade`, the following privileged commands become available. They are rejected on any other connection. Each command replies with a short status line.

#### `/su-drop <table> <value>`

Deletes a single value from one of the tables. `<table>` is one of:

- `users` — `<value>` is the user's `display_name` (NOT their id or auth token). Every stored user with that display name is removed.
- `clusters` — `<value>` is a cluster id.
- `pending_resources` — `<value>` is a pending resource id.

#### `/su-clinfo [<cluster_id> | user <display_name>]`

Reports each matching cluster's id, ip address, organization, and the display names of its members.

- `/su-clinfo` — reports every cluster.
- `/su-clinfo <cluster_id>` — reports only that cluster.
- `/su-clinfo user <display_name>` — reports only the clusters the named user belongs to.

#### `/su-invalidate <resource_name> [user <display_name> | cluster <cluster_id>]`

Pushes a `/d <resource_name>` frame to live connections so they evict the cached resource.

- `/su-invalidate <resource_name>` — targets every connection.
- `/su-invalidate <resource_name> user <display_name>` — targets only the connections of the named user.
- `/su-invalidate <resource_name> cluster <cluster_id>` — targets only the connections in that cluster.

### Resource Exchange Flow

The request path is designed for cache sharing between nodes in the same organization and network:

1. A client asks for a resource with `/r <resource_name>`.
2. The server stores a pending resource entry.
3. The request is broadcast to peers in the same cluster.
4. A peer answers with `/p <resource_id> <response_json>`.
5. The server deletes the pending entry and forwards the response to the original requester.

## Development

```sh
gleam run  # Run the project
gleam test # Run the tests
```

## How To Run

### Docker

Build the image:

```sh
docker build -t webproxy-server .
```

Run the container:

```sh
docker run --rm \
  -e AUTHENTICATION_URL="https://your-auth-server.example.com/auth" \
  -e PORT=8080 \
  -e AUTHORIZED_ADMINISTRATOR_IPS='["10.0.0.5"]' \
  -p 8080:8080 \
  webproxy-server
```

Docker is the recommended way to run the service in production or in a test environment that should match the release image.

### Gleam

For local development, run the project directly with Gleam:

```sh
export AUTHENTICATION_URL="https://your-auth-server.example.com/auth"
export PORT=8080
export AUTHORIZED_ADMINISTRATOR_IPS='["10.0.0.5"]'
gleam run
```

If `PORT` is not set, the server falls back to `8080`. See [Environment Variables](#environment-variables) for the full list.

## License

This project is licensed under the MIT License. See [LICENSE](LICENSE).
