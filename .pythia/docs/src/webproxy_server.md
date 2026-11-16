# Web Proxy Server

The `src/webproxy_server.gleam` file is the entry point of a web proxy server implemented in Gleam. This server is responsible for handling incoming requests and routing them to the appropriate destination based on predefined rules.

### Structure and Functions

1. **Main Function**:
    - Initializes the database tables (`users`, `clusters`, `pending_resources`) using the `auth.new_user_table()`, `cluster.new_clusters_table()`, and `engine.new_pending_resources_queue()` functions respectively.
    - Configures the port number from the environment using `environment.port()`.
    - Starts a mist server to listen on the specified port, handling incoming requests using the `router.handle_request(_, db)` function.

2. **Garbage Collector**:
    - Sleeps for 1 hour before deleting all old users from the database table.
    - Calls itself recursively to continue this periodic task.

3. **Warning Function**:
    - Checks if the `AUTHORIZED_ADMINISTRATOR_IPS` environment variable contains the wildcard `"*"`.
    - If so, prints an error message warning about allowing any IP address to upgrade to intervention mode.

### Internal Logic and Algorithms

- **Database Tables**: The server maintains three main tables: `users`, `clusters`, and `pending_resources`. Each table is created using appropriate Gleam functions.
- **Mist Server**: The mist server is used to listen on the specified port. It processes incoming requests, routes them to the appropriate destination based on the `router.handle_request(_, db)` function, which calls various functions within the component's engine and environment.
- **Garbage Collection**: The periodic deletion of old users is handled by a recursive function that sleeps for 1 hour before deleting the users from the database table. This ensures that old users are removed automatically to maintain a clean database.

### Dependencies

The `src/webproxy_server.gleam` file depends on several Gleam libraries:
- `database`
- `gleam/erlang/process`
- `gleam/int`
- `gleam/io`
- `gleam/list`
- `mist`
- `webproxy_server/auth`
- `webproxy_server/cluster`
- `webproxy_server/engine`
- `webproxy_server/environment`

These dependencies are imported at the beginning of the file using the `import` statement.

### Example Usage

To use this server, you would typically compile and run it from a Gleam environment. Here is an example of how you might compile and run the server:

```sh
gleam build src/webproxy_server.gleam -o webproxy_server
./webproxy_server
```

This command compiles the `src/webproxy_server.gleam` file into an executable named `webproxy_server`, which you then run to start the server.

This comprehensive documentation should provide a clear understanding of how the `src/webproxy_server.gleam` file functions and how it interacts with other components within the web proxy project.
