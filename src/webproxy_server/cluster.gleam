import database
import gleam/bit_array
import gleam/crypto
import gleam/dict.{type Dict}
import gleam/erlang/atom
import gleam/result
import gleam/string
import mist
import webproxy_server/auth

pub type Cluster =
  Dict(String, mist.WebsocketConnection)

pub fn new_clusters_table() -> database.Table(Cluster) {
  atom.create("clusters_table")
  |> database.create_ets_table
}

pub fn join_cluster(
  table: database.Table(Cluster),
  user: auth.User,
  ip_address: String,
  connection: mist.WebsocketConnection,
) -> Result(String, Nil) {
  let cluster_id =
    bit_array.from_string(user.organization_id <> "##" <> ip_address)
    |> crypto.hash(crypto.Sha512, _)
    |> bit_array.base64_url_encode(True)
  let query = {
    use ref <- database.transaction(table)
    database.find(ref, cluster_id)
    |> result.unwrap(dict.new())
    |> dict.insert(user.id, connection)
    |> database.upsert(ref, user.id, _)
  }
  echo "Join cluster query result: " <> string.inspect(query)
  Ok(cluster_id)
}

pub fn get_connected_peers(
  table: database.Table(Cluster),
  id: String,
  user_id: String,
) -> Dict(String, mist.WebsocketConnection) {
  let query = {
    use ref <- database.transaction(table)
    database.find(ref, id)
  }
  echo "Connected peers query result: " <> string.inspect(query)
  result.unwrap(query, dict.new())
  |> dict.filter(fn(key, _) { key != user_id })
}
