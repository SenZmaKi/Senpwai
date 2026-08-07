#!/usr/bin/env python3
"""Compare Cloudflare responses across curl, curl-cffi, and Senpwai's Dio.

Secrets are read from Senpwai's local WebKit/session stores or environment
variables and are never included in probe output.
"""

import argparse
import json
import os
import struct
import subprocess
import sys
import tempfile
import time
from pathlib import Path
from urllib.parse import urlparse


DEFAULT_CONTAINER = (
    Path.home()
    / "Library/Containers/com.example.senpwai/Data/Library"
)
DEFAULT_COOKIE_STORE = DEFAULT_CONTAINER / "Cookies/Cookies.binarycookies"
DEFAULT_SESSIONS_FILE = (
    DEFAULT_CONTAINER
    / "Application Support/com.example.senpwai/SenpwaiData/network/cf_sessions.json"
)
MAC_EPOCH_UNIX_OFFSET = 978_307_200
CHALLENGE_MARKERS = (
    "just a moment",
    "performing security verification",
    "challenge-platform",
    "cf_chl_",
)


def parse_args():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("url", help="Protected URL to probe")
    parser.add_argument(
        "--cookie-store",
        type=Path,
        default=DEFAULT_COOKIE_STORE,
        help="WebKit Cookies.binarycookies path",
    )
    parser.add_argument(
        "--sessions-file",
        type=Path,
        default=DEFAULT_SESSIONS_FILE,
        help="Senpwai cf_sessions.json path",
    )
    parser.add_argument(
        "--dart-probe",
        type=Path,
        default=Path(__file__).with_name("cloudflare_dio_probe.dart"),
        help="Dart probe entrypoint",
    )
    parser.add_argument("--timeout", type=int, default=45)
    parser.add_argument("--skip-curl-cffi", action="store_true")
    parser.add_argument("--skip-dio", action="store_true")
    return parser.parse_args()


def emit(payload):
    print(json.dumps(payload, sort_keys=True), flush=True)


def domain_matches(host, cookie_domain):
    domain = cookie_domain.lstrip(".").lower()
    host = host.lower()
    return host == domain or host.endswith(f".{domain}")


def binary_cookies(path):
    data = path.read_bytes()
    if data[:4] != b"cook":
        raise RuntimeError("Unsupported WebKit cookie store")
    page_count = struct.unpack(">I", data[4:8])[0]
    page_sizes = [
        struct.unpack(">I", data[8 + index * 4 : 12 + index * 4])[0]
        for index in range(page_count)
    ]
    cursor = 8 + page_count * 4
    for page_size in page_sizes:
        page = data[cursor : cursor + page_size]
        cursor += page_size
        cookie_count = struct.unpack("<I", page[4:8])[0]
        offsets = [
            struct.unpack("<I", page[8 + index * 4 : 12 + index * 4])[0]
            for index in range(cookie_count)
        ]
        for offset in offsets:
            raw_cookie = page[offset:]
            size = struct.unpack("<I", raw_cookie[:4])[0]
            raw_cookie = raw_cookie[:size]
            url_offset, name_offset, path_offset, value_offset = struct.unpack(
                "<IIII", raw_cookie[16:32]
            )

            def read_string(start):
                end = raw_cookie.find(b"\0", start)
                return raw_cookie[start:end].decode("utf-8")

            expires = struct.unpack("<d", raw_cookie[40:48])[0]
            created = struct.unpack("<d", raw_cookie[48:56])[0]
            yield {
                "domain": read_string(url_offset),
                "name": read_string(name_offset),
                "path": read_string(path_offset),
                "value": read_string(value_offset),
                "expires": expires + MAC_EPOCH_UNIX_OFFSET if expires else None,
                "created": created + MAC_EPOCH_UNIX_OFFSET,
            }


def usable_cookies(cookies, host, request_path):
    now = time.time()
    matching = [
        cookie
        for cookie in cookies
        if domain_matches(host, cookie["domain"])
        and request_path.startswith(cookie["path"] or "/")
        and (cookie["expires"] is None or cookie["expires"] > now)
        and cookie["name"]
        and cookie["value"]
    ]
    newest_by_name = {}
    for cookie in sorted(matching, key=lambda item: item["created"]):
        newest_by_name[cookie["name"]] = cookie
    return list(newest_by_name.values())


