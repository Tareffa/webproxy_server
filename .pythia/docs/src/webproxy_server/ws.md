# Web Proxy Server WebSocket Command Processor

The `ws.gleam` file is responsible for processing WebSocket commands in the web proxy server. This file contains various classes and functions that handle incoming messages from clients and manage the state of the proxy, including authentication and authorization checks.

## Public Types

### WsCommand

#### Parameters
- `SendText(String)`: Sends a text message to the client.

#### Return Value
None

#### Behavior
This type encapsulates the possible commands sent by clients through WebSocket. The `SendText` command is used to transmit textual data to the client.

### WsState

#### Parameters
- `Unreacheable`: Represents a state where the proxy cannot reach its target.
- `Unauthorized(ip_address: String, outbound: Subject(WsCommand))`: Indicates that the client lacks proper authentication or authorization.
  - `ip_address`: The IP address of the client.
  - `outbound`: A subject that will receive WsCommand messages from the proxy.
- `Authorized(user: auth.User, cluster_id: String, ip_address: String, outbound: Subject(WsCommand))`: Indicates that the client is authenticated and authorized.
  - `user`: The user details authenticated by the proxy.
  - `cluster_id`: The ID of the cluster to which the client belongs.
  - `ip_address`: The IP address of the client.
  - `outbound`: A subject that will receive WsCommand messages from the proxy.
- `Intervention(user: auth.User)`: Represents an intervention request made by a user.

#### Return Value
None

#### Behavior
This type represents the state of the proxy server at any given time. It includes the current state (e.g., unauthenticated, authorized, etc.) and provides mechanisms to transition between these states based on received commands or events.

## Internal Logic

### WsCommand Processing

The `ws.gleam` file processes incoming WebSocket messages according to the defined `WsCommand`. It checks if the message is a valid command and then dispatches it to the appropriate handler. The handlers are responsible for handling different types of commands, such as sending text messages or managing authentication.

### Authentication and Authorization

Authentication and authorization checks are performed in the `ws.gleam` file. The `auth` module provides functions to handle user authentication and authorization. The `authorize_user/2` function takes a user's credentials and cluster ID, and returns an authorized state if the credentials are valid for the given cluster.

### Error Handling

Error handling is implemented in the `ws.gleam` file to manage exceptions that may occur during message processing or authentication. The `handle_error/1` function logs any errors that occur and then sends an error response back to the client.

## Side Effects

The `ws.gleam` file has side effects, such as sending text messages to clients through the WebSocket API. These side effects are managed by the `send_text_to_client/2` function, which takes a user's credentials and the message to be sent.

### Example Usage

Here is an example of how the `ws.gleam` file might be used in a web proxy server application:

```gleam
import gleam/http.server
import webproxy_server/ws

let server = http.server.start()
server.listen(8080)
```

In this example, the `http.server.start/0` function starts the HTTP server on port 8080. The `ws.gleam` file is then used to handle WebSocket connections and process incoming messages according to the defined `WsCommand`.
