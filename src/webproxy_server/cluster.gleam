import database
import gleam/bit_array
import gleam/crypto
import gleam/dict.{type Dict}
import gleam/erlang/atom
import gleam/erlang/process.{type Subject}
import gleam/result
import webproxy_server/auth
import webproxy_server/ws

/// A cluster groups every connection that resolves to the same
/// `(organization_id, ip_address)` pair. The pair is kept alongside the members
/// so it can be reported even though the cluster id itself is a one-way hash.
pub type Cluster {
  Cluster(
    organization_id: String,
    ip_address: String,
    members: Dict(String, Subject(ws.WsCommand)),
  )
}

pub fn new_clusters_table() -> database.Table(Cluster) {
  atom.create("clusters_table")
  |> database.create_ets_table
}

pub fn join_cluster(
  table: database.Table(Cluster),
  user: auth.User,
  ip_address: String,
  outbound: Subject(ws.WsCommand),
) -> Result(String, Nil) {
  let cluster_id =
    bit_array.from_string(user.organization_id <> "##" <> ip_address)
    |> crypto.hash(crypto.Sha512, _)
    |> bit_array.base64_url_encode(True)
  let _query = {
    use ref <- database.transaction(table)
    let cluster =
      database.find(ref, cluster_id)
      |> result.unwrap(Cluster(user.organization_id, ip_address, dict.new()))
    let members = dict.insert(cluster.members, user.id, outbound)
    database.upsert(ref, cluster_id, Cluster(..cluster, members:))
  }
  Ok(cluster_id)
}

pub fn leave_cluster(
  table: database.Table(Cluster),
  cluster_id: String,
  user_id: String,
) -> Nil {
  let _ = {
    use ref <- database.transaction(table)
    case database.find(ref, cluster_id) {
      Error(_) -> Ok(Nil)
      Ok(cluster) -> {
        let members = dict.delete(cluster.members, user_id)
        case dict.is_empty(members) {
          True -> database.delete(ref, cluster_id)
          False ->
            database.upsert(ref, cluster_id, Cluster(..cluster, members:))
            |> result.map(fn(_) { Nil })
        }
      }
    }
  }
  Nil
}

pub fn get_connected_peers(
  table: database.Table(Cluster),
  id: String,
  user_id: String,
) -> Dict(String, Subject(ws.WsCommand)) {
  let query = {
    use ref <- database.transaction(table)
    database.find(ref, id)
  }
  case query {
    Ok(cluster) -> dict.filter(cluster.members, fn(key, _) { key != user_id })
    Error(_) -> dict.new()
  }
}
