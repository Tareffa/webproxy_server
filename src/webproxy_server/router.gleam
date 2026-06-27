import database
import gleam/erlang/process
import gleam/http/request
import gleam/http/response
import gleam/option.{Some}
import mist
import webproxy_server/auth
import webproxy_server/cluster
import webproxy_server/engine
import webproxy_server/intervention
import webproxy_server/web
import webproxy_server/ws.{Authorized, Intervention, Unauthorized, Unreacheable}

pub type Database {
  Database(
    users: database.Table(auth.User),
    clusters: database.Table(cluster.Cluster),
    pending_resources: database.Table(engine.PendingResource),
  )
}

pub fn handle_request(
  request: request.Request(mist.Connection),
  db: Database,
) -> response.Response(mist.ResponseData) {
  case request.path_segments(request) {
    ["health"] -> web.health()
    ["ws"] ->
      mist.websocket(
        request:,
        on_init: fn(_conn) {
          let outbound = process.new_subject()
          let selector =
            process.new_selector()
            |> process.select(for: outbound)

          let state = case mist.get_connection_info(request.body) {
            Ok(info) -> {
              Unauthorized(mist.ip_address_to_string(info.ip_address), outbound)
            }
            Error(_) -> Unreacheable
          }
          #(state, Some(selector))
        },
        on_close: fn(state) { engine.on_close(db.clusters, state) },
        handler: fn(state, message, conn) {
          handle_ws_message(state, message, conn, db)
        },
      )
    _ -> web.not_found()
  }
}

fn handle_ws_message(
  state: ws.WsState,
  message: mist.WebsocketMessage(ws.WsCommand),
  conn: mist.WebsocketConnection,
  db: Database,
) {
  case message, state {
    _, Unreacheable -> mist.stop()
    mist.Text("ping"), _ -> engine.ping(conn, state)

    mist.Text("/s " <> auth_token), Unauthorized(address, outbound) ->
      engine.subscribe(
        db.users,
        db.clusters,
        address,
        outbound,
        auth_token,
        conn,
      )

    _, Unauthorized(_, _) -> mist.continue(state)

    mist.Text("/r " <> resource_name),
      Authorized(user:, cluster_id:, ip_address:, outbound:)
    -> {
      engine.require(
        db.clusters,
        db.pending_resources,
        cluster_id,
        user,
        ip_address,
        outbound,
        resource_name,
      )
    }

    mist.Text("/p " <> data),
      Authorized(user:, cluster_id:, ip_address:, outbound:)
    -> {
      engine.provide(
        db.clusters,
        db.pending_resources,
        cluster_id,
        user,
        ip_address,
        outbound,
        data,
      )
    }

    mist.Text("/upgrade"), Authorized(user:, ip_address:, ..) ->
      engine.upgrade(user, ip_address, conn)

    mist.Text("/su-drop " <> data), Intervention(_) ->
      intervention.drop_value(
        db.users,
        db.clusters,
        db.pending_resources,
        conn,
        state,
        data,
      )

    mist.Text("/su-clinfo " <> data), Intervention(_) ->
      intervention.cluster_info(db.users, db.clusters, conn, state, data)

    mist.Text("/su-invalidate " <> data), Intervention(_) ->
      intervention.force_cache_invalidation(
        db.users,
        db.clusters,
        conn,
        state,
        data,
      )

    mist.Custom(ws.SendText(text)), _ -> {
      let _ = mist.send_text_frame(conn, text)
      mist.continue(state)
    }

    mist.Closed, _ | mist.Shutdown, _ -> mist.stop()

    _, _ -> mist.continue(state)
  }
}
