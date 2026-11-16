### **File: test/webproxy_server/intervention_test.gleam**

#### Purpose and Role in the Project

The `intervention_test.gleam` file contains test cases for various functionalities within the web proxy server's intervention module. This module is responsible for managing user deletion, cluster operations, and resource invalidation. The tests ensure that these functions behave as expected and handle different scenarios gracefully.

#### Structure of the File

- **Helpers**: Several helper functions are defined to insert users and clusters into the database, as well as to retrieve display names and members.
- **Drops**:
  - `drop_users_test`: Tests deleting users by their display name, ensuring that only matching records are deleted.
  - `drop_users_none_test`: Tests deleting users when none match the specified criteria.
  - `drop_cluster_test`: Tests removing a specific cluster from the system.
  - `drop_pending_resource_test`: Tests invalidating a pending resource.
  - `drop_invalid_test`: Verifies that an invalid command is rejected with appropriate feedback.
- **Cluster Report**:
  - `cluster_report_all_test`: Checks if all clusters are reported correctly when no parameters are provided.
  - `cluster_report_single_test`: Validates reporting a single cluster based on its ID.
  - `cluster_report_by_user_test`: Confirms that users are correctly included in the reported list of clusters.
  - `cluster_report_missing_test`: Ensures that an error is thrown when no clusters are found.
- **Invalidate Resource**:
  - `invalidate_all_test`: Tests invalidating all connections by resource name.
  - `invalidate_user_test`: Confirms that a specific user's connections are notified when resources are invalidated.
  - `invalidate_cluster_test`: Checks if only the targeted cluster is notified when resources are invalidated.
  - `invalidate_invalid_test`: Verifies that an invalid command is rejected with clear feedback.
- **Select Idioms**:
  - `select_users_by_display_name_test`: Ensures that a custom `select_fn` correctly filters users by their display name, returning only the matching records.
  - `select_all_clusters_test`: Validates that the `select_fn` for listing all clusters compiles to a wildcard pattern, ensuring all records are fetched.

#### Note

This file is designed to be self-contained and clear, making it easy for developers to understand and test various functionalities within the web proxy server's intervention module.
