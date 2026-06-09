import gleam/erlang/process.{type Subject}

pub type WsCommand {
  SendText(String)
}

pub type WsState {
  Unreacheable
  Unauthorized(ip_address: String, outbound: Subject(WsCommand))
  Authorized(
    user_id: String,
    cluster_id: String,
    scopes: List(String),
    outbound: Subject(WsCommand),
  )
}
