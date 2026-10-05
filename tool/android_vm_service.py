"""Validate the live integration VM and narrowly classify driver transport loss."""

import json
from pathlib import Path
import re
import sys
import urllib.parse
import urllib.request
from urllib.error import URLError


def verify_vm_service(base_url: str, target: str) -> bool:
    """Return true only when this loopback VM is running the requested test."""
    try:
        parsed = urllib.parse.urlsplit(base_url)
        if parsed.scheme != "http" or parsed.hostname not in (
            "127.0.0.1",
            "localhost",
            "::1",
        ):
            return False

        def call(method: str, **arguments: str) -> dict:
            url = base_url.rstrip("/") + "/" + method
            if arguments:
                url += "?" + urllib.parse.urlencode(arguments)
            with urllib.request.urlopen(url, timeout=1) as response:
                value = json.loads(response.read())
                return value.get("result", value)

        vm = call("getVM")
        for isolate in vm.get("isolates", []):
            if isolate.get("name") != "main" or isolate.get(
                "isSystemIsolate", False
            ):
                continue
            details = call("getIsolate", isolateId=isolate["id"])
            uri = details.get("rootLib", {}).get("uri", "")
            name = urllib.parse.unquote(urllib.parse.urlsplit(uri).path).rsplit(
                "/", 1
            )[-1]
            if name == Path(target).name:
                return True
        return False
    except (URLError, OSError, ValueError, KeyError, TypeError):
        return False


def may_retry_transport(log: str) -> bool:
    """Retry only a known VM transport loss, never a test or app failure."""
    failures = (
        "Some tests failed",
        "TestFailure",
        "Test failed.",
        "EXCEPTION CAUGHT BY FLUTTER",
        "FATAL EXCEPTION",
        "Fatal signal",
        "Unhandled Exception:",
    )
    if any(marker in log for marker in failures):
        return False
    if (
        "All tests passed" in log
        and "DriverError: Failed to fulfill RequestData" in log
        and "Service has disappeared" in log
    ):
        return True

    # On slow emulators flutter drive can connect to the paused test isolate,
    # then lose it before the test framework starts. Permit one complete rerun
    # only for this exact handshake failure and only before any test progress.
    if "getIsolate: (112) Service has disappeared" not in log:
        return False
    test_progress = re.search(r"(?m)^\s*\d{2}:\d{2} \+\d+:", log)
    return not test_progress


if __name__ == "__main__":
    if sys.argv[1] == "ready":
        ok = verify_vm_service(sys.argv[2], sys.argv[3])
    elif sys.argv[1] == "retry":
        ok = may_retry_transport(Path(sys.argv[2]).read_text(errors="replace"))
    else:
        raise SystemExit("Use ready URL TARGET or retry LOG")
    raise SystemExit(0 if ok else 1)
