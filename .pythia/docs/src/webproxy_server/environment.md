# Environment Variables for Web Proxy Server

The `environment.gleam` file is a critical component of the web proxy server project, responsible for managing various environmental variables that control its behavior. This file ensures that the server can start successfully and operate correctly with minimal human intervention.

## Purpose and Role

The `environment.gleam` file contains configuration settings that determine how the server interacts with the outside world. These settings include:

- **Port**: The TCP port on which the server listens for incoming requests.
  - Default: `8080`.
  - Behavior: If not set or invalid, defaults to `8080`.

- **Authentication URL**: The base URL for user authentication.
  - Required: The server cannot start without a valid value.
  - Behavior: If the environment variable is missing or malformed, returns a default value of `"https://"`.

- **Use Native Connection IP**: Determines whether to trust the transport-level connection IP address instead of relying on the `X-Forwarded-For` / `X-Real-IP` headers.
  - Default: `False`.
  - Behavior: Set to `True` when the server faces clients directly, allowing for more control over client authentication.

- **Authorized Administrator IPs**: Specifies a list of IP addresses that are allowed to upgrade to intervention mode.
  - Default: An empty list, meaning no one is allowed to upgrade.
  - Behavior: If the environment variable is missing or malformed, returns an empty list. If the JSON array is empty, returns an empty list.

## Public/Exported Classes, Functions, Constants

### Port

```gleam
/// The TCP port the server binds to. Defaults to `8080` when unset or invalid.
pub fn port() -> Int {
  envoy.get("PORT")
    |> result.try(int.parse)
    |> result.unwrap(8080)
}
```

- **Parameters**: None.
- **Return Value**: An integer representing the port number.
- **Behavior**: If the environment variable is not set or invalid, defaults to `8080`.

### Authentication URL

```gleam
/// The URL used to authenticate users. Required: the server cannot start
/// without a valid `https://` value.
pub fn authentication_url() -> String {
  let assert Ok("https://" <> url) = envoy.get("AUTHENTICATION_URL")
    as "Please, inform a valid AUTHENTICATION_URL environment variable according to the documentation."

  "https://" <> url
}
```

- **Parameters**: None.
- **Return Value**: A string representing the authentication URL.
- **Behavior**: If the environment variable is missing or malformed, returns a default value of `"https://"`.

### Use Native Connection IP

```gleam
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
```

- **Parameters**: None.
- **Return Value**: A boolean indicating whether to trust the native connection IP address.
- **Behavior**: If the environment variable is not set or malformed, defaults to `False`.

### Authorized Administrator IPs

```gleam
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
```

- **Parameters**: None.
- **Return Value**: A list of strings representing the authorized administrator IP addresses.
- **Behavior**: If the environment variable is missing or malformed, returns an empty list. If the JSON array is empty, returns an empty list.

## Internal Logic and Algorithms

The `environment.gleam` file uses several Gleam standard libraries to handle string manipulation, parsing, error handling, and JSON decoding. It relies on the `envoy` module for accessing environment variables.

```gleam
import envoy
```

This import statement ensures that all necessary functions for interacting with environment variables are available within the context of this file.

## Side Effects

The `environment.gleam` file performs I/O operations to fetch environmental variables from the system. It also uses JSON decoding to parse and validate settings stored in the environment variables.

```gleam
import gleam/dynamic/decode
import gleam/int
import gleam/json
```

These imports allow the file to handle different data types, such as integers, strings, and lists, which are commonly used in this configuration setting.

Overall, the `environment.gleam` file serves as a central repository for managing environment variables related to the web proxy server, ensuring that the server operates efficiently and securely.
