import gleam/bytes_tree
import gleam/http/request
import gleam/http/response
import gleam/json
import gleam/result
import mist
import webproxy_server/environment

const not_found_status_code = 404

/// Resolves the originating client IP for an incoming request.
///
/// Behind a reverse proxy (the default, `USE_NATIVE_CONNECTION_IP` unset or
/// `False`) the IP is taken from the `X-Forwarded-For` header, falling back to
/// `X-Real-IP`. When `USE_NATIVE_CONNECTION_IP` is `True`, or when neither
/// header is present, the transport-level connection IP is used instead.
pub fn resolve_ip_address(
  request: request.Request(mist.Connection),
) -> Result(String, Nil) {
  let from_headers = case environment.use_native_connection_ip() {
    True -> Error(Nil)
    False ->
      request.get_header(request, "x-forwarded-for")
      |> result.or(request.get_header(request, "x-real-ip"))
  }

  from_headers
  |> result.lazy_or(fn() {
    mist.get_connection_info(request.body)
    |> result.map(fn(info) { mist.ip_address_to_string(info.ip_address) })
    |> result.replace_error(Nil)
  })
}

pub fn not_found() -> response.Response(mist.ResponseData) {
  response.new(not_found_status_code)
  |> set_body("Not Found")
}

pub fn set_body(
  resp: response.Response(a),
  body: String,
) -> response.Response(mist.ResponseData) {
  response.set_body(resp, mist.Bytes(bytes_tree.from_string(body)))
}

pub fn health() -> response.Response(mist.ResponseData) {
  response.new(200)
  |> set_body(json.to_string(json.object([#("status", json.string("UP"))])))
}
