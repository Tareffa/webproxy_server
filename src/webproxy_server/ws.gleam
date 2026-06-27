import gleam/erlang/process.{type Subject}
import webproxy_server/auth

pub type WsCommand {
  SendText(String)
}

pub type WsState {
  Unreacheable
  Unauthorized(ip_address: String, outbound: Subject(WsCommand))
  Authorized(
    user: auth.User,
    cluster_id: String,
    ip_address: String,
    outbound: Subject(WsCommand),
  )
  Intervention(user: auth.User)
}
