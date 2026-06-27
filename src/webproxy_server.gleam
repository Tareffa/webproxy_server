import database
import gleam/erlang/process
import gleam/int
import gleam/io
import gleam/list
import mist
import webproxy_server/auth
import webproxy_server/cluster
import webproxy_server/engine
import webproxy_server/environment
import webproxy_server/ottimizza
import webproxy_server/router

@external(erlang, "webproxy_server_ffi", "delete_old_users_from_table")
fn delete_old_users_from_table(table: database.Table(auth.User)) -> Int

pub fn main() -> Nil {
  io.println("Starting server...")

  warn_about_authorized_administrator_ips()

  let users = auth.new_user_table()
  let clusters = cluster.new_clusters_table()
  let pending_resources = engine.new_pending_resources_queue()
  let assert Ok(bandwidth_counter) = ottimizza.start_counter()
  let assert Ok(hit_counter) = ottimizza.start_cache_hit_counter()
  let db =
    router.Database(
      users:,
      clusters:,
      pending_resources:,
      bandwidth_counter:,
      hit_counter:,
    )

  let port = environment.port()

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

/// Emits a warning at boot when `AUTHORIZED_ADMINISTRATOR_IPS` contains the
/// wildcard `"*"`, which allows any IP address to upgrade to intervention mode.
fn warn_about_authorized_administrator_ips() -> Nil {
  case list.contains(environment.authorized_administrator_ips(), "*") {
    True ->
      io.println_error(
        "WARNING: AUTHORIZED_ADMINISTRATOR_IPS contains \"*\", so connections "
        <> "from any IP address are allowed to upgrade to intervention mode. "
        <> "This may be dangerous.",
      )
    False -> Nil
  }
}
