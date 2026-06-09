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

pub fn main() -> Nil {
  io.println("Starting server...")

  let users = auth.new_user_table()
  let clusters = cluster.new_clusters_table()
  let pending_resources = engine.new_pending_resources_queue()
  let db = router.Database(users:, clusters:, pending_resources:)

  let port = get_port()

  let assert Ok(_) =
    router.handle_request(_, db)
    |> mist.new
    |> mist.with_ipv6
    |> mist.bind("0.0.0.0")
    |> mist.port(port)
    |> mist.start

  io.println("Server started at port " <> int.to_string(port))
  process.sleep_forever()
}

fn get_port() -> Int {
  envoy.get("PORT")
  |> result.try(int.parse)
  |> result.unwrap(8080)
}
