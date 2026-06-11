import database
import gleam/dynamic/decode
import gleam/erlang/atom
import gleam/float
import gleam/io
import gleam/list
import gleam/result
import gleam/string
import gleam/time/timestamp

type Log {
  Log(timestamp: Float, error: Bool, message: String)
}

pub opaque type Logger {
  Logger(db: database.Table(Log))
}

fn log_decoder() {
  use timestamp <- database.field(0, decode.float)
  use error <- database.field(1, decode.bool)
  use message <- database.field(2, decode.string)
  decode.success(Log(timestamp, error, message))
}

pub fn new_logger() -> Result(Logger, database.FileError) {
  let name = atom.create("logs")
  use table <- result.try(database.create_dets_table(name, log_decoder()))
  Ok(Logger(table))
}

pub fn println(with logger: Logger, message message: String) {
  io.println(message)
  let now = timestamp.system_time() |> timestamp.to_unix_seconds()
  let log = Log(now, False, message)
  let _ = database.transaction(logger.db, fn(ref) { database.insert(ref, log) })
  Nil
}

pub fn println_error(with logger: Logger, message message: String) {
  io.println_error(message)
  let now = timestamp.system_time() |> timestamp.to_unix_seconds()
  let log = Log(now, True, message)
  let _ = database.transaction(logger.db, fn(ref) { database.insert(ref, log) })
  Nil
}

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
