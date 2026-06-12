import webproxy_server/ottimizza
import database
import envoy
import gleam/erlang/process
import gleam/int
import gleam/io
import gleam/result
import mist
import webproxy_server/auth
import webproxy_server/cluster
import webproxy_server/engine
import webproxy_server/router

@external(erlang, "webproxy_server_ffi", "delete_old_users_from_table")
fn delete_old_users_from_table(table: database.Table(auth.User)) -> Int

pub fn main() -> Nil {
  io.println("Starting server...")

  let users = auth.new_user_table()
  let clusters = cluster.new_clusters_table()
  let pending_resources = engine.new_pending_resources_queue()
  let assert Ok(bandwidth_counter) = ottimizza.start_counter()
  let db = router.Database(users:, clusters:, pending_resources:, bandwidth_counter:)

  let port = get_port()

  let assert Ok(_) =
    router.handle_request(_, db)
    |> mist.new
    |> mist.with_ipv6
    |> mist.bind("0.0.0.0")
    |> mist.port(port)
    |> mist.start

  io.println("Server started at port " <> int.to_string(port))
  start_garbage_collector(db)
}

fn start_garbage_collector(db: router.Database) {
  process.sleep(3_600_000)
  delete_old_users_from_table(db.users)
  start_garbage_collector(db)
}

fn get_port() -> Int {
  envoy.get("PORT")
  |> result.try(int.parse)
  |> result.unwrap(8080)
}
