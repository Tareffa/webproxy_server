-module(webproxy_server_ffi).

-define(SECONDS_IN_24H, 86400).

-export([delete_old_users_from_table/1, table_size/1]).

table_size(Table) ->
    ets:info(element(2, Table), size).

%% Users follow this pattern:
%% {UserId, {user, UserId, DisplayName, Scopes, OrganizationId, CreatedAt}}
delete_old_users_from_table(Table) ->
    CutoffTime = erlang:system_time(second) - ?SECONDS_IN_24H,
    MatchSpec = [
        {
            {'_', {user, '_', '_', '_', '_', '$1'}},  %% Bind CreatedAt to $1
            [{'<', '$1', CutoffTime}],                 %% Guard: CreatedAt < 24h ago
            [true]                                     %% Delete matching entries
        }
    ],
    ets:select_delete(element(2, Table), MatchSpec).
