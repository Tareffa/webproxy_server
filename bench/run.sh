#!/bin/sh
#
# Puts the Gleam server (its last commit, GLEAM_REF) and the Hive one under the
# same synthetic load, one after the other, and prints each one's numbers and
# peak memory. Flags are handed to `bench load`, for example:
#
#   bench/run.sh -clients 500 -cluster 10 -duration 20s
#
# SERVERS picks which to run, "gleam hive" by default:
#
#   SERVERS=hive bench/run.sh -only request/provide
#
# and -active keeps most connections idle, which is what a large run looks like:
#
#   SERVERS=hive bench/run.sh -clients 100000 -cluster 10 -active 10000
#
# Needs git, go, gleam, erl and hive on the PATH.

set -eu

ROOT=$(cd "$(dirname "$0")/.." && pwd)
GLEAM_REF=${GLEAM_REF:-76ccf30}
SERVERS=${SERVERS:-gleam hive}
WORK=$(mktemp -d)
trap 'kill $(jobs -p) 2>/dev/null; rm -rf "$WORK"' EXIT

echo "Building..."
(cd "$ROOT/bench" && go build -o "$WORK/bench" .)
case "$SERVERS" in *gleam*)
  mkdir "$WORK/gleam"
  git -C "$ROOT" archive "$GLEAM_REF" | tar -x -C "$WORK/gleam"
  (cd "$WORK/gleam" && gleam export erlang-shipment >/dev/null)
esac
case "$SERVERS" in *hive*)
  hive build "$ROOT/src/main.hive" >/dev/null
  cp "$ROOT/src/main" "$WORK/hive"
esac

"$WORK/bench" auth -addr 127.0.0.1:18443 -ca "$WORK/ca.pem" >/dev/null &
sleep 1
export AUTHENTICATION_URL=https://127.0.0.1:18443/auth

# measure <name> <port> <pid> [bench load flags...]
measure() {
  name=$1 port=$2 server=$3
  shift 3
  until curl -sf "http://127.0.0.1:$port/health" >/dev/null; do sleep 0.2; done
  echo
  echo "== $name"
  "$WORK/bench" load -url "ws://127.0.0.1:$port/ws" "$@"
  echo "peak memory: $(grep VmHWM "/proc/$server/status" | tr -s ' ' | cut -d' ' -f2-)"
  kill "$server"
  wait "$server" 2>/dev/null || true
}

case "$SERVERS" in *gleam*)
  # +Q lifts Erlang's limit of 65,536 open sockets.
  PORT=18080 erl +Q 1048576 -pa "$WORK"/gleam/build/erlang-shipment/*/ebin -noshell \
    -eval "public_key:cacerts_load(\"$WORK/ca.pem\"), webproxy_server@@main:run(webproxy_server)" \
    >"$WORK/gleam.log" 2>&1 &
  measure gleam 18080 "$!" "$@"
esac

case "$SERVERS" in *hive*)
  SSL_CERT_FILE="$WORK/ca.pem" PORT=18090 "$WORK/hive" >"$WORK/hive.log" 2>&1 &
  measure hive 18090 "$!" "$@"
esac
