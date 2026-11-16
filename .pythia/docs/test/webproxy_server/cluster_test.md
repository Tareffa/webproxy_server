# `test/webproxy_server/cluster_test.gleam`

## Introduction

The `cluster_test.gleam` file is a test suite designed to validate the functionality of the `cluster` module in the `webproxy_server` component. This module manages clusters, allowing for the addition and removal of peers based on user authentication and network interactions.

## Public Functions

### `join_cluster_test()`

This function tests the `join_cluster/5` function in the `cluster` module. It performs the following steps:
1. Creates a new cluster table.
2. Creates an outbound subject.
3. Joins a cluster with user credentials, IP address, and outbound subject.
4. Verifies that a cluster ID is returned.
5. Finds the joined cluster from the database.
6. Asserts that the cluster size is one.

### `leave_cluster_test()`

This function tests the `leave_cluster/4` function in the `cluster` module. It performs the following steps:
1. Creates a new cluster table.
2. Joins a cluster with user credentials, IP address, and outbound subject.
3. Leaves the cluster using the returned cluster ID and user ID.
4. Verifies that an error is raised when attempting to leave a non-existent cluster.

### `get_connected_peers_test()`

This function tests the `get_connected_peers/5` function in the `cluster` module. It performs the following steps:
1. Creates a new cluster table.
2. Joins two clusters with user credentials, IP addresses, and outbound subjects.
3. Retrieves the connected peers for each joined cluster using the respective cluster ID and user ID.
4. Verifies that the number of connected peers matches the expected count.

## Internal Logic

The `cluster` module uses a dictionary (`clusters_table`) to manage clusters. It performs operations such as:
- Creating new clusters table.
- Joining a cluster with user credentials and outbound subject.
- Leaving a cluster using the returned cluster ID and user ID.
- Retrieving connected peers for each joined cluster.

The internal logic is designed to handle network interactions, peer authentication, and error handling efficiently.
