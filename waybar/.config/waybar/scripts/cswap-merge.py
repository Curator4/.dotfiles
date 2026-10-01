#!/usr/bin/env python3
"""Merge cswap Claude accounts into a CodexBar usage JSON array.

CodexBar's /usage endpoint only reports the active CLI login. When claude-swap
manages extra seats, this script annotates that login and appends the others
so waybar/tooltip/popup can show both.

Reads a CodexBar usage array on stdin. Writes the merged array to stdout.
Missing cswap, timeouts, and empty account lists are a no-op.
"""

from __future__ import annotations

import json
import os
import subprocess
import sys
from datetime import datetime, timezone
from pathlib import Path

CSWAP = os.environ.get("CSWAP_BIN", str(Path.home() / ".local/bin" / "cswap"))
TIMEOUT = float(os.environ.get("CSWAP_LIST_TIMEOUT", "5"))


def _load_stdin() -> object:
    raw = sys.stdin.read()
    if not raw.strip():
        return []
    try:
        return json.loads(raw)
    except json.JSONDecodeError:
        return None


def _cswap_list() -> dict | None:
    if not os.path.isfile(CSWAP) or not os.access(CSWAP, os.X_OK):
        return None
    try:
        proc = subprocess.run(
            [CSWAP, "list", "--json"],
            capture_output=True,
            text=True,
            timeout=TIMEOUT,
            check=False,
        )
    except (FileNotFoundError, subprocess.TimeoutExpired, OSError):
        return None
    if proc.returncode != 0 or not proc.stdout.strip():
        return None
    try:
        data = json.loads(proc.stdout)
    except json.JSONDecodeError:
        return None
    if not isinstance(data, dict) or data.get("schemaVersion") != 1:
        return None
    accounts = data.get("accounts")
    if not isinstance(accounts, list) or not accounts:
        return None
    return data


def _label(account: dict) -> str:
    alias = account.get("alias")
    email = account.get("email")
    if isinstance(alias, str) and alias.strip():
        return alias.strip()
    if isinstance(email, str) and email.strip():
        return email.strip()
    number = account.get("number")
    return f"account {number}" if number is not None else "claude"


def _meta(account: dict) -> dict:
    meta = {
        "number": account.get("number"),
        "active": bool(account.get("active")),
    }
    if account.get("alias"):
        meta["alias"] = account["alias"]
    if account.get("email"):
        meta["email"] = account["email"]
    return meta


def _reset_description(iso: str | None) -> str | None:
    if not iso:
        return None
    try:
        ts = datetime.fromisoformat(iso.replace("Z", "+00:00")).astimezone()
    except (TypeError, ValueError):
        return None
    return ts.strftime("Resets %-I:%M%p (%Z)")


def _window(cswap_window: dict | None, minutes: int) -> dict | None:
    if not isinstance(cswap_window, dict):
        return None
    pct = cswap_window.get("pct")
    resets_at = cswap_window.get("resetsAt")
    if not isinstance(pct, (int, float)) and not resets_at:
        return None
    out: dict = {"windowMinutes": minutes}
    if isinstance(pct, (int, float)):
        out["usedPercent"] = pct
    if isinstance(resets_at, str) and resets_at:
        out["resetsAt"] = resets_at
        desc = _reset_description(resets_at)
        if desc:
            out["resetDescription"] = desc
    return out


def _usage_block(account: dict) -> dict | None:
    usage = account.get("usage")
    if not isinstance(usage, dict):
        usage = account.get("lastGoodUsage")
    if not isinstance(usage, dict):
        return None
    primary = _window(usage.get("fiveHour"), 300)
    secondary = _window(usage.get("sevenDay"), 10080)
    if primary is None and secondary is None:
        return None
    updated = usage.get("usageFetchedAt") or datetime.now(timezone.utc).strftime(
        "%Y-%m-%dT%H:%M:%SZ"
    )
    identity = {"providerID": "claude"}
    email = account.get("email")
    if isinstance(email, str) and email:
        identity["accountEmail"] = email
    return {
        "primary": primary,
        "secondary": secondary,
        "tertiary": None,
        "dataConfidence": "percentOnly",
        "updatedAt": updated,
        "identity": identity,
    }


def _entry_from_cswap(account: dict) -> dict:
    label = _label(account)
    entry: dict = {
        "provider": "claude",
        "account": label,
        "source": "cswap",
        "cswap": _meta(account),
    }
    usage = _usage_block(account)
    if usage is not None:
        entry["usage"] = usage
        return entry
    status = account.get("usageStatus") or "unavailable"
    err = account.get("usageError") or status
    entry["error"] = {"message": f"cswap: usage {err}"}
    return entry


def _claude_host(entries: list) -> dict | None:
    """Pick one CodexBar Claude row to represent the active login."""
    if not entries:
        return None
    healthy = [
        e for e in entries
        if not e.get("error") and isinstance(e.get("usage"), dict)
    ]
    pool = healthy or entries
    labeled = [e for e in pool if e.get("account")]
    return (labeled or pool)[0]


def merge(body: list, cswap: dict) -> list:
    accounts = [a for a in cswap.get("accounts", []) if isinstance(a, dict)]
    if not accounts:
        return body

    active = next((a for a in accounts if a.get("active")), None)
    claude = [e for e in body if isinstance(e, dict) and e.get("provider") == "claude"]
    others = [e for e in body if not (isinstance(e, dict) and e.get("provider") == "claude")]

    host = _claude_host(claude)
    if active is not None and host is not None:
        primary = dict(host)
        primary["account"] = _label(active)
        primary["cswap"] = _meta(active)
        usage = primary.get("usage")
        if isinstance(usage, dict):
            identity = dict(usage.get("identity") or {})
            identity.setdefault("providerID", "claude")
            if active.get("email"):
                identity["accountEmail"] = active["email"]
            usage = dict(usage)
            usage["identity"] = identity
            primary["usage"] = usage
        claude = [primary]
    elif host is not None:
        claude = [host]
    else:
        claude = []

    seen: set = set()
    for entry in claude:
        meta = entry.get("cswap") if isinstance(entry, dict) else None
        if isinstance(meta, dict) and meta.get("number") is not None:
            seen.add(meta["number"])
        account = entry.get("account") if isinstance(entry, dict) else None
        if account:
            seen.add(str(account))
        if active is not None:
            seen.add(active.get("number"))
            seen.add(_label(active))

    extras = []
    for account in accounts:
        if account.get("active"):
            continue
        number = account.get("number")
        label = _label(account)
        if number in seen or label in seen:
            continue
        extras.append(_entry_from_cswap(account))
        seen.add(number)
        seen.add(label)

    return others + claude + extras


def main() -> int:
    body = _load_stdin()
    if not isinstance(body, list):
        if isinstance(body, str):
            sys.stdout.write(body)
        elif body is not None:
            json.dump(body, sys.stdout)
        return 0
    cswap = _cswap_list()
    if cswap is None:
        json.dump(body, sys.stdout)
        return 0
    json.dump(merge(body, cswap), sys.stdout)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
