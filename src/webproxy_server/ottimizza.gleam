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
      #("organization_id", json.string(int.to_string(num_org_id))),
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
