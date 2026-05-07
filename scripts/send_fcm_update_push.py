#!/usr/bin/env python3
"""Send a data-only FCM v1 push notifying clients of a new release.

Reads the service-account JSON from the FCM_SERVICE_ACCOUNT_JSON env var,
posts to the FCM HTTP v1 endpoint for the project, and exits 0 on success.
On HTTP errors it prints to stderr but still exits 0 - the GitHub Release
is the source of truth, the push is a courtesy ping for installed clients.
"""

from __future__ import annotations

import json
import os
import sys

import google.auth.transport.requests
import requests
from google.oauth2 import service_account

FCM_SCOPE = "https://www.googleapis.com/auth/firebase.messaging"
TOPIC = "app-updates"


def main(argv: list[str]) -> int:
    sa_json = os.environ.get("FCM_SERVICE_ACCOUNT_JSON", "")
    if not sa_json:
        print("FCM_SERVICE_ACCOUNT_JSON empty; skipping push.")
        return 0

    if len(argv) != 3:
        print(f"usage: {argv[0]} <versionName> <versionCode>", file=sys.stderr)
        return 2

    version_name, version_code = argv[1], argv[2]

    sa = json.loads(sa_json)
    project_id = sa.get("project_id")
    if not project_id:
        print("Service account JSON has no project_id", file=sys.stderr)
        return 0

    creds = service_account.Credentials.from_service_account_info(sa, scopes=[FCM_SCOPE])
    creds.refresh(google.auth.transport.requests.Request())

    payload = {
        "message": {
            "topic": TOPIC,
            "data": {
                "type": "update",
                "versionName": version_name,
                "versionCode": version_code,
            },
            "android": {"priority": "HIGH"},
        }
    }

    url = f"https://fcm.googleapis.com/v1/projects/{project_id}/messages:send"
    headers = {
        "Authorization": f"Bearer {creds.token}",
        "Content-Type": "application/json; charset=UTF-8",
    }

    try:
        resp = requests.post(url, headers=headers, data=json.dumps(payload), timeout=15)
        resp.raise_for_status()
        print(f"FCM push sent: {resp.status_code} {resp.text.strip()}")
    except requests.HTTPError as exc:
        print(f"FCM push failed: {exc} body={exc.response.text if exc.response else ''}", file=sys.stderr)
    except requests.RequestException as exc:
        print(f"FCM push request error: {exc}", file=sys.stderr)
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