def session_profiles(path):
    if not path.exists():
        return []
    decoded = json.loads(path.read_text())
    profiles = []
    for host, host_data in decoded.get("hosts", {}).items():
        for profile in host_data.get("profiles", {}).values():
            profiles.append({"host": host, **profile})
    return profiles


def credentials(args, host, request_path):
    explicit_cookie = os.environ.get("CF_PROBE_COOKIE")
    explicit_user_agent = os.environ.get("CF_PROBE_UA")
    profiles = session_profiles(args.sessions_file)

    cookie_source = "environment"
    cookie_header = explicit_cookie
    if not cookie_header:
        webkit = (
            usable_cookies(binary_cookies(args.cookie_store), host, request_path)
            if args.cookie_store.exists()
            else []
        )
        if webkit:
            cookie_header = "; ".join(
                f'{cookie["name"]}={cookie["value"]}' for cookie in webkit
            )
            cookie_source = "webkit"
        else:
            host_profiles = [
                profile
                for profile in profiles
                if profile["host"].lower() == host.lower()
            ]
            host_profiles.sort(key=lambda profile: profile.get("savedAt", ""))
            if host_profiles:
                cookies = host_profiles[-1].get("cookies", [])
                cookie_header = "; ".join(
                    f'{cookie["name"]}={cookie["value"]}'
                    for cookie in cookies
                    if cookie.get("name") and cookie.get("value")
                )
                cookie_source = "session-profile"
    if not cookie_header:
        raise RuntimeError(
            f"No cookies found for {host}; set CF_PROBE_COOKIE explicitly"
        )

    user_agent_source = "environment"
    user_agent = explicit_user_agent
    if not user_agent:
        profiles_with_ua = [
            profile for profile in profiles if profile.get("userAgent")
        ]
        exact_profiles = [
            profile
            for profile in profiles_with_ua
            if profile["host"].lower() == host.lower()
        ]
        candidates = exact_profiles or profiles_with_ua
        candidates.sort(key=lambda profile: profile.get("savedAt", ""))
        if candidates:
            user_agent = candidates[-1]["userAgent"]
            user_agent_source = (
                "matching-session-profile"
                if exact_profiles
                else "latest-webview-session-fallback"
            )
    if not user_agent:
        raise RuntimeError(
            "No WebView User-Agent found; set CF_PROBE_UA explicitly"
        )

    return cookie_header, user_agent, cookie_source, user_agent_source


def response_summary(label, status, protocol, elapsed, headers, body):
    headers = {str(key).lower(): str(value) for key, value in headers.items()}
    body_lower = body.lower()
    emit(
        {
            "probe": label,
            "status": status,
            "protocol": protocol,
            "elapsedMs": round(elapsed * 1000),
            "server": headers.get("server"),
            "cfMitigated": headers.get("cf-mitigated"),
            "contentType": headers.get("content-type"),
            "bodyBytes": len(body.encode("utf-8")),
            "challengeMarkers": [
                marker for marker in CHALLENGE_MARKERS if marker in body_lower
            ],
        }
    )


def parse_last_header_block(raw_headers):
    normalized = raw_headers.replace("\r\n", "\n")
    blocks = [block for block in normalized.split("\n\n") if block.strip()]
    block = blocks[-1] if blocks else ""
    headers = {}
    for line in block.splitlines()[1:]:
        if ":" in line:
            name, value = line.split(":", 1)
            headers[name.strip()] = value.strip()
    return headers


def native_curl(args, cookie, user_agent):
    with tempfile.TemporaryDirectory(prefix="senpwai-cf-curl-") as temp_dir:
        headers_path = Path(temp_dir) / "headers"
        body_path = Path(temp_dir) / "body"
        config_path = Path(temp_dir) / "credentials.conf"
        config_path.write_text(
            f'user-agent = "{curl_config_value(user_agent)}"\n'
            f'header = "Cookie: {curl_config_value(cookie)}"\n'
        )
        config_path.chmod(0o600)
        command = [
            "curl",
            "--config",
            str(config_path),
            "--silent",
            "--show-error",
            "--location",
            "--max-time",
            str(args.timeout),
            "--dump-header",
            str(headers_path),
            "--output",
            str(body_path),
            "--write-out",
            "%{http_code} %{http_version} %{time_total}",
            args.url,
        ]
        started = time.monotonic()
        result = subprocess.run(command, capture_output=True, text=True)
        elapsed = time.monotonic() - started
        fields = result.stdout.strip().split()
        body = body_path.read_text(errors="replace") if body_path.exists() else ""
        headers = (
            parse_last_header_block(headers_path.read_text(errors="replace"))
            if headers_path.exists()
            else {}
        )
        response_summary(
            "curl",
            int(fields[0]) if fields else 0,
            fields[1] if len(fields) > 1 else None,
            elapsed,
            headers,
            body,
        )
        if result.returncode:
            emit(
                {
                    "probe": "curl",
                    "exitCode": result.returncode,
                    "error": result.stderr.strip(),
                }
            )


