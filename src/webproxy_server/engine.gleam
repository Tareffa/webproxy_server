import database
import gleam/dict
import gleam/erlang/atom
import gleam/erlang/process.{type Subject}
import gleam/io
import gleam/json
import gleam/list
import gleam/result
import gleam/string
import mist
import webproxy_server/auth
import webproxy_server/cluster
import webproxy_server/ws_command

pub opaque type PendingResource {
  PendingResource(user_id: String, resource_name: String)
}

pub fn new_pending_resources_queue() -> database.Table(PendingResource) {
  atom.create("pending_resources_table")
  |> database.create_ets_table()
}

fn add_pending_resource_to_queue(
  queue: database.Table(PendingResource),
  user_id: String,
  resource_name: String,
) -> Result(String, database.TransactionError(Nil)) {
  use ref <- database.transaction(queue)
  database.insert(ref, PendingResource(user_id:, resource_name:))
}

pub type WsState {
  Unreacheable
  Unauthorized(ip_address: String, outbound: Subject(ws_command.WsCommand))
  Authorized(
    user_id: String,
    cluster_id: String,
    scopes: List(String),
    outbound: Subject(ws_command.WsCommand),
  )
}

pub fn ping(conn: mist.WebsocketConnection, state: WsState) {
  let _ = mist.send_text_frame(conn, "pong")
  mist.continue(state)
}

pub fn subscribe(
  users: database.Table(auth.User),
  clusters: database.Table(cluster.Cluster),
  ip_address: String,
  outbound: Subject(ws_command.WsCommand),
  auth_token: String,
  connection: mist.WebsocketConnection,
) -> mist.Next(WsState, a) {
  let check = {
    use user <- result.try(auth.get_user_by_auth_token(users, auth_token))

    use cluster_id <- result.try(cluster.join_cluster(
      clusters,
      user,
      ip_address,
      outbound,
    ))

    io.println(
      "User '"
      <> user.display_name
      <> "' successfully subscribed. With IP address "
      <> ip_address
      <> ". ClusterID: "
      <> cluster_id,
    )
    let _ = mist.send_text_frame(connection, "subscribed")
    Ok(Authorized(user.id, cluster_id, user.scopes, outbound))
  }
  result.unwrap(check, Unauthorized(ip_address, outbound))
  |> mist.continue
}

pub fn require(
  clusters: database.Table(cluster.Cluster),
  pending_resources: database.Table(PendingResource),
  cluster_id: String,
  user_id: String,
  scopes: List(String),
  outbound: Subject(ws_command.WsCommand),
  resource_name: String,
) {
  let peers =
    cluster.get_connected_peers(clusters, cluster_id, user_id)
    |> dict.values()

  case
    add_pending_resource_to_queue(pending_resources, user_id, resource_name)
  {
    Ok(resource_id) -> {
      let petition =
        json.object([
          #("resourceId", json.string(resource_id)),
          #("scopes", json.array(scopes, of: json.string)),
          #("resourceName", json.string(resource_name)),
        ])
        |> json.to_string()
      let petition = "/r " <> petition
      list.each(peers, fn(peer) {
        process.send(peer, ws_command.SendText(petition))
      })
      process.spawn(fn() {
        process.sleep(400)
        remove_pending_resource_from_queue(pending_resources, resource_id)
      })
      Nil
    }
    Error(_) -> {
      io.println_error("Unable to add resource to queue")
    }
  }

  mist.continue(Authorized(user_id:, scopes:, cluster_id:, outbound:))
}

fn remove_pending_resource_from_queue(
  queue: database.Table(PendingResource),
  resource_id: String,
) {
  use ref <- database.transaction(queue)
  database.delete(ref, resource_id)
}

pub fn provide(
  clusters: database.Table(cluster.Cluster),
  pending_resources: database.Table(PendingResource),
  cluster_id: String,
  user_id: String,
  scopes: List(String),
  outbound: Subject(ws_command.WsCommand),
  data: String,
) -> mist.Next(WsState, a) {
  case string.split_once(data, " ") {
    Ok(#(resource_id, response_json)) -> {
      let _ = {
        use ref <- database.transaction(pending_resources)
        case database.find(ref, resource_id) {
          Ok(pending_resource) -> {
            let _ = database.delete(ref, resource_id)
            let peers =
              cluster.get_connected_peers(clusters, cluster_id, user_id)
            case dict.get(peers, pending_resource.user_id) {
              Ok(peer) -> {
                process.send(
                  peer,
                  ws_command.SendText(
                    "/p "
                    <> pending_resource.resource_name
                    <> " "
                    <> response_json,
                  ),
                )
                Ok(Nil)
              }
              Error(_) -> Ok(Nil)
            }
          }
          Error(_) -> Ok(Nil)
        }
      }
      mist.continue(Authorized(user_id:, scopes:, cluster_id:, outbound:))
    }
    _ -> mist.stop()
  }
}

pub fn on_close(
  clusters: database.Table(cluster.Cluster),
  state: WsState,
) -> Nil {
  case state {
    Authorized(user_id:, cluster_id:, ..) ->
      cluster.leave_cluster(clusters, cluster_id, user_id)
    _ -> Nil
  }
}
