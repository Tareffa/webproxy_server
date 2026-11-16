# File: src/webproxy_server/engine.gleam

## Purpose and Role in the Project

The `engine.gleam` file contains the implementation of the main engine for the web proxy server. It manages user authentication, resource management, and WebSocket communication with clients.

### Functions and Classes

1. **new_pending_resources_queue**
   - Description: Initializes a database table to store pending resources.
   - Parameters: None
   - Returns: A reference to the created ETS table.

2. **add_pending_resource_to_queue**
   - Description: Adds a new resource to the pending queue.
   - Parameters:
     - `queue`: The database table for pending resources.
     - `user_id`: The ID of the user who owns the resource.
     - `resource_name`: The name of the resource.
   - Returns:
     - A result indicating success or failure. If successful, returns the resource ID; otherwise, returns a transaction error.

3. **ping**
   - Description: Sends a "pong" message to the WebSocket client.
   - Parameters:
     - `conn`: The WebSocket connection object.
     - `state`: The current state of the WebSocket.
   - Returns: None

4. **subscribe**
   - Description: Subscribes a user to a cluster by sending a "subscribed" message and initiating resource fetching.
   - Parameters:
     - `users`: Database table for authenticated users.
     - `clusters`: Database table for clusters.
     - `ip_address`: The IP address of the client.
     - `outbound`: A subject to send WebSocket commands.
     - `auth_token`: The authentication token for the user.
     - `connection`: The WebSocket connection object.
   - Returns: A result indicating success or failure. On success, returns an authorized state; otherwise, returns an unauthorized state.

5. **require**
   - Description: Fetches a resource from the pending queue and sends it to the connected peer(s).
   - Parameters:
     - `clusters`: Database table for clusters.
     - `pending_resources`: Database table for pending resources.
     - `cluster_id`: The ID of the cluster.
     - `user`: The authenticated user.
     - `ip_address`: The IP address of the client.
     - `outbound`: A subject to send WebSocket commands.
     - `resource_name`: The name of the resource.
   - Returns: A result indicating success or failure. On success, returns an authorized state; otherwise, logs an error and stops.

6. **remove_pending_resource_from_queue**
   - Description: Removes a pending resource from the database table.
   - Parameters:
     - `queue`: The database table for pending resources.
     - `resource_id`: The ID of the resource to be removed.
   - Returns: None

7. **provide**
   - Description: Processes incoming data and sends it to all connected peers that have the necessary resources.
   - Parameters:
     - `clusters`: Database table for clusters.
     - `pending_resources`: Database table for pending resources.
     - `cluster_id`: The ID of the cluster.
     - `user`: The authenticated user.
     - `ip_address`: The IP address of the client.
     - `outbound`: A subject to send WebSocket commands.
     - `data`: The incoming data packet.
   - Returns: A result indicating success or failure. On success, returns an authorized state; otherwise, logs an error and stops.

8. **upgrade**
   - Description: Handles user upgrades by sending a success message to the client.
   - Parameters:
     - `user`: The authenticated user.
     - `ip_address`: The IP address of the client.
     - `conn`: The WebSocket connection object.
   - Returns: None

9. **ip_is_authorized_administrator**
   - Description: Checks if the given IP address is authorized to upgrade a connection without an administrator account.
   - Parameters:
     - `ip_address`: The IP address of the client.
   - Returns: A boolean indicating whether the IP address is authorized.

10. **on_close**
    - Description: Handles WebSocket closure by leaving the cluster for authenticated users.
    - Parameters:
      - `clusters`: Database table for clusters.
      - `state`: The current state of the WebSocket connection.
    - Returns: None

### Internal Logic and Algorithms

- **Pending Resource Queue**: Manages resources that are waiting to be processed by clients. It stores user IDs, resource names, and pending states in an ETS table.
- **Resource Fetching**: When a user subscribes, it adds the requested resource to the pending queue and sends it to all connected peers who have the necessary resources. The fetching process is scheduled for 60 seconds after the request.

### Side Effects

- **Database Operations**: Modifies database tables such as `pending_resources` and `users`.
- **WebSocket Communication**: Sends messages to clients over WebSocket connections.
- **Error Handling**: Logs errors when resources cannot be added or removed from the pending queue.
