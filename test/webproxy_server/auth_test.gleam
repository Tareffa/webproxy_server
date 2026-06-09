import database
import envoy
import webproxy_server/auth

const user1 = auth.User(
  id: "123",
  display_name: "John Doe",
  scopes: ["read", "write"],
  organization_id: "org1",
)

const user2 = auth.User(
  id: "456",
  display_name: "Jane Smith",
  scopes: ["read"],
  organization_id: "org2",
)

pub fn get_user_by_auth_token_test() {
  let cache = auth.new_user_table()
  let token = "jaguaruna"

  envoy.set("AUTHENTICATION_URL", "https://rhm.dev")

  assert Error(Nil) == auth.get_user_by_auth_token(cache, token)

  assert Ok(token)
    == database.transaction(cache, fn(ref) {
      let _ = database.upsert(ref, "other_token", user1)
      database.upsert(ref, token, user2)
    })

  assert Ok(user1) == auth.get_user_by_auth_token(cache, "other_token")
  assert Ok(user2) == auth.get_user_by_auth_token(cache, token)
}
