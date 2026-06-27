import database
import gleam/dict.{type Dict}
import gleam/erlang/atom
import gleam/erlang/process.{type Subject}
import gleam/list
import gleam/string
import webproxy_server/auth
import webproxy_server/cluster
import webproxy_server/engine
import webproxy_server/intervention
import webproxy_server/ws

// --- helpers ---------------------------------------------------------------

fn insert_user(
  users: database.Table(auth.User),
  token: String,
  id: String,
  display_name: String,
) -> Nil {
  let assert Ok(_) = {
    use ref <- database.transaction(users)
    database.upsert(ref, token, auth.User(id, display_name, [], "org", 0.0))
  }
  Nil
}

fn insert_cluster(
  clusters: database.Table(cluster.Cluster),
  id: String,
  organization_id: String,
  ip_address: String,
  members: Dict(String, Subject(ws.WsCommand)),
) -> Nil {
  let assert Ok(_) = {
    use ref <- database.transaction(clusters)
    database.upsert(
      ref,
      id,
      cluster.Cluster(organization_id, ip_address, members),
    )
  }
  Nil
}

/// A membership dict with a fresh (never-read) subject per user id.
fn members(ids: List(String)) -> Dict(String, Subject(ws.WsCommand)) {
  list.fold(ids, dict.new(), fn(acc, id) {
    dict.insert(acc, id, process.new_subject())
  })
}

