# Auth Module

The `auth.gleam` file in the `src/webproxy_server/` directory is responsible for handling user authentication and management within a web proxy server. The module provides functions to create a new table for storing users, store a new user, and retrieve a user by their authentication token.

## Public Functions

1. **json_to_user_decoder()**: This function defines how JSON data should be decoded into the `User` type. It handles both `User` and `SysAdmin` types based on the presence of the `"isAdmin"` field in the JSON object.

2. **new_user_table()**: This function creates a new table named "users_table" using the `database.create_ets_table()` method. The table is used to store user data persistently across database restarts.

3. **store_user(cache: database.Table(User), token: String, user: User) -> Nil**: This function stores a new user in the database. If the user is of type `SysAdmin`, it does not store them; otherwise, it inserts the user into the table using the `database.upsert()` method.

4. **get_user_by_auth_token(cache: database.Table(User), token: String) -> Result(User, Nil)**: This function retrieves a user by their authentication token. It sends an HTTP request to the authentication URL and parses the JSON response to obtain the user data. The user data is then stored in the database using `store_user()`.

5. **prepare_auth_request(token: String) -> Result(Request, Nil)**: This function creates a new HTTP request with the necessary headers for the authentication token. It prepends the "accept" and "authorization" headers to the base request URL.

## Internal Logic

- **User and SysAdmin Types**: The module defines two types, `User` and `SysAdmin`, each containing various fields such as ID, display name, scopes, organization ID, and creation timestamp.
- **JSON Decoder**: The `json_to_user_decoder()` function handles the JSON decoding of user data. It uses the `decode.field()` method to extract specific values from the JSON object.
- **Database Operations**: The module interacts with a database using the `database` module. It creates a new table for storing users, inserts or updates user records, and retrieves user data based on authentication tokens.
- **HTTP Requests**: The module sends HTTP requests to an authentication URL and parses the JSON response using the `httpc` module.

## Note

The module assumes that the `environment.authentication_url()` function returns the correct authentication URL for the web proxy server.
