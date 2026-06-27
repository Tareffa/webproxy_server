//// Centralizes access to every environment variable the server reads. No other
//// module should call `envoy` directly.

import envoy
import gleam/dynamic/decode
import gleam/int
import gleam/json
import gleam/result
import gleam/string

/// The TCP port the server binds to. Defaults to `8080` when unset or invalid.
pub fn port() -> Int {
  envoy.get("PORT")
  |> result.try(int.parse)
  |> result.unwrap(8080)
}

/// The URL used to authenticate users. Required: the server cannot start
/// without a valid `https://` value.
pub fn authentication_url() -> String {
  "http://localhost:8080/auth_relay"
}

/// Whether to trust the transport-level connection IP instead of the
/// `X-Forwarded-For` / `X-Real-IP` headers. Defaults to `False`, which suits a
/// deployment behind a reverse proxy. Set to `True` when the server faces
/// clients directly.
pub fn use_native_connection_ip() -> Bool {
  case envoy.get("USE_NATIVE_CONNECTION_IP") {
    Ok(raw) ->
      case string.lowercase(string.trim(raw)) {
        "true" | "1" -> True
        _ -> False
      }
    Error(_) -> False
  }
}

/// The IP addresses allowed to upgrade to intervention mode, parsed from the
/// `AUTHORIZED_ADMINISTRATOR_IPS` JSON array. A missing, malformed, or empty
/// value yields an empty list, meaning no one is allowed to upgrade.
pub fn authorized_administrator_ips() -> List(String) {
  case envoy.get("AUTHORIZED_ADMINISTRATOR_IPS") {
    Ok(raw) ->
      json.parse(raw, decode.list(decode.string))
      |> result.unwrap([])
    Error(_) -> []
  }
}
