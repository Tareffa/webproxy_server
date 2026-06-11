-module(webproxy_server_ffi).

-define(SECONDS_IN_24H, 86400).

-export([delete_old_users_from_table/1]).

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
    ets:select_delete(Table, MatchSpec).
