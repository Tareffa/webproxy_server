# Log Proxy Server Logger

The `log.gleam` file in the `src/webproxy_server` directory is responsible for handling and processing log messages from the web proxy server. It encapsulates a logger that stores and processes logs efficiently in a distributed system using Dets tables and Erlang atoms.

### Public Exported Classes, Functions, Constants

#### Log
```gleam
type Log {
  Log(timestamp: Float, error: Bool, message: String)
}
```
- **Parameters**: `timestamp: Float` — The timestamp at which the log occurred.
- **Return Value**: `Log` — An instance of the log structure containing the timestamp, error status, and message.

#### Logger
```gleam
pub opaque type Logger {
  Logger(db: database.Table(Log))
}
```
- **Parameters**: `db: database.Table(Log)` — The Dets table where log messages are stored.

### Internal Logic, Algorithms, Side Effects

#### log_decoder()
```gleam
fn log_decoder() {
  use timestamp <- database.field(0, decode.float)
  use error <- database.field(1, decode.bool)
  use message <- database.field(2, decode.string)
  decode.success(Log(timestamp, error, message))
}
```
- **Purpose**: Defines a decoder function for `Log` messages stored in the Dets table.
- **Parameters**: None
- **Return Value**: A decoded `Log` instance.

#### new_logger()
```gleam
pub fn new_logger() -> Result(Logger, database.FileError) {
  let name = atom.create("logs")
  use table <- result.try(database.create_dets_table(name, log_decoder()))
  Ok(Logger(table))
}
```
- **Purpose**: Initializes a logger by creating a Dets table for storing logs.
- **Parameters**: None
- **Return Value**:
  - `Ok(Logger(table))` — Returns a new logger instance with the specified Dets table.
  - `Err(database.FileError)` — Returns an error if the Dets table creation fails.

#### println()
```gleam
pub fn println(with logger: Logger, message message: String) {
  io.println(message)
  let now = timestamp.system_time() |> timestamp.to_unix_seconds()
  let log = Log(now, False, message)
  let _ = database.transaction(logger.db, fn(ref) { database.insert(ref, log) })
  Nil
}
```
- **Purpose**: Logs a message to the console and persists it in the Dets table.
- **Parameters**:
  - `with logger: Logger` — The logger instance to which the log will be appended.
  - `message message: String` — The message to log.
- **Return Value**: None

#### println_error()
```gleam
pub fn println_error(with logger: Logger, message message: String) {
  io.println_error(message)
  let now = timestamp.system_time() |> timestamp.to_unix_seconds()
  let log = Log(now, True, message)
  let _ = database.transaction(logger.db, fn(ref) { database.insert(ref, log) })
  Nil
}
```
- **Purpose**: Logs an error message to the console and persists it in the Dets table.
- **Parameters**:
  - `with logger: Logger` — The logger instance to which the log will be appended.
  - `message message: String` — The error message to log.
- **Return Value**: None

#### dump()
```gleam
pub fn dump(from logger: Logger) {
  use ref <- database.transaction(logger.db)
  use logs <- result.try(database.select(ref, #(Log)))
  logs
  |> list.sort(fn(a, b) { float.compare(a.1.timestamp, b.1.timestamp) })
  |> list.map(fn(log) {
    let Log(timestamp, error, message) = log.1
    case error {
      True -> "[ERROR] {" <> float.to_string(timestamp) <> "}: " <> message
      False -> "[INFO] {" <> float.to_string(timestamp) <> "}: " <> message
    }
  })
  |> string.join("\n")
  |> Ok
}
```
- **Purpose**: Retrieves all logs from the Dets table and formats them as a string.
- **Parameters**:
  - `from logger: Logger` — The logger instance to retrieve the logs from.
- **Return Value**:
  - `Ok(string)` — Returns a string containing all formatted logs.
  - `Err(database.FileError)` — Returns an error if the log retrieval fails.
