#!/usr/bin/env python3
# =============================================================================
# GoatAuth — Python example client (standard library only, no dependencies)
# =============================================================================
#
# This is an EXAMPLE showing how to authenticate YOUR OWN software against a
# GoatAuth server. You embed this kind of logic in the client program you
# distribute to your users; it talks to the GoatAuth client API at /api/v1/*.
#
# Every endpoint is a POST with a JSON body that always includes your app_id
# and secret (the app's public identity + shared secret from the dashboard),
# plus endpoint-specific fields.
#
# Every response is JSON with a boolean "success" flag:
#   * On success  -> {"success": true, ...fields}
#   * On failure  -> {"success": false, "message": "...", "code": "..."}
#
# The important response fields:
#   token   : opaque session token; store it and pass it back to verify()
#   user    : {
#               "username":          str,
#               "level":             int,          # subscription tier
#               "expires_at":        int | None,   # epoch MILLISECONDS, None = lifetime
#               "expires_iso":       str | None,   # ISO-8601 timestamp, None = lifetime
#               "seconds_remaining": int | None,   # None = lifetime
#               "lifetime":          bool,
#               "created_at":        int           # epoch MILLISECONDS
#             }
#   version : {
#               "outdated":     bool,              # True if your version != latest
#               "latest":       str,               # newest published version
#               "download_url": str | None         # where to grab the update
#             }
#
# NOTE: Do not treat the client-side "secret" as truly secret — anything you
# ship can be extracted. GoatAuth's real protection comes from server-side
# checks (key consumption, HWID locking, bans, expiry), not from hiding the
# secret. This example keeps the secret in the file purely for clarity.
# =============================================================================

import json
import hashlib
import uuid
import platform
import urllib.request
import urllib.error

# --- Configuration -----------------------------------------------------------
# Point this at your GoatAuth server. In production use https://your-domain.
BASE_URL = "http://localhost:3000"

# Replace these with the values shown on your app's dashboard page.
APP_ID = "your-app-id-here"
SECRET = "your-app-secret-here"

# The version string of THIS build of your software. The server compares it
# against the latest published version to tell you when an update is available.
APP_VERSION = "1.0"


# --- Hardware ID -------------------------------------------------------------
def get_hwid() -> str:
    """
    Compute a stable-ish hardware identifier for this machine.

    We combine the primary NIC's MAC address (uuid.getnode()) with a couple of
    coarse platform facts and hash the result so we never send raw hardware
    details over the wire. This is 'good enough' for a demo; production clients
    often mix in disk serials, CPU IDs, etc. for a stronger fingerprint.
    """
    raw = "|".join(
        [
            str(uuid.getnode()),      # MAC-derived node id
            platform.system(),         # e.g. "Windows" / "Linux" / "Darwin"
            platform.machine(),        # e.g. "x86_64"
            platform.node(),           # hostname
        ]
    )
    return hashlib.sha256(raw.encode("utf-8")).hexdigest()


# --- Low-level HTTP helper ---------------------------------------------------
def _post(endpoint: str, payload: dict) -> dict:
    """
    POST a JSON body to /api/v1/<endpoint> and return the decoded JSON dict.

    Always injects app_id + secret. Reads the response as JSON regardless of
    HTTP status (GoatAuth returns a JSON error envelope on failures too), so
    callers can rely on the "success" flag rather than exceptions.
    """
    body = {"app_id": APP_ID, "secret": SECRET, **payload}
    data = json.dumps(body).encode("utf-8")

    req = urllib.request.Request(
        f"{BASE_URL}/api/v1/{endpoint}",
        data=data,
        method="POST",
        headers={
            "Content-Type": "application/json",
            "Accept": "application/json",
        },
    )

    try:
        with urllib.request.urlopen(req, timeout=15) as resp:
            return json.loads(resp.read().decode("utf-8"))
    except urllib.error.HTTPError as exc:
        # 4xx/5xx still carry a JSON error body — decode and return it so the
        # caller can inspect success/message/code uniformly.
        try:
            return json.loads(exc.read().decode("utf-8"))
        except Exception:
            return {
                "success": False,
                "message": f"HTTP {exc.code} {exc.reason}",
                "code": "http_error",
            }
    except urllib.error.URLError as exc:
        return {
            "success": False,
            "message": f"Network error: {exc.reason}",
            "code": "network_error",
        }


# --- Public API --------------------------------------------------------------
def init() -> dict:
    """
    Handshake with the server. Returns app info + version details (whether this
    build is outdated and where to download the latest). Call this at startup.
    """
    return _post("init", {"version": APP_VERSION})


def register(username: str, password: str, key: str, hwid: str) -> dict:
    """Create a new user, consuming a license key. Returns a session on success."""
    return _post(
        "register",
        {"username": username, "password": password, "key": key, "hwid": hwid},
    )


def login(username: str, password: str, hwid: str) -> dict:
    """Authenticate an existing username/password. Returns a session on success."""
    return _post("login", {"username": username, "password": password, "hwid": hwid})


def license(key: str, hwid: str) -> dict:
    """
    License-only authentication: the key itself is the credential (no username
    or password). Returns a session on success.
    """
    return _post("license", {"key": key, "hwid": hwid})


def verify(token: str, hwid: str) -> dict:
    """
    Re-check a previously issued token (e.g. periodically, or on next launch)
    to confirm the session is still valid and the user is not banned/expired.
    """
    return _post("verify", {"token": token, "hwid": hwid})


# --- Helpers -----------------------------------------------------------------
def _print_user(user: dict) -> None:
    """Pretty-print the subscription info from a `user` payload."""
    if not user:
        print("  (no user attached to this session)")
        return
    print(f"  username          : {user['username']}")
    print(f"  level             : {user['level']}")
    if user["lifetime"]:
        print("  subscription      : LIFETIME (never expires)")
    else:
        print(f"  expires (iso)     : {user['expires_iso']}")
        print(f"  seconds remaining : {user['seconds_remaining']}")


# --- Demo --------------------------------------------------------------------
def main() -> None:
    hwid = get_hwid()
    print(f"HWID: {hwid}\n")

    # 1) Handshake + update check.
    print("== init ==")
    res = init()
    if not res.get("success"):
        print(f"init failed: {res.get('message')} (code={res.get('code')})")
        return
    version = res["version"]
    print(f"  latest version    : {version['latest']}")
    print(f"  outdated          : {version['outdated']}")
    if version["outdated"]:
        print(f"  download update   : {version['download_url']}")
    print()

    # 2) Log in with sample credentials (swap for real ones / a UI prompt).
    print("== login ==")
    res = login("sample_user", "sample_password", hwid)
    if not res.get("success"):
        print(f"login failed: {res.get('message')} (code={res.get('code')})")
        return
    token = res["token"]
    print("  login OK, subscription:")
    _print_user(res.get("user"))
    print()

    # 3) Verify the token we just received.
    print("== verify ==")
    res = verify(token, hwid)
    if not res.get("success"):
        print(f"verify failed: {res.get('message')} (code={res.get('code')})")
        return
    print("  token is valid, subscription:")
    _print_user(res.get("user"))


if __name__ == "__main__":
    main()
