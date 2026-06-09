import database
import gleam/bit_array
import gleam/crypto
import gleam/dict.{type Dict}
import gleam/erlang/atom
import gleam/erlang/process.{type Subject}
import gleam/result
import webproxy_server/auth
import webproxy_server/ws

pub type Cluster =
  Dict(String, Subject(ws.WsCommand))

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
    database.find(ref, cluster_id)
    |> result.unwrap(dict.new())
    |> dict.insert(user.id, outbound)
    |> database.upsert(ref, cluster_id, _)
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
    let members =
      database.find(ref, cluster_id)
      |> result.unwrap(dict.new())
      |> dict.delete(user_id)

    case dict.is_empty(members) {
      True -> database.delete(ref, cluster_id)
      False ->
        database.upsert(ref, cluster_id, members) |> result.map(fn(_) { Nil })
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
  result.unwrap(query, dict.new())
  |> dict.filter(fn(key, _) { key != user_id })
}
