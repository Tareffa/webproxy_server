//// The `/info/visual` dashboard: a static page that draws the clusters and
//// their live sessions in 3D, polling `/info/visual/data` for fresh snapshots.
////
//// Both endpoints are public, so the snapshot is anonymized: cluster and
//// organization ids are replaced by keyed hashes (see `anonymize`), and no IP
//// addresses, user ids or display names ever leave the server.

import database
import gleam/bit_array
import gleam/crypto
import gleam/dict
import gleam/http/response
import gleam/json
import gleam/list
import gleam/string
import mist
import webproxy_server/cluster.{type Cluster}
import webproxy_server/web

/// A cluster as published by `/info/visual/data`. `sessions` counts the
/// cluster's members, which are keyed by user id.
@internal
pub type ClusterSummary {
  ClusterSummary(id: String, organization: String, sessions: Int)
}

/// The page's HTML, embedded in `src/webproxy_server_visual_page.erl`.
@external(erlang, "webproxy_server_visual_page", "html")
fn page_html() -> String

/// Serves the visualization page.
pub fn page() -> response.Response(mist.ResponseData) {
  response.new(200)
  |> response.set_header("content-type", "text/html; charset=utf-8")
  |> response.set_header("cache-control", "no-cache")
  |> web.set_body(page_html())
}

/// Serves the anonymized snapshot polled by the page:
///
/// ```json
/// {
///   "sessionCount": 5,
///   "clusters": [{ "id": "3fa9c1d2e0", "organization": "9b8a7c6d5e", "sessions": 5 }]
/// }
/// ```
pub fn data(
  clusters: database.Table(Cluster),
  anonymization_key: BitArray,
) -> response.Response(mist.ResponseData) {
  let summaries = summarize(clusters, anonymization_key)
  let session_count =
    list.fold(summaries, 0, fn(total, summary) { total + summary.sessions })

  let body =
    json.object([
      #("sessionCount", json.int(session_count)),
      #("clusters", json.array(summaries, summary_to_json)),
    ])
    |> json.to_string

  response.new(200)
  |> response.set_header("content-type", "application/json")
  |> response.set_header("cache-control", "no-store")
  |> web.set_body(body)
}

/// Every stored cluster with its ids anonymized and its members counted.
@internal
pub fn summarize(
  clusters: database.Table(Cluster),
  anonymization_key: BitArray,
) -> List(ClusterSummary) {
  cluster.all_clusters(clusters)
  |> list.map(fn(entry) {
    let #(id, cluster) = entry
    ClusterSummary(
      id: anonymize(anonymization_key, "cluster", id),
      organization: anonymize(
        anonymization_key,
        "organization",
        cluster.organization_id,
      ),
      sessions: dict.size(cluster.members),
    )
  })
}

fn summary_to_json(summary: ClusterSummary) -> json.Json {
  json.object([
    #("id", json.string(summary.id)),
    #("organization", json.string(summary.organization)),
    #("sessions", json.int(summary.sessions)),
  ])
}

/// Cluster ids are an unsalted hash of `(organization_id, ip_address)`, so
/// publishing them (even truncated) next to the organization would let anyone
/// recover the IP by brute force. Instead, both ids are replaced by an HMAC
/// under a key generated at boot. The result stays stable for the life of the
/// process, so the page can animate changes, but means nothing outside it.
fn anonymize(key: BitArray, kind: String, value: String) -> String {
  crypto.hmac(bit_array.from_string(kind <> ":" <> value), crypto.Sha256, key)
  |> bit_array.base16_encode
  |> string.slice(at_index: 0, length: 10)
  |> string.lowercase
}
