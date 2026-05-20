import envoy
import gleam/dynamic/decode
import gleam/http/request.{type Request}
import gleam/http/response.{type Response}
import gleam/httpc
import gleam/int
import gleam/json
import mist.{type ResponseData}
import webproxy_server/web

fn user_parser() {
  use num_id <- decode.field("id", decode.int)
  use display_name <- decode.field("username", decode.string)
  use num_org_id <- decode.subfield(["organization", "id"], decode.int)
  decode.success(
    json.object([
      #("id", json.string(int.to_string(num_id))),
      #("displayName", json.string(display_name)),
      #("organization_id", json.string(int.to_string(num_org_id))),
    ]),
  )
}

pub fn authenticate(req: Request(body)) -> Response(ResponseData) {
  case request.get_header(req, "authorization") {
    Error(Nil) -> web.unauthorized()
    Ok(auth_token) -> {
      echo "ENTREI"
      let assert Ok(url) = envoy.get("OAUTH_BASE_URL")
      let url = url <> "/oauth/userinfo"
      echo url
      let assert Ok(req) = request.to(url)
      let req =
        request.prepend_header(req, "Accept", "application/json")
        |> request.prepend_header("Authorizatin", auth_token)

      case httpc.send(req) {
        Ok(resp) if resp.status == 200 -> {
          echo resp.body
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
