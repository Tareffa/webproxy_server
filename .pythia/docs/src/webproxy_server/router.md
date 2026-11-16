# WebProxy Server Router Module

The `router.gleam` module in the web proxy server project is responsible for handling HTTP and WebSocket requests. It provides functions to manage the state of WebSocket connections and handle various WebSocket commands. The router interacts with the database and other components to provide a secure and efficient data streaming service.

### Public Types

- `Database`: A struct containing three tables: `users`, `clusters`, and `pending_resources`.
  - `users`: Represents user information.
  - `clusters`: Represents cluster metadata.
  - `pending_resources`: Represents resources awaiting processing.

### Public Functions

#### `handle_request`
This function processes incoming HTTP requests. It checks the request path segments to determine the action to be taken:
- For the `/health` endpoint, it returns a simple health check response.
- For the `/ws` endpoint, it sets up a WebSocket connection with the client and handles messages accordingly.

#### `handle_ws_message`
This function processes WebSocket messages from connected clients. It handles different commands such as `ping`, subscription, resource provision, upgrade, and value drop. The message handling logic includes validating user permissions and interacting with the database to manage resources.

### Internal Logic

- **Database Interaction**: The router uses the `database` module to interact with the database tables: `users`, `clusters`, and `pending_resources`. It retrieves necessary data for resource management.
- **WebSocket Connection Handling**: The router sets up WebSocket connections using `mist.websocket`. It handles initialization, closure, and message handling to maintain a long-running connection.
- **Error Handling**: The router includes error handling mechanisms for invalid requests and WebSocket disconnections. It uses `mist.stop()` to terminate the WebSocket connection when necessary.

### Notable Internal Logic

- **WebSocket Commands**: The router supports several WebSocket commands like `/s` for subscription, `/r` for resource provision, `/p` for data provision, `/upgrade`, and `/su-drop`. Each command is handled by a specific function in `handle_ws_message`.
- **Resource Management**: The router manages resources using the `engine` module. It interacts with other components to ensure that resources are processed correctly and efficiently.
- **Permission Checks**: The router includes permission checks to ensure that only authorized users can access sensitive commands like `/s`, `/r`, and `/p`. Unauthorized access is denied, and appropriate error messages are returned.

This module forms a critical part of the web proxy server's functionality, providing secure and efficient data streaming to clients.
