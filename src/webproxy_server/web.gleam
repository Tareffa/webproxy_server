import gleam/bytes_tree
import gleam/http/response
import gleam/json
import mist

const not_found_status_code = 404

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
