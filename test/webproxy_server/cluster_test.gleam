import database
import gleam/dict
import gleam/erlang/process
import webproxy_server/auth
import webproxy_server/cluster

const user = auth.User(
  id: "123",
  display_name: "John Doe",
  scopes: ["read", "write"],
  organization_id: "org1",
)

const ip_address = "192.168.1.1"

pub fn join_cluster_test() {
  let table = cluster.new_clusters_table()
  let outbound = process.new_subject()

  let assert Ok(cluster_id) =
    cluster.join_cluster(table, user, ip_address, outbound)
  let assert Ok(cluster) = {
    use ref <- database.transaction(table)
    database.find(ref, cluster_id)
  }
  assert dict.size(cluster) == 1
}

pub fn leave_cluster_test() {
  let table = cluster.new_clusters_table()
  let outbound = process.new_subject()

  let assert Ok(cluster_id) =
    cluster.join_cluster(table, user, ip_address, outbound)
  assert Nil == cluster.leave_cluster(table, cluster_id, user.id)
  let assert Error(database.Operation(database.NotFound)) = {
    use ref <- database.transaction(table)
    database.find(ref, cluster_id)
  }
}

pub fn get_connected_peers_test() {
  let table = cluster.new_clusters_table()
  let outbound = process.new_subject()

  let assert Ok(cluster_id) =
    cluster.join_cluster(table, user, ip_address, outbound)

  let other_user = auth.User(..user, display_name: "Penelope", id: "aabbcc")
  let assert Ok(second_cluster_id) =
    cluster.join_cluster(table, other_user, ip_address, outbound)

  assert cluster_id == second_cluster_id

  let other_ip = "192.168.1.2"
  let other_network_user =
    auth.User(..user, display_name: "Someone", id: "1010101")
  let assert Ok(third_cluster_id) =
    cluster.join_cluster(table, other_network_user, other_ip, outbound)

  assert cluster_id != third_cluster_id

  let other_org_same_network_user =
    auth.User(..user, display_name: "Else", id: "fdsadas", organization_id: "2")
  let assert Ok(fourth_cluster_id) =
    cluster.join_cluster(table, other_org_same_network_user, other_ip, outbound)

  assert cluster_id != fourth_cluster_id
  assert third_cluster_id != fourth_cluster_id

  let peers = cluster.get_connected_peers(table, cluster_id, user.id)
  assert dict.size(peers) == 1
}
