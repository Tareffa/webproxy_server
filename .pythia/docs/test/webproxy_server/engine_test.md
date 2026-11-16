# WebProxyServer Engine Test

This test file contains the implementation and tests for the `WebProxyServer.Engine` module. It is responsible for handling HTTP requests and responses within the web proxy server.

## Module Documentation

The `WebProxyServer.Engine` module provides functionality to manage incoming HTTP requests and send appropriate responses. The main entry point of this module is the `main/1` function, which takes a list of handlers as input.

### Public Functions and Classes

- **handle_request/2**: This function processes an incoming HTTP request and returns a response. It takes two parameters: the request object (`Request`) and the route handler function (`Handler`). The response can be either a string (for static content) or another `Response` struct.
  - Parameters:
    - `request`: An instance of `WebProxyServer.Request`.
    - `handler`: A function that processes the request and returns a response.

- **response_handler/1**: This function is used to define the route handler functions for specific routes. It takes a single parameter: the route pattern (`Pattern`).
  - Parameters:
    - `pattern`: The pattern string representing the URL path.
    - `handler`: A function that processes requests matching the given pattern.

- **parse_request/1**: This helper function parses an incoming HTTP request and extracts relevant information such as method, headers, and body. It returns a `Request` struct.
  - Parameters:
    - `request_str`: The string representation of the HTTP request.
  - Returns:
    - A `WebProxyServer.Request`.

### Internal Logic

- **HTTP Request Parsing**: The `parse_request/1` function uses regular expressions to parse the incoming HTTP request and extract necessary information such as method, headers, and body. This allows for easy processing of different types of HTTP requests.

- **Routing and Dispatching**: The `handle_request/2` function uses the route pattern provided by the `response_handler/1` function to dispatch requests to the appropriate handler functions. If no matching pattern is found, it returns a default response or logs an error.

- **Response Generation**: The `handler/2` functions are responsible for generating responses based on the request data. This involves processing the request body and applying any necessary transformations before returning a suitable HTTP response.

### Error Handling

- **Error Messages**: If an error occurs during the handling of an incoming request, such as invalid headers or malformed JSON, appropriate error messages are returned to the client. This helps in debugging issues and providing clear feedback to users.

### Example Usage

```gleam
let result = WebProxyServer.Engine.handle_request(WebProxyServer.Request.new("GET", "/example", "application/json"), (req, res) {
  if req.method == "POST" {
    res.send("Received POST request")
  } else {
    res.send("Hello World!")
  }
})
```

This example demonstrates how to use the `WebProxyServer.Engine` module to handle an incoming HTTP GET request and return a simple response.
