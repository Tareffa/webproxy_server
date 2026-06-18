import gleam/otp/actor
import gleam/erlang/process
import webproxy_server/cluster
import webproxy_server/auth
import database
import envoy
import gleam/dynamic/decode
import gleam/http
import gleam/http/request.{type Request}
import gleam/http/response.{type Response}
import gleam/httpc
import gleam/int
import gleam/json
import mist.{type ResponseData}
import webproxy_server/web

fn user_parser() {
  use num_id <- decode.subfield(["record", "id"], decode.int)
  use display_name <- decode.subfield(["record", "username"], decode.string)
  use user_type <- decode.subfield(["record", "type"], decode.int)
  let scopes = case user_type {
    0 -> ["*", "admin"]
    1 -> ["*"]
    2 -> ["*"]
    7 -> ["*", "admin", "analyst"]
    8 -> ["*", "admin", "analyst", "leader"]
    9 -> ["*", "admin", "analyst", "leader", "techleader"]
    _ -> []
  }
  use num_org_id <- decode.subfield(
    ["record", "organization", "id"],
    decode.int,
  )
  decode.success(
    json.object([
      #("id", json.string(int.to_string(num_id))),
      #("displayName", json.string(display_name)),
      #("scopes", json.array(scopes, of: json.string)),
      #("organizationId", json.string(int.to_string(num_org_id))),
      #("isAdmin", json.bool(user_type == 9))
    ]),
  )
}

pub fn authenticate(req: Request(body)) -> Response(ResponseData) {
  case request.get_header(req, "authorization") {
    Error(Nil) -> web.unauthorized()
    Ok(auth_token) -> {
      let assert Ok(url) = envoy.get("OAUTH_BASE_URL")
      let url = url <> "/oauth/userinfo"
      let assert Ok(req) = request.to(url)
      let req =
        request.prepend_header(req, "accept", "application/json")
        |> request.prepend_header("authorization", auth_token)
        |> request.set_method(http.Get)

      case httpc.send(req) {
        Ok(resp) if resp.status == 200 -> {
          case json.parse(from: resp.body, using: user_parser()) {
            Ok(user) -> {
              response.new(200)
              |> web.set_body(json.to_string(user))
            }
            Error(_) -> web.unauthorized()
          }
        }
        _ -> web.unauthorized()
      }
    }
  }
}

pub type CacheHitMessage {
  Hit 
  Miss
  GetData(reply_with: process.Subject(CacheHit))
}

pub type CacheHit {
  CacheHit(hits: Int, misses: Int)
}

fn handle_cache_hit_message(state: CacheHit, message: CacheHitMessage) -> actor.Next(CacheHit, CacheHitMessage) {
  case message {
    Hit -> actor.continue(CacheHit(state.hits + 1, state.misses))
    Miss -> actor.continue(CacheHit(state.hits, state.misses + 1))
    GetData(client) -> {
      process.send(client, state)
      actor.continue(state)
    }
  }
}

pub type HitCounter = actor.Started(process.Subject(CacheHitMessage))
pub fn start_cache_hit_counter() {
  actor.new(CacheHit(0, 0))
  |> actor.on_message(handle_cache_hit_message)
  |> actor.start
}

pub fn hit(counter: HitCounter) {
  process.send(counter.data, Hit)
}

pub fn miss(counter: HitCounter) {
  process.send(counter.data, Miss)
}

pub type Message {
  Add(value: Int)
  Get(reply_with: process.Subject(Int))
}


fn handle_message(state: Int, message: Message) -> actor.Next(Int, Message) {
  case message {
    Add(value) -> actor.continue(value + state)
    Get(client) -> {
      process.send(client, state)
      actor.continue(state)
    }
  }
}

pub type BandCounter = actor.Started(process.Subject(Message))
pub fn start_counter() {
  actor.new(0)
  |> actor.on_message(handle_message)
  |> actor.start
}

@external(erlang, "webproxy_server_ffi", "table_size")
fn table_size(table: database.Table(a)) -> Int

pub fn info(
  users: database.Table(auth.User),
  clusters: database.Table(cluster.Cluster),
  memory_counter: BandCounter,
  hit_counter: HitCounter
) {
  let user_count = table_size(users)
  let cluster_count = table_size(clusters)
  let bandwidth_saved = process.call(memory_counter.data, waiting: 10, sending: Get)
  let hit_ratio = process.call(hit_counter.data, waiting: 10, sending: GetData)

  let resp = response.new(200)
  |> web.set_default_headers
  json.object([
    #("userCount", json.int(user_count)),
    #("clusterCount", json.int(cluster_count)),
    #("bandwidthSaved", json.int(bandwidth_saved)),
    #("cacheMissCount", json.int(hit_ratio.misses)),
    #("cacheHitCount", json.int(hit_ratio.hits))
  ])
  |> json.to_string()
  |> web.set_body(resp, _)
}
