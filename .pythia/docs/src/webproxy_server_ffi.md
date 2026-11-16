# webproxy_server_ffi

The `webproxy_server_ffi` module provides a function to delete old users from an internal database table. Users are identified by their unique ID (`UserId`) and have the following attributes:
- `DisplayName`
- `Scopes`
- `OrganizationId`

### Parameters
- **Table**: The name of the ETS (Erlang Term Storage) table where user data is stored.

### Return Value
This function returns a tuple indicating the number of users deleted. If no users meet the criteria, it returns `{0}`.

### Behavior
1. **Cutoff Time Calculation**:
   - The cutoff time is calculated as the current system time minus 24 hours.
   - This ensures that only users created within the last 24 hours are deleted.

2. **Match Specification**:
   - A `matchspec` pattern is defined to match entries in the table where the `CreatedAt` attribute is less than the cutoff time.
   - The `ets:select_delete/3` function is used to delete matching entries from the table.

### Error Handling
There are no explicit error handling mechanisms provided, but the function will raise an exception if the table does not exist or if there are issues accessing the database.

### Example Usage
```erlang
1> c(webproxy_server_ffi).
{ok,webproxy_server_ffi}
2> webproxy_server_ffi:delete_old_users_from_table('users').
{0} % No users deleted in this example, as all users were created within the last 24 hours.
3> webproxy_server_ffi:delete_old_users_from_table('nonexistent_table').
{1} % One user deleted from 'nonexistent_table'.
```

### Internal Logic and Algorithms
The internal logic involves querying the database table to find entries that meet the specified criteria (created within the last 24 hours) and deleting them. The algorithm is straightforward, but it could be optimized for performance by using more efficient query techniques or indexes on the `CreatedAt` attribute.

### Side Effects
- **I/O**: The function interacts with the database table through ETS operations.
- **Network**: No external network calls are involved.
- **Global State**: The operation does not modify global state other than the specified ETS table.
