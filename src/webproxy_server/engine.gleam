import webproxy_server/ottimizza
import database
import gleam/dict
import gleam/erlang/atom
import gleam/erlang/process.{type Subject}
import gleam/io
import gleam/json
import gleam/list
import gleam/result
import gleam/string
import gleam/string_tree
import mist
import webproxy_server/auth
import webproxy_server/cluster
import webproxy_server/ws.{Authorized, Unauthorized}

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

pub fn ping(conn: mist.WebsocketConnection, state: ws.WsState) {
  let _ = mist.send_text_frame(conn, "pong")
  mist.continue(state)
}

pub fn subscribe(
  users: database.Table(auth.User),
  clusters: database.Table(cluster.Cluster),
  ip_address: String,
  outbound: Subject(ws.WsCommand),
  auth_token: String,
  connection: mist.WebsocketConnection,
) -> mist.Next(ws.WsState, a) {
  let check = {
    use user <- result.try(auth.get_user_by_auth_token(users, auth_token))

    use cluster_id <- result.try(cluster.join_cluster(
      clusters,
      user,
      ip_address,
      outbound,
    ))

    let _ = mist.send_text_frame(connection, "subscribed")
    Ok(Authorized(user, cluster_id, outbound))
  }
  result.unwrap(check, Unauthorized(ip_address, outbound))
  |> mist.continue
}

pub fn require(
  clusters: database.Table(cluster.Cluster),
  pending_resources: database.Table(PendingResource),
  cluster_id: String,
  user: auth.User,
  outbound: Subject(ws.WsCommand),
  resource_name: String,
) {
  let peers =
    cluster.get_connected_peers(clusters, cluster_id, user.id)
    |> dict.values()

  case
    add_pending_resource_to_queue(pending_resources, user.id, resource_name)
  {
    Ok(resource_id) -> {
      let petition =
        json.object([
          #("resourceId", json.string(resource_id)),
          #("scopes", json.array(user.scopes, of: json.string)),
          #("resourceName", json.string(resource_name)),
        ])
        |> json.to_string()
      let petition = "/r " <> petition
      list.each(peers, fn(peer) { process.send(peer, ws.SendText(petition)) })
      process.spawn(fn() {
        process.sleep(60_000)
        remove_pending_resource_from_queue(pending_resources, resource_id)
      })
      Nil
    }
    Error(_) -> {
      io.println_error("Unable to add resource to queue")
    }
  }

  mist.continue(Authorized(user:, cluster_id:, outbound:))
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
  bandwidth_counter: ottimizza.BandCounter,
  cluster_id: String,
  user: auth.User,
  outbound: Subject(ws.WsCommand),
  data: String,
) -> mist.Next(ws.WsState, a) {
  case string.split_once(data, " ") {
    Ok(#(resource_id, response_json)) -> {
      let _ = {
        use ref <- database.transaction(pending_resources)
        case database.find(ref, resource_id) {
          Ok(pending_resource) -> {
            let _ = database.delete(ref, resource_id)
            let peers =
              cluster.get_connected_peers(clusters, cluster_id, user.id)
            case dict.get(peers, pending_resource.user_id) {
              Ok(peer) -> {
                string_tree.from_string("/p ")
                |> string_tree.append(pending_resource.resource_name)
                |> string_tree.append(" ")
                |> string_tree.append(response_json)
                |> string_tree.to_string()
                |> ws.SendText
                |> process.send(peer, _)
                process.send(bandwidth_counter.data, ottimizza.Add(string.byte_size(response_json)))
                Ok(Nil)
              }
              Error(_) -> Ok(Nil)
            }
          }
          Error(_) -> Ok(Nil)
        }
      }
      mist.continue(Authorized(user:, cluster_id:, outbound:))
    }
    _ -> mist.stop()
  }
}

pub fn upgrade(user: auth.User, conn: mist.WebsocketConnection) {
  case user {
    auth.User(..) -> {
      string_tree.from_string("User ")
      |> string_tree.append(user.display_name)
      |> string_tree.append(" from organization ")
      |> string_tree.append(user.organization_id)
      |> string_tree.append(
        " tried to upgrade their connection without an administrator account.",
      )
      |> string_tree.to_string()
      |> io.println_error()
      mist.stop()
    }
    auth.SysAdmin(..) -> {
      let _ =
        mist.send_text_frame(
          conn,
          "Successfully upgraded. You are now in intervention mode.",
        )
      mist.continue(ws.Intervention(user))
    }
  }
}

pub fn on_close(
  clusters: database.Table(cluster.Cluster),
  state: ws.WsState,
) -> Nil {
  case state {
    Authorized(user:, cluster_id:, ..) ->
      cluster.leave_cluster(clusters, cluster_id, user.id)
    _ -> Nil
  }
}
