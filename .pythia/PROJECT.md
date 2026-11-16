# Comprehensive Documentation

## Overview

The `webproxy_server` project is designed to serve as a secure and efficient data streaming service for clients. It comprises several interconnected modules and utilities, including authentication, resource management, WebSocket communication, and logging. This documentation outlines the architecture of the project, key concepts, entry points, and setup instructions.

### Architecture Overview

The `webproxy_server` project is composed of various major areas, each responsible for specific functionalities:

1. **HTTP Server (`src/web.gleam`)**
   - Handles incoming HTTP requests and returns appropriate responses.
   
2. **WebSocket (`src/ws.gleam`)**
   - Manages WebSocket connections, handles WebSocket commands like subscription, resource provision, and upgrade.
   
3. **Authentication (`src/auth.gleam`)**
   - Manages user authentication and authorization for the web proxy server.
   
4. **Resource Management (`src/engine.gleam`, `src/cluster.gleam`, etc.)**
   - Handles resource creation, fetching, invalidation, and management within clusters.
   
5. **Logging (`src/log.gleam`)**
   - Provides a logging mechanism for recording events and debugging issues.

### Key Concepts

- **HTTP Server**: This module manages incoming HTTP requests by parsing them and dispatching to the appropriate route handlers defined in `response_handler/1`.

- **WebSocket**: The WebSocket module processes messages from clients, managing connections through the lifecycle of a session. It also handles resource management tasks like subscription, provision, and upgrade.

- **Authentication**: The authentication module manages user credentials, ensuring only authenticated users can access certain commands or resources.

- **Resource Management**: This area is crucial for handling and processing various resources within clusters. Resources include pending requests that need to be processed by clients.

- **Logging**: Logs are essential for debugging and tracking the state of the web proxy server over time.

### Entry Points

The following entry points must be known for a new developer to understand how to interact with the `webproxy_server` project:

1. **HTTP Server (`main/1`)**:
   - Handles incoming HTTP requests using route handlers.
   
2. **WebSocket Connection**:
   - Establishes a WebSocket connection with clients and processes messages accordingly.
   
3. **Authentication Token Management**:
   - Uses user authentication to manage permissions and access control for various commands.

4. **Resource Handling Functions** (`handle_request/2`, `get_user_by_auth_token`):
   - Handles resource creation, fetching, invalidation, and management within the database tables.
   
5. **Logging Mechanism**:
   - Logs events and issues for debugging purposes using the `log.gleam` module.

### Setup Instructions

1. **Compiling the Project**:
   - Ensure you have Gleam installed on your system (`gleam --version`).
   - Navigate to the root directory of the project.
   - Compile the main modules by running: `gleam build src/webproxy_server.gleam src/auth.gleam src/cluster.gleam`.

2. **Running the HTTP Server**:
   - Execute the compiled binary using `./webproxy_server` in your terminal.

3. **Configuring Environment Variables**:
   - The project uses environment variables to configure various aspects, such as port numbers and authentication URLs.
   - Set environment variables like `PORT=8080`, `AUTHENTICATION_URL=https://example.com/authenticate`.

4. **Using WebSocket Clients**:
   - Clients can establish a WebSocket connection using the server's address (e.g., `ws://localhost:8080/ws`).
   - Connect clients to ensure they receive and respond to messages correctly.

5. **Testing the Authentication Module**:
   - Use test cases provided in `src/auth_test.gleam` to validate authentication functionalities.
   
6. **Logging Test Cases**:
   - Use the logging mechanism in `src/log_test.gleam` to check logs for expected events and issues during development.

By understanding these key areas, entry points, and setup instructions, new developers can effectively begin working with the `webproxy_server` project.
