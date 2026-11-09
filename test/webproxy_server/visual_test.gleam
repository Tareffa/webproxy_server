import database
import gleam/bit_array
import gleam/bytes_tree
import gleam/dict
import gleam/dynamic/decode
import gleam/erlang/process
import gleam/int
import gleam/json
import gleam/list
import gleam/string
import mist
import webproxy_server/cluster
import webproxy_server/visual

// --- helpers ---------------------------------------------------------------

const key = <<"test-anonymization-key">>

fn insert_cluster(
  clusters: database.Table(cluster.Cluster),
  id: String,
  organization_id: String,
  ip_address: String,
  member_ids: List(String),
) -> Nil {
  let members =
    list.fold(member_ids, dict.new(), fn(acc, member_id) {
      dict.insert(acc, member_id, process.new_subject())
    })
  let assert Ok(_) = {
    use ref <- database.transaction(clusters)
    database.upsert(
      ref,
      id,
      cluster.Cluster(organization_id, ip_address, members),
    )
  }
  Nil
}

fn sample_clusters() -> database.Table(cluster.Cluster) {
  let clusters = cluster.new_clusters_table()
  insert_cluster(clusters, "cl-1", "org-1", "10.0.0.1", ["a", "b", "c"])
  insert_cluster(clusters, "cl-2", "org-1", "10.0.0.2", ["d"])
  insert_cluster(clusters, "cl-3", "org-2", "10.0.0.3", ["e", "f"])
  clusters
}

/// The anonymized organization of each summary, keyed by its session count
/// (unique in `sample_clusters`) so tests can tell the clusters apart.
fn organizations_by_sessions(
  summaries: List(visual.ClusterSummary),
) -> dict.Dict(Int, String) {
  list.fold(summaries, dict.new(), fn(acc, summary) {
    dict.insert(acc, summary.sessions, summary.organization)
  })
}

fn body_text(body: mist.ResponseData) -> String {
  let assert mist.Bytes(bytes) = body
  let assert Ok(text) = bit_array.to_string(bytes_tree.to_bit_array(bytes))
  text
}

// --- summarize -------------------------------------------------------------

pub fn summarize_counts_sessions_test() {
  let summaries = visual.summarize(sample_clusters(), key)

  let sessions =
    list.map(summaries, fn(summary) { summary.sessions })
    |> list.sort(int.compare)
  assert sessions == [1, 2, 3]
}

pub fn summarize_empty_test() {
  assert visual.summarize(cluster.new_clusters_table(), key) == []
}

pub fn summarize_groups_by_organization_test() {
  let organizations =
    visual.summarize(sample_clusters(), key) |> organizations_by_sessions

  // cl-1 (3 sessions) and cl-2 (1 session) share org-1; cl-3 (2) is org-2.
  assert dict.get(organizations, 3) == dict.get(organizations, 1)
  assert dict.get(organizations, 3) != dict.get(organizations, 2)
}

pub fn summarize_hides_identifiers_test() {
  let summaries = visual.summarize(sample_clusters(), key)

  let leaked =
    list.any(summaries, fn(summary) {
      let published = summary.id <> " " <> summary.organization
      list.any(["cl-", "org-", "10.0.0."], string.contains(published, _))
    })
  assert leaked == False

  // Cluster and organization ids are hashed in separate domains, so a cluster
  // id never doubles as an organization id.
  let ids = list.map(summaries, fn(summary) { summary.id })
  let organizations = list.map(summaries, fn(summary) { summary.organization })
  assert list.any(ids, list.contains(organizations, _)) == False
}

pub fn summarize_is_stable_per_key_test() {
  let clusters = sample_clusters()

  let ids = fn(anonymization_key) {
    visual.summarize(clusters, anonymization_key)
    |> list.map(fn(summary) { summary.id })
    |> list.sort(string.compare)
  }

  assert ids(key) == ids(key)
  assert ids(key) != ids(<<"another-key">>)
}

// --- endpoints -------------------------------------------------------------

pub fn data_endpoint_test() {
  let response = visual.data(sample_clusters(), key)
  assert response.status == 200

  let text = body_text(response.body)
  assert string.contains(text, "10.0.0.") == False

  let decoder = {
    use session_count <- decode.field("sessionCount", decode.int)
    use sessions <- decode.field(
      "clusters",
      decode.list(decode.at(["sessions"], decode.int)),
    )
    decode.success(#(session_count, list.sort(sessions, int.compare)))
  }
  assert json.parse(text, decoder) == Ok(#(6, [1, 2, 3]))
}

pub fn page_endpoint_test() {
  let response = visual.page()
  assert response.status == 200
  assert list.contains(response.headers, #(
    "content-type",
    "text/html; charset=utf-8",
  ))

  // The page is served intact, including its non-ASCII text, and polls the
  // data endpoint relative to its own path.
  let html = body_text(response.body)
  assert string.starts_with(html, "<!doctype html>")
  assert string.contains(html, "WebProxy · Live clusters")
  assert string.contains(html, "+ '/data'")
  assert string.ends_with(html, "</html>")
}
