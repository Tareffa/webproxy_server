# Cluster Service

The `cluster.gleam` file implements a cluster service for web proxy servers. It maintains clusters that group every connection to the same `(organization_id, ip_address)` pair. Each member of the cluster is identified by a unique identifier and can be connected via a WebSocket command. The cluster service provides functionality to join, leave, and retrieve connected peers.

## Types

### Cluster
```gleam
pub type Cluster {
  Cluster(
    organization_id: String,
    ip_address: String,
    members: Dict(String, Subject(ws.WsCommand)),
  )
}
```
A `Cluster` contains information about the organization and IP address associated with the cluster, along with a dictionary of members.

### User
```gleam
type User = {
  id: String,
  organization_id: String,
}
```
A `User` represents a user in the system. Each user has an ID and an organization ID.

## Functions

### new_clusters_table()
```gleam
pub fn new_clusters_table() -> database.Table(Cluster) {
  atom.create("clusters_table")
  |> database.create_ets_table
}
```
Creates a table to store clusters using ETS (Erlang Term Storage). The table is created with the name "clusters_table".

### join_cluster(table: database.Table(Cluster), user: auth.User, ip_address: String, outbound: Subject(ws.WsCommand))
```gleam
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
```
Joins a new cluster. It takes the table, user details (ID and organization ID), IP address, and WebSocket command. It calculates a unique cluster ID using SHA-512 hashing and inserts the member into the cluster's dictionary. The function returns the generated cluster ID.

### leave_cluster(table: database.Table(Cluster), cluster_id: String, user_id: String)
```gleam
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
}
```
Leaves an existing cluster. It takes the table, cluster ID, and user ID. It deletes the user from the cluster's dictionary and checks if all members are removed. If so, it deletes the entire cluster entry.

### get_connected_peers(table: database.Table(Cluster), id: String, user_id: String)
```gleam
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
```
Retrieves connected peers for a given cluster ID and user ID. It queries the table for the cluster entry, filters out the current user's peer, and returns the remaining connected peers.

This file provides essential functionalities for managing clusters in the web proxy server system, ensuring seamless communication and connection tracking among clients.
