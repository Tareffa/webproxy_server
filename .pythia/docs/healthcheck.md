# Healthcheck Script

The `healthcheck.sh` script is a utility designed to monitor the status of an application running inside a Podman container. This script performs HTTP requests to verify that the application instance is operational and responsive.

### Purpose and Role in the Project

- **Periodic Check**: The script is executed by the Podman container engine on a regular schedule (e.g., every 60 seconds).
- **Exit Code Interpretation**:
  - Exit code `0`: The health check passes.
  - Any other exit code: The health check fails. Multiple consecutive failures indicate that the instance is unhealthy and will cause Podman to terminate it.

### Description of Public/Exported Classes, Functions, Constants

The script does not contain any public classes, functions, or constants.

### Notable Internal Logic, Algorithms, Side Effects

- **HTTP Request**: The `wget` command is used to send an HTTP GET request to the application running on `http://127.0.0.1:8080`. This is a common method for checking if a web server is responding.
- **Exit Code Handling**: The script checks the exit code of `wget` after sending the request. If the exit code is `0`, it indicates that the application is healthy and the health check passes. Any other exit code results in a failure, with multiple failures indicating an unhealthy instance.

### Companion Files Together

Since this is a single file, there are no companion files to document together as one unit.