def curl_config_value(value):
    if "\n" in value or "\r" in value:
        raise RuntimeError("Credential contains an unsupported newline")
    return value.replace("\\", "\\\\").replace('"', '\\"')


def curl_cffi_probe(args, cookie, user_agent):
    try:
        from curl_cffi import requests
        from curl_cffi.requests.impersonate import BrowserTypeLiteral
    except ImportError:
        emit(
            {
                "probe": "curl-cffi",
                "skipped": True,
                "reason": "Install curl-cffi in the active Python environment",
            }
        )
        return

    chrome_profiles = sorted(
        (
            profile
            for profile in BrowserTypeLiteral.__args__
            if profile.startswith("chrome") and profile[6:].isdigit()
        ),
        key=lambda profile: int(profile[6:]),
    )
    impersonate = chrome_profiles[-1]
    started = time.monotonic()
    response = requests.get(
        args.url,
        headers={"User-Agent": user_agent, "Cookie": cookie},
        impersonate=impersonate,
        timeout=args.timeout,
    )
    elapsed = time.monotonic() - started
    response_summary(
        f"curl-cffi:{impersonate}",
        response.status_code,
        str(getattr(response, "http_version", None)),
        elapsed,
        response.headers,
        response.text,
    )


def dart_probe(args, cookie, user_agent):
    environment = os.environ.copy()
    environment.update(
        {
            "CF_PROBE_URL": args.url,
            "CF_PROBE_COOKIE": cookie,
            "CF_PROBE_UA": user_agent,
            "CF_PROBE_TIMEOUT_SECONDS": str(args.timeout),
        }
    )
    result = subprocess.run(
        ["dart", "run", str(args.dart_probe)],
        env=environment,
        capture_output=True,
        text=True,
    )
    if result.stdout.strip():
        print(result.stdout.strip(), flush=True)
    if result.returncode:
        emit(
            {
                "probe": "dio-http2-preferred",
                "exitCode": result.returncode,
                "error": result.stderr.strip(),
            }
        )


def main():
    args = parse_args()
    parsed_url = urlparse(args.url)
    if parsed_url.scheme not in ("http", "https") or not parsed_url.hostname:
        raise SystemExit("URL must be an absolute HTTP(S) URL")

    try:
        cookie, user_agent, cookie_source, user_agent_source = credentials(
            args, parsed_url.hostname, parsed_url.path or "/"
        )
    except (OSError, ValueError, RuntimeError) as error:
        emit({"credentialError": str(error), "secretsPrinted": False})
        raise SystemExit(2) from error

    emit(
        {
            "target": args.url,
            "credentials": {
                "cookieSource": cookie_source,
                "userAgentSource": user_agent_source,
                "secretsPrinted": False,
            },
        }
    )
    try:
        native_curl(args, cookie, user_agent)
    except Exception as error:  # Keep the remaining transports diagnostic.
        emit(
            {
                "probe": "curl",
                "errorType": type(error).__name__,
                "error": str(error),
            }
        )
    if not args.skip_curl_cffi:
        try:
            curl_cffi_probe(args, cookie, user_agent)
        except Exception as error:
            emit(
                {
                    "probe": "curl-cffi",
                    "errorType": type(error).__name__,
                    "error": str(error),
                }
            )
    if not args.skip_dio:
        try:
            dart_probe(args, cookie, user_agent)
        except Exception as error:
            emit(
                {
                    "probe": "dio-http2-preferred",
                    "errorType": type(error).__name__,
                    "error": str(error),
                }
            )


if __name__ == "__main__":
    main()
