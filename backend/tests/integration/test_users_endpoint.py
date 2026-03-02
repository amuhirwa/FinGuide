"""
Integration tests for /users endpoints.

Covers:
  GET  /users/me  - fetch current user profile
  PATCH /users/me - update profile fields
"""

BASE = "/api/v1/users"


class TestAuthGuard:
    def test_get_me_requires_auth(self, client):
        assert client.get(f"{BASE}/me").status_code == 401

    def test_patch_me_requires_auth(self, client):
        assert client.patch(f"{BASE}/me", json={}).status_code == 401


class TestGetProfile:
    def test_returns_user_profile(self, client, auth_headers, test_user):
        resp = client.get(f"{BASE}/me", headers=auth_headers)
        assert resp.status_code == 200
        body = resp.json()
        assert body["phone_number"] == test_user.phone_number
        assert body["full_name"] == test_user.full_name
        assert body["ubudehe_category"] == test_user.ubudehe_category.value
        assert body["income_frequency"] == test_user.income_frequency.value

    def test_returns_is_active_and_is_verified(self, client, auth_headers, test_user):
        resp = client.get(f"{BASE}/me", headers=auth_headers)
        body = resp.json()
        assert body["is_active"] is True
        assert body["is_verified"] is True

    def test_id_matches_test_user(self, client, auth_headers, test_user):
        resp = client.get(f"{BASE}/me", headers=auth_headers)
        assert resp.json()["id"] == test_user.id


class TestUpdateProfile:
    def test_update_full_name(self, client, auth_headers, test_user):
        resp = client.patch(
            f"{BASE}/me",
            json={"full_name": "Updated Name"},
            headers=auth_headers,
        )
        assert resp.status_code == 200
        assert resp.json()["full_name"] == "Updated Name"

    def test_empty_body_returns_unchanged_profile(self, client, auth_headers, test_user):
        original_name = test_user.full_name
        resp = client.patch(f"{BASE}/me", json={}, headers=auth_headers)
        assert resp.status_code == 200
        assert resp.json()["full_name"] == original_name

    def test_partial_update_only_changes_given_field(self, client, auth_headers, test_user):
        original_phone = test_user.phone_number
        resp = client.patch(
            f"{BASE}/me",
            json={"full_name": "New Name Only"},
            headers=auth_headers,
        )
        assert resp.status_code == 200
        body = resp.json()
        assert body["full_name"] == "New Name Only"
        assert body["phone_number"] == original_phone

    def test_updated_profile_is_persisted(self, client, auth_headers):
        client.patch(f"{BASE}/me", json={"full_name": "Persisted"}, headers=auth_headers)
        resp = client.get(f"{BASE}/me", headers=auth_headers)
        assert resp.json()["full_name"] == "Persisted"
