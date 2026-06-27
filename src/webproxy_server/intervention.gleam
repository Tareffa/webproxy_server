//// Privileged commands available only to connections that have entered
//// intervention mode (see `engine.upgrade`). Every public function in this
//// module performs a SysAdmin-only operation and must only be reachable from
//// the `ws.Intervention` state.

import database
import gleam/dict.{type Dict}
import gleam/erlang/process.{type Subject}
import gleam/int
import gleam/list
import gleam/result
import gleam/string
import gleam/string_tree
import mist
import webproxy_server/auth
import webproxy_server/cluster.{type Cluster}
import webproxy_server/engine
import webproxy_server/ws

/// Handles the `/su-drop <table> <value>` command: deletes a single value from
/// one of the tables.
///
/// - `users`: `<value>` is the user's `display_name`, NOT their id or auth
///   token. Every stored user matching the display name is removed.
/// - `clusters`: `<value>` is a cluster id.
/// - `pending_resources`: `<value>` is a pending resource id.
pub fn drop_value(
  users: database.Table(auth.User),
  clusters: database.Table(Cluster),
  pending_resources: database.Table(engine.PendingResource),
  conn: mist.WebsocketConnection,
  state: ws.WsState,
  data: String,
) -> mist.Next(ws.WsState, a) {
  reply(conn, state, drop(users, clusters, pending_resources, data))
}

/// The side-effecting core of `drop_value`, separated from the socket I/O so it
/// can be tested. Returns the message that would be sent back to the operator.
@internal
pub fn drop(
  users: database.Table(auth.User),
  clusters: database.Table(Cluster),
  pending_resources: database.Table(engine.PendingResource),
  data: String,
) -> String {
  case data {
    "users " <> display_name ->
      case drop_users_by_display_name(users, display_name) {
        0 -> "No user found with display name " <> display_name
        count ->
          "Dropped "
          <> int.to_string(count)
          <> " user(s) with display name "
          <> display_name
      }
    "clusters " <> cluster_id ->
      drop_by_id(clusters, cluster_id, "cluster", cluster_id)
    "pending_resources " <> resource_id ->
      drop_by_id(
        pending_resources,
        resource_id,
        "pending resource",
        resource_id,
      )
    _ -> "Invalid command. Usage: /su-drop <table> <value>"
  }
}

/// Handles the `/su-clinfo` command, reporting each cluster's id, ip address,
/// organization and the display names of its members.
///
/// - `/su-clinfo` reports every cluster.
/// - `/su-clinfo <cluster_id>` reports only that cluster.
/// - `/su-clinfo user <display_name>` reports only the clusters the user with
///   that display name belongs to.
pub fn cluster_info(
  users: database.Table(auth.User),
  clusters: database.Table(Cluster),
  conn: mist.WebsocketConnection,
  state: ws.WsState,
  data: String,
) -> mist.Next(ws.WsState, a) {
  reply(conn, state, cluster_report(users, clusters, data))
}

/// The read-only core of `cluster_info`, separated from the socket I/O so it can
/// be tested. Returns the report that would be sent back to the operator.
@internal
pub fn cluster_report(
  users: database.Table(auth.User),
  clusters: database.Table(Cluster),
  data: String,
) -> String {
  let names = user_names_by_id(users)

  case data {
    "" -> format_clusters(all_clusters(clusters), names)
    "user " <> display_name ->
      format_clusters(clusters_with_user(users, clusters, display_name), names)
    cluster_id -> format_clusters(one_cluster(clusters, cluster_id), names)
  }
}

/// Handles the `/su-invalidate <resource_name>` command, pushing a
/// `/d <resource_name>` frame to live connections so they evict the cached
/// resource.
///
/// - `/su-invalidate <resource_name>` targets every connection.
/// - `/su-invalidate <resource_name> user <display_name>` targets only the
///   connections of users with that display name.
/// - `/su-invalidate <resource_name> cluster <cluster_id>` targets only the
///   connections in that cluster.
pub fn force_cache_invalidation(
  users: database.Table(auth.User),
  clusters: database.Table(Cluster),
  conn: mist.WebsocketConnection,
  state: ws.WsState,
  data: String,
) -> mist.Next(ws.WsState, a) {
  reply(conn, state, invalidate_resource(users, clusters, data))
}

