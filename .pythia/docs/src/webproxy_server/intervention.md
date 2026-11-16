# webproxy_server/intervention.gleam

## Description

The `webproxy_server/intervention.gleam` module provides a set of privileged commands for advanced users who need to perform administrative tasks. These commands are designed to be used by connections that have entered the `ws.Intervention` state, ensuring that only authorized personnel can execute these operations.

### Public Functions and Constants

#### `drop_value`

```gleam
pub fn drop_value(
  users: database.Table(auth.User),
  clusters: database.Table(Cluster),
  pending_resources: database.Table(engine.PendingResource),
  conn: mist.WebsocketConnection,
  state: ws.WsState,
  data: String,
) -> mist.Next(ws.WsState, a)
```

- **Parameters**:
  - `users`: A table containing user information.
  - `clusters`: A table containing cluster information.
  - `pending_resources`: A table containing pending resource information.
  - `conn`: The websocket connection object.
  - `state`: The current state of the WebSocket session.
  - `data`: The data sent by the client, which contains the operation to be performed.

- **Behavior**:
  - Parses the command string and calls the `drop` function with the appropriate parameters.
  - Returns the response message sent back to the client.

#### `cluster_info`

```gleam
pub fn cluster_info(
  users: database.Table(auth.User),
  clusters: database.Table(Cluster),
  conn: mist.WebsocketConnection,
  state: ws.WsState,
  data: String,
) -> mist.Next(ws.WsState, a)
```

- **Parameters**:
  - `users`: A table containing user information.
  - `clusters`: A table containing cluster information.
  - `conn`: The websocket connection object.
  - `state`: The current state of the WebSocket session.
  - `data`: The data sent by the client, which contains the operation to be performed.

- **Behavior**:
  - Parses the command string and calls the `cluster_report` function with the appropriate parameters.
  - Returns the response message sent back to the client.

#### `force_cache_invalidation`

```gleam
pub fn force_cache_invalidation(
  users: database.Table(auth.User),
  clusters: database.Table(Cluster),
  conn: mist.WebsocketConnection,
  state: ws.WsState,
  data: String,
) -> mist.Next(ws.WsState, a)
```

- **Parameters**:
  - `users`: A table containing user information.
  - `clusters`: A table containing cluster information.
  - `conn`: The websocket connection object.
  - `state`: The current state of the WebSocket session.
  - `data`: The data sent by the client, which contains the operation to be performed.

- **Behavior**:
  - Parses the command string and calls the `invalidate_resource` function with the appropriate parameters.
  - Returns the response message sent back to the client.

### Internal Logic

#### `drop`

```gleam
@internal
pub fn drop(
  users: database.Table(auth.User),
  clusters: database.Table(Cluster),
  pending_resources: database.Table(engine.PendingResource),
  data: String,
) -> String
```

- **Parameters**:
  - `users`: A table containing user information.
  - `clusters`: A table containing cluster information.
  - `pending_resources`: A table containing pending resource information.
  - `data`: The data sent by the client, which contains the command to be performed.

- **Behavior**:
  - Parses the command string and calls the corresponding operation function (`drop_users_by_display_name` for users, `drop_by_id` for clusters and pending resources).
  - Returns the message that would be sent back to the client after executing the operation.

#### `cluster_report`

```gleam
@internal
pub fn cluster_report(
  users: database.Table(auth.User),
  clusters: database.Table(Cluster),
  data: String,
) -> String
```

- **Parameters**:
  - `users`: A table containing user information.
  - `clusters`: A table containing cluster information.
  - `data`: The data sent by the client, which contains the command to be performed.

- **Behavior**:
  - Parses the command string and calls the corresponding operation function (`all_clusters`, `one_cluster`, or `user_connections`).
  - Returns the report that would be sent back to the client after executing the operation.

### Side Effects

The commands perform side effects, such as deleting records from databases and invalidating caches for live connections. These operations are intended to be used by authenticated users who have been granted access to these privileged functions.