/// The sorted display names of every stored user, for asserting deletions.
fn display_names(users: database.Table(auth.User)) -> List(String) {
  let select_fn = fn(user: auth.User) { user }
  let assert Ok(rows) = {
    use ref <- database.transaction(users)
    database.select(ref, #(select_fn))
  }

  rows
  |> list.map(fn(row) {
    let #(_token, user) = row
    user.display_name
  })
  |> list.sort(string.compare)
}

fn find_cluster(clusters: database.Table(cluster.Cluster), id: String) {
  use ref <- database.transaction(clusters)
  database.find(ref, id)
}

// --- drop ------------------------------------------------------------------

pub fn drop_users_test() {
  let users = auth.new_user_table()
  let clusters = cluster.new_clusters_table()
  let pending = engine.new_pending_resources_queue()

  insert_user(users, "tok-a", "id-a", "alice")
  insert_user(users, "tok-a2", "id-a2", "alice")
  insert_user(users, "tok-b", "id-b", "bob")

  let reply = intervention.drop(users, clusters, pending, "users alice")
  assert reply == "Dropped 2 user(s) with display name alice"
  assert display_names(users) == ["bob"]
}

pub fn drop_users_none_test() {
  let users = auth.new_user_table()
  let clusters = cluster.new_clusters_table()
  let pending = engine.new_pending_resources_queue()

  insert_user(users, "tok-b", "id-b", "bob")

  let reply = intervention.drop(users, clusters, pending, "users alice")
  assert reply == "No user found with display name alice"
  assert display_names(users) == ["bob"]
}

pub fn drop_cluster_test() {
  let users = auth.new_user_table()
  let clusters = cluster.new_clusters_table()
  let pending = engine.new_pending_resources_queue()

  insert_cluster(clusters, "cl-1", "org1", "10.0.0.1", dict.new())

  let reply = intervention.drop(users, clusters, pending, "clusters cl-1")
  assert reply == "Dropped cluster cl-1"

  let assert Error(_) = find_cluster(clusters, "cl-1")
}

pub fn drop_pending_resource_test() {
  let users = auth.new_user_table()
  let clusters = cluster.new_clusters_table()
  let pending = engine.new_pending_resources_queue()

  let reply =
    intervention.drop(users, clusters, pending, "pending_resources res-1")
  assert reply == "Dropped pending resource res-1"
}

pub fn drop_invalid_test() {
  let users = auth.new_user_table()
  let clusters = cluster.new_clusters_table()
  let pending = engine.new_pending_resources_queue()

  let reply = intervention.drop(users, clusters, pending, "bogus thing")
  assert reply == "Invalid command. Usage: /su-drop <table> <value>"
}

// --- cluster_report --------------------------------------------------------

pub fn cluster_report_all_test() {
  let users = auth.new_user_table()
  let clusters = cluster.new_clusters_table()

  insert_user(users, "tok-a", "id-a", "alice")
  insert_user(users, "tok-b", "id-b", "bob")
  insert_cluster(
    clusters,
    "cl-1",
    "org1",
    "10.0.0.1",
    members(["id-a", "id-b"]),
  )

  let report = intervention.cluster_report(users, clusters, "")
  assert string.contains(report, "Cluster cl-1")
  assert string.contains(report, "Organization: org1")
  assert string.contains(report, "IP: 10.0.0.1")
  assert string.contains(report, "alice")
  assert string.contains(report, "bob")
}

pub fn cluster_report_single_test() {
  let users = auth.new_user_table()
  let clusters = cluster.new_clusters_table()

  insert_cluster(clusters, "cl-1", "org1", "10.0.0.1", dict.new())
  insert_cluster(clusters, "cl-2", "org2", "10.0.0.2", dict.new())

  let report = intervention.cluster_report(users, clusters, "cl-1")
  assert string.contains(report, "Cluster cl-1")
  assert string.contains(report, "Cluster cl-2") == False
}

pub fn cluster_report_by_user_test() {
  let users = auth.new_user_table()
  let clusters = cluster.new_clusters_table()

  insert_user(users, "tok-a", "id-a", "alice")
  insert_user(users, "tok-b", "id-b", "bob")
  insert_cluster(clusters, "cl-1", "org1", "10.0.0.1", members(["id-a"]))
  insert_cluster(clusters, "cl-2", "org2", "10.0.0.2", members(["id-b"]))

  let report = intervention.cluster_report(users, clusters, "user alice")
  assert string.contains(report, "Cluster cl-1")
  assert string.contains(report, "Cluster cl-2") == False
}

pub fn cluster_report_missing_test() {
  let users = auth.new_user_table()
  let clusters = cluster.new_clusters_table()

  let report = intervention.cluster_report(users, clusters, "does-not-exist")
  assert report == "No clusters found."
}

// --- invalidate_resource ---------------------------------------------------

pub fn invalidate_all_test() {
  let users = auth.new_user_table()
  let clusters = cluster.new_clusters_table()

  let sub_a = process.new_subject()
  let sub_b = process.new_subject()
  insert_cluster(clusters, "cl-1", "o", "i", dict.from_list([#("id-a", sub_a)]))
  insert_cluster(clusters, "cl-2", "o", "i", dict.from_list([#("id-b", sub_b)]))

  let reply = intervention.invalidate_resource(users, clusters, "cache1")
  assert reply == "Invalidated cache1 on 2 connection(s) (all connections)."
  assert process.receive(sub_a, 50) == Ok(ws.SendText("/d cache1"))
  assert process.receive(sub_b, 50) == Ok(ws.SendText("/d cache1"))
}

pub fn invalidate_user_test() {
  let users = auth.new_user_table()
  let clusters = cluster.new_clusters_table()

  insert_user(users, "tok-a", "id-a", "alice")
  insert_user(users, "tok-b", "id-b", "bob")
  let sub_a = process.new_subject()
  let sub_b = process.new_subject()
  insert_cluster(
    clusters,
    "cl-1",
    "o",
    "i",
    dict.from_list([#("id-a", sub_a), #("id-b", sub_b)]),
  )

  let reply =
    intervention.invalidate_resource(users, clusters, "cache1 user alice")
  assert reply == "Invalidated cache1 on 1 connection(s) (user alice)."
  // Only alice's connection is notified.
  assert process.receive(sub_a, 50) == Ok(ws.SendText("/d cache1"))
  assert process.receive(sub_b, 10) == Error(Nil)
}

pub fn invalidate_cluster_test() {
  let users = auth.new_user_table()
  let clusters = cluster.new_clusters_table()

  let sub_a = process.new_subject()
  let sub_b = process.new_subject()
  insert_cluster(clusters, "cl-1", "o", "i", dict.from_list([#("id-a", sub_a)]))
  insert_cluster(clusters, "cl-2", "o", "i", dict.from_list([#("id-b", sub_b)]))

  let reply =
    intervention.invalidate_resource(users, clusters, "cache1 cluster cl-1")
  assert reply == "Invalidated cache1 on 1 connection(s) (cluster cl-1)."
  // Only the targeted cluster is notified.
  assert process.receive(sub_a, 50) == Ok(ws.SendText("/d cache1"))
  assert process.receive(sub_b, 10) == Error(Nil)
}

pub fn invalidate_invalid_test() {
  let users = auth.new_user_table()
  let clusters = cluster.new_clusters_table()

  let reply = intervention.invalidate_resource(users, clusters, "a b c d")
  assert reply
    == "Invalid command. Usage: /su-invalidate <resource_name> [user <display_name> | cluster <cluster_id>]"
}

// --- select idioms ---------------------------------------------------------

/// Confirms the select-by-display_name technique used by
/// `intervention.drop_users_by_display_name`: a `select_fn` that fixes
/// `display_name` and leaves the other fields as wildcards must return exactly
/// the stored `User` records carrying that display name (keyed by auth token).
pub fn select_users_by_display_name_test() {
  let users =
    atom.create("intervention_test_users")
    |> database.create_ets_table()

  let assert Ok(_) = {
    use ref <- database.transaction(users)
    let assert Ok(_) =
      database.upsert(
        ref,
        "tok-alice",
        auth.User("id-a", "alice", [], "org", 1.0),
      )
    let assert Ok(_) =
      database.upsert(ref, "tok-bob", auth.User("id-b", "bob", [], "org", 2.0))
    let assert Ok(_) =
      database.upsert(
        ref,
        "tok-alice-2",
        auth.User("id-a2", "alice", ["x"], "org2", 3.0),
      )
    Ok(Nil)
  }

  let display_name = "alice"
  let select_fn = fn(
    id: String,
    scopes: List(String),
    organization_id: String,
    created_at: Float,
  ) {
    auth.User(id, display_name, scopes, organization_id, created_at)
  }

  let assert Ok(rows) = {
    use ref <- database.transaction(users)
    database.select(ref, #(select_fn))
  }

  // Both "alice" rows match; "bob" does not.
  assert list.length(rows) == 2

  let all_alice =
    list.all(rows, fn(row) {
      let #(_token, user) = row
      user.display_name == "alice"
    })
  assert all_alice == True

  // The keys returned are the auth tokens, which is what delete uses.
  let tokens = list.map(rows, fn(row) { row.0 }) |> list.sort(string.compare)
  assert tokens == ["tok-alice", "tok-alice-2"]
}

/// Confirms the identity `select_fn` used by `intervention.all_clusters`
/// compiles to a wildcard pattern and returns every stored cluster.
pub fn select_all_clusters_test() {
  let clusters =
    atom.create("intervention_test_clusters")
    |> database.create_ets_table()

  let assert Ok(_) = {
    use ref <- database.transaction(clusters)
    let assert Ok(_) =
      database.upsert(
        ref,
        "cl-1",
        cluster.Cluster("org1", "10.0.0.1", dict.new()),
      )
    let assert Ok(_) =
      database.upsert(
        ref,
        "cl-2",
        cluster.Cluster("org2", "10.0.0.2", dict.new()),
      )
    Ok(Nil)
  }

  let select_fn = fn(cluster: cluster.Cluster) { cluster }
  let assert Ok(rows) = {
    use ref <- database.transaction(clusters)
    database.select(ref, #(select_fn))
  }

  assert list.length(rows) == 2

  let ids = list.map(rows, fn(row) { row.0 }) |> list.sort(string.compare)
  assert ids == ["cl-1", "cl-2"]
}