/// The side-effecting core of `force_cache_invalidation`, separated from the
/// socket I/O so it can be tested. Pushes the `/d <resource_name>` frames and
/// returns the message that would be sent back to the operator.
@internal
pub fn invalidate_resource(
  users: database.Table(auth.User),
  clusters: database.Table(Cluster),
  data: String,
) -> String {
  case string.split(data, " ") {
    [resource_name, "user", display_name] ->
      report(
        invalidate(
          user_connections(users, clusters, display_name),
          resource_name,
        ),
        resource_name,
        "user " <> display_name,
      )
    [resource_name, "cluster", cluster_id] ->
      report(
        invalidate(cluster_connections(clusters, cluster_id), resource_name),
        resource_name,
        "cluster " <> cluster_id,
      )
    [resource_name] ->
      report(
        invalidate(all_connections(clusters), resource_name),
        resource_name,
        "all connections",
      )
    _ ->
      "Invalid command. Usage: /su-invalidate <resource_name> [user <display_name> | cluster <cluster_id>]"
  }
}

/// Sends `message` over the socket and stays in the current state. This is the
/// only part of each command that cannot be exercised in a unit test, so the
/// commands delegate their logic to the `@internal` cores above.
fn reply(
  conn: mist.WebsocketConnection,
  state: ws.WsState,
  message: String,
) -> mist.Next(ws.WsState, a) {
  let _ = mist.send_text_frame(conn, message)
  mist.continue(state)
}

/// Sends a `/d <resource_name>` frame to every given connection and returns how
/// many were notified.
fn invalidate(
  connections: List(Subject(ws.WsCommand)),
  resource_name: String,
) -> Int {
  let message = ws.SendText("/d " <> resource_name)
  list.each(connections, fn(connection) { process.send(connection, message) })
  list.length(connections)
}

fn report(count: Int, resource_name: String, scope: String) -> String {
  "Invalidated "
  <> resource_name
  <> " on "
  <> int.to_string(count)
  <> " connection(s) ("
  <> scope
  <> ")."
}

/// The outbound subjects of every connection in every cluster.
fn all_connections(
  clusters: database.Table(Cluster),
) -> List(Subject(ws.WsCommand)) {
  all_clusters(clusters)
  |> list.flat_map(fn(entry) {
    let #(_id, cluster) = entry
    dict.values(cluster.members)
  })
}

/// The outbound subjects of every connection belonging to a user with the given
/// display name, across all clusters.
fn user_connections(
  users: database.Table(auth.User),
  clusters: database.Table(Cluster),
  display_name: String,
) -> List(Subject(ws.WsCommand)) {
  let ids = user_ids_by_display_name(users, display_name)

  all_clusters(clusters)
  |> list.flat_map(fn(entry) {
    let #(_id, cluster) = entry
    cluster.members
    |> dict.filter(fn(user_id, _) { list.contains(ids, user_id) })
    |> dict.values()
  })
}

/// The outbound subjects of every connection in a single cluster.
fn cluster_connections(
  clusters: database.Table(Cluster),
  cluster_id: String,
) -> List(Subject(ws.WsCommand)) {
  one_cluster(clusters, cluster_id)
  |> list.flat_map(fn(entry) {
    let #(_id, cluster) = entry
    dict.values(cluster.members)
  })
}

/// Every stored cluster, paired with its id (the table key). The identity
/// `select_fn` compiles to a bare wildcard pattern, so every row matches.
fn all_clusters(clusters: database.Table(Cluster)) -> List(#(String, Cluster)) {
  let select_fn = fn(cluster: Cluster) { cluster }

  let outcome = {
    use ref <- database.transaction(clusters)
    database.select(ref, #(select_fn))
  }

  result.unwrap(outcome, [])
}

/// A single cluster looked up by id, as a (possibly empty) list so it shares the
/// formatting path with the other lookups.
fn one_cluster(
  clusters: database.Table(Cluster),
  cluster_id: String,
) -> List(#(String, Cluster)) {
  let outcome = {
    use ref <- database.transaction(clusters)
    database.find(ref, cluster_id)
  }

  case outcome {
    Ok(cluster) -> [#(cluster_id, cluster)]
    Error(_) -> []
  }
}

/// Every cluster that contains at least one user with the given display name.
fn clusters_with_user(
  users: database.Table(auth.User),
  clusters: database.Table(Cluster),
  display_name: String,
) -> List(#(String, Cluster)) {
  let ids = user_ids_by_display_name(users, display_name)

  all_clusters(clusters)
  |> list.filter(fn(entry) {
    let #(_id, cluster) = entry
    list.any(ids, fn(user_id) { dict.has_key(cluster.members, user_id) })
  })
}

/// The ids of every stored user carrying the given display name.
fn user_ids_by_display_name(
  users: database.Table(auth.User),
  display_name: String,
) -> List(String) {
  let select_fn = fn(
    id: String,
    scopes: List(String),
    organization_id: String,
    created_at: Float,
  ) {
    auth.User(id, display_name, scopes, organization_id, created_at)
  }

  let outcome = {
    use ref <- database.transaction(users)
    database.select(ref, #(select_fn))
  }

  outcome
  |> result.unwrap([])
  |> list.map(fn(entry) {
    let #(_token, user) = entry
    user.id
  })
}

/// A lookup from user id to display name, used to render cluster membership.
fn user_names_by_id(users: database.Table(auth.User)) -> Dict(String, String) {
  let select_fn = fn(user: auth.User) { user }

  let outcome = {
    use ref <- database.transaction(users)
    database.select(ref, #(select_fn))
  }

  outcome
  |> result.unwrap([])
  |> list.fold(dict.new(), fn(acc, entry) {
    let #(_token, user) = entry
    dict.insert(acc, user.id, user.display_name)
  })
}

fn format_clusters(
  clusters: List(#(String, Cluster)),
  names: Dict(String, String),
) -> String {
  case clusters {
    [] -> "No clusters found."
    _ ->
      clusters
      |> list.map(fn(entry) { format_cluster(entry, names) })
      |> string.join("\n\n")
  }
}

fn format_cluster(
  entry: #(String, Cluster),
  names: Dict(String, String),
) -> String {
  let #(id, cluster) = entry

  let members =
    cluster.members
    |> dict.keys()
    |> list.map(fn(user_id) { result.unwrap(dict.get(names, user_id), user_id) })
    |> string.join(", ")

  string_tree.from_string("Cluster ")
  |> string_tree.append(id)
  |> string_tree.append("\n  Organization: ")
  |> string_tree.append(cluster.organization_id)
  |> string_tree.append("\n  IP: ")
  |> string_tree.append(cluster.ip_address)
  |> string_tree.append("\n  Users: ")
  |> string_tree.append(members)
  |> string_tree.to_string()
}

/// Deletes a value addressed directly by its table key (clusters and pending
/// resources). ETS deletes are idempotent, so this reports success whether or
/// not the key existed.
fn drop_by_id(
  table: database.Table(a),
  id: String,
  label: String,
  value: String,
) -> String {
  let outcome = {
    use ref <- database.transaction(table)
    database.delete(ref, id)
  }

  case outcome {
    Ok(_) -> "Dropped " <> label <> " " <> value
    Error(_) -> "Unable to drop " <> label <> " " <> value
  }
}

/// Users are keyed by their auth token, so they cannot be deleted by display
/// name with a plain key lookup. Instead we select every stored user whose
/// `display_name` matches (the other fields stay wildcards) and delete each one
/// by its key. Returns the number of users removed.
fn drop_users_by_display_name(
  users: database.Table(auth.User),
  display_name: String,
) -> Int {
  let select_fn = fn(
    id: String,
    scopes: List(String),
    organization_id: String,
    created_at: Float,
  ) {
    auth.User(id, display_name, scopes, organization_id, created_at)
  }

  let outcome = {
    use ref <- database.transaction(users)
    use matches <- result.map(
      database.select(ref, #(select_fn))
      |> result.replace_error(Nil),
    )

    matches
    |> list.map(fn(entry) {
      let #(token, _user) = entry
      database.delete(ref, token)
    })
    |> list.length
  }

  result.unwrap(outcome, 0)
}
