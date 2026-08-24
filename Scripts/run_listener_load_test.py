#!/usr/bin/env python3
"""Load-test the local listener server without exposing listener credentials.

The harness uses only Python's standard library. Each simulated listener is
bound to a different 127.0.0.x source address, so the server exercises its
normal client-bound pairing grants instead of sharing one grant between all
connections.
"""

import argparse
import asyncio
import base64
import collections
import hashlib
import json
import math
import os
import re
import secrets
import signal
import socket
import struct
import subprocess
import sys
import time
import uuid
from dataclasses import dataclass, field
from typing import Dict, Iterable, List, Optional, Set, Tuple
from urllib.parse import urlsplit


INVITE_ENVIRONMENT_VARIABLE = "LCT_LISTENER_INVITE_URL"
INVITE_PATTERN = re.compile(
    r"invite=([0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-"
    r"[0-9a-fA-F]{4}-[0-9a-fA-F]{12})\.([A-Za-z0-9_-]{43})"
)
GRANT_PATTERN = re.compile(r"[A-Za-z0-9_-]{43}")
KNOWN_ENVELOPE_TYPES = {
    "snapshot",
    "entryUpsert",
    "stateChanged",
    "resyncRequired",
    "heartbeat",
}
COLD_START_ASSETS = (
    ("/", "text/html", (b"/reader.css", b"/reader.js")),
    ("/reader.css", "text/css", ()),
    ("/reader.js", "text/javascript", ()),
)
MAX_HTTP_HEADER_BYTES = 64 * 1024
MAX_HTTP_BODY_BYTES = 4 * 1024 * 1024
MAX_WEBSOCKET_PAYLOAD_BYTES = 4 * 1024 * 1024


class LoadTestError(Exception):
    """A deliberately credential-free load-test failure."""


class SafeArgumentParser(argparse.ArgumentParser):
    """Avoid echoing a mistyped invitation URL in command-line errors."""

    def error(self, message: str) -> None:
        del message
        self.print_usage(sys.stderr)
        self.exit(2, f"{self.prog}: error: invalid command-line arguments\n")


@dataclass(frozen=True)
class Invitation:
    invitation_id: str = field(repr=False)
    fragment_credential: str = field(repr=False)
    port: int


@dataclass(frozen=True)
class Configuration:
    invitation: Invitation = field(repr=False)
    client_count: int
    duration: float
    reconnect_count: int
    reconnect_after: Optional[float]
    connect_timeout: float
    required_events: Set[str]
    allow_resync: bool
    cold_start_assets: bool
    manage_loopback_aliases: bool


@dataclass
class HTTPResponse:
    status: int
    headers: Dict[str, List[str]] = field(repr=False)
    body: bytes = field(repr=False)


def parse_arguments(argv: Optional[List[str]] = None) -> argparse.Namespace:
    parser = SafeArgumentParser(
        description=(
            "Exercise pairing, authenticated snapshots, and persistent WebSockets "
            "for independent local listener clients. Credentials and transcript "
            "content are never printed."
        ),
        formatter_class=argparse.ArgumentDefaultsHelpFormatter,
    )
    parser.add_argument(
        "--invite-url",
        metavar="URL",
        help=(
            "listener invitation URL; prefer the "
            f"{INVITE_ENVIRONMENT_VARIABLE} environment variable so the credential "
            "does not appear in the process list"
        ),
    )
    parser.add_argument(
        "--clients",
        type=int,
        default=100,
        help="number of independently paired listeners (1-253)",
    )
    parser.add_argument(
        "--duration",
        type=float,
        default=60.0,
        help="steady-state WebSocket test duration in seconds",
    )
    parser.add_argument(
        "--reconnect-count",
        type=int,
        default=0,
        help="number of listeners to close cleanly and reconnect during the run",
    )
    parser.add_argument(
        "--reconnect-after",
        type=float,
        help="seconds after steady state begins to perform the reconnect phase",
    )
    parser.add_argument(
        "--connect-timeout",
        type=float,
        default=10.0,
        help="timeout for each network operation in seconds",
    )
    parser.add_argument(
        "--require-event",
        action="append",
        choices=sorted(KNOWN_ENVELOPE_TYPES - {"snapshot"}),
        default=[],
        help=(
            "event every listener must receive; may be repeated (for a live media "
            "test, add: --require-event entryUpsert)"
        ),
    )
    parser.add_argument(
        "--no-require-heartbeat",
        action="store_true",
        help="do not require every listener to receive a server heartbeat",
    )
    parser.add_argument(
        "--allow-resync",
        action="store_true",
        help="do not fail when the server reports a dropped-event resynchronization",
    )
    parser.add_argument(
        "--skip-cold-start-assets",
        action="store_true",
        help=(
            "skip the default browser cold-start burst of /, /reader.css, and "
            "/reader.js before pairing"
        ),
    )
    parser.add_argument(
        "--manage-loopback-aliases",
        action="store_true",
        help=(
            "create missing 127.0.0.x aliases for this run and remove only those "
            "aliases afterward; requires running the harness as root"
        ),
    )
    return parser.parse_args(argv)


def parse_invitation(raw_url: Optional[str]) -> Invitation:
    if not raw_url:
        raise LoadTestError(
            f"provide --invite-url or set {INVITE_ENVIRONMENT_VARIABLE}"
        )
    try:
        parsed = urlsplit(raw_url)
        port = parsed.port
    except ValueError as error:
        raise LoadTestError("the invitation URL is malformed") from error
    if (
        parsed.scheme.lower() != "http"
        or parsed.username is not None
        or parsed.password is not None
        or parsed.hostname is None
        or parsed.query
        or parsed.path not in ("", "/")
        or port is None
        or not (1 <= port <= 65_535)
    ):
        raise LoadTestError("the invitation must be an HTTP root URL with an explicit port")
    match = INVITE_PATTERN.fullmatch(parsed.fragment)
    if match is None:
        raise LoadTestError("the invitation URL has an invalid fragment")
    try:
        canonical_id = str(uuid.UUID(match.group(1)))
    except ValueError as error:
        raise LoadTestError("the invitation identifier is invalid") from error
    return Invitation(
        invitation_id=canonical_id,
        fragment_credential=match.group(2),
        port=port,
    )


def make_configuration(arguments: argparse.Namespace) -> Configuration:
    raw_invitation = arguments.invite_url or os.environ.get(
        INVITE_ENVIRONMENT_VARIABLE
    )
    invitation = parse_invitation(raw_invitation)
    if not (1 <= arguments.clients <= 253):
        raise LoadTestError("--clients must be between 1 and 253")
    if not math.isfinite(arguments.duration) or arguments.duration < 5:
        raise LoadTestError("--duration must be at least 5 seconds")
    if not math.isfinite(arguments.connect_timeout) or arguments.connect_timeout <= 0:
        raise LoadTestError("--connect-timeout must be positive")
    if not (0 <= arguments.reconnect_count <= arguments.clients):
        raise LoadTestError("--reconnect-count must be between zero and --clients")
    reconnect_after = arguments.reconnect_after
    if arguments.reconnect_count:
        if reconnect_after is None:
            reconnect_after = arguments.duration / 2
        if not math.isfinite(reconnect_after) or not (
            0 < reconnect_after < arguments.duration
        ):
            raise LoadTestError(
                "--reconnect-after must fall inside the steady-state duration"
            )
    elif reconnect_after is not None:
        raise LoadTestError("--reconnect-after requires --reconnect-count")
    required_events = set(arguments.require_event)
    if not arguments.no_require_heartbeat:
        required_events.add("heartbeat")
    if "heartbeat" in required_events and arguments.duration < 12:
        raise LoadTestError(
            "heartbeat validation requires --duration of at least 12 seconds"
        )
    return Configuration(
        invitation=invitation,
        client_count=arguments.clients,
        duration=arguments.duration,
        reconnect_count=arguments.reconnect_count,
        reconnect_after=reconnect_after,
        connect_timeout=arguments.connect_timeout,
        required_events=required_events,
        allow_resync=arguments.allow_resync,
        cold_start_assets=not arguments.skip_cold_start_assets,
        manage_loopback_aliases=arguments.manage_loopback_aliases,
    )


class LoopbackAliasManager:
    def __init__(self, configuration: Configuration) -> None:
        self.configuration = configuration
        self.created: List[str] = []

    @property
    def required(self) -> List[str]:
        return [
            f"127.0.0.{index + 1}"
            for index in range(1, self.configuration.client_count + 1)
        ]

    def prepare(self) -> None:
        try:
            result = subprocess.run(
                ["/sbin/ifconfig", "lo0"],
                check=True,
                capture_output=True,
                text=True,
            )
        except (OSError, subprocess.CalledProcessError) as error:
            raise LoadTestError("could not inspect the loopback interface") from error
        assigned = set(
            re.findall(r"^\s*inet\s+(127\.[0-9]+\.[0-9]+\.[0-9]+)\b", result.stdout, re.M)
        )
        missing = [address for address in self.required if address not in assigned]
        if not missing:
            return
        if not self.configuration.manage_loopback_aliases:
            raise LoadTestError(
                "required loopback aliases are missing; rerun as root with "
                "--manage-loopback-aliases"
            )
        if os.geteuid() != 0:
            raise LoadTestError("--manage-loopback-aliases requires root privileges")
        try:
            for address in missing:
                subprocess.run(
                    [
                        "/sbin/ifconfig",
                        "lo0",
                        "alias",
                        address,
                        "netmask",
                        "255.255.255.255",
                    ],
                    check=True,
                    stdout=subprocess.DEVNULL,
                    stderr=subprocess.DEVNULL,
                )
                self.created.append(address)
        except (OSError, subprocess.CalledProcessError) as error:
            raise LoadTestError("could not create the required loopback aliases") from error

    def cleanup(self) -> Optional[LoadTestError]:
        failed = False
        for address in reversed(self.created):
            try:
                subprocess.run(
                    ["/sbin/ifconfig", "lo0", "-alias", address],
                    check=True,
                    stdout=subprocess.DEVNULL,
                    stderr=subprocess.DEVNULL,
                )
            except (OSError, subprocess.CalledProcessError):
                failed = True
        self.created.clear()
        if failed:
            return LoadTestError("one or more temporary loopback aliases could not be removed")
        return None


def credential_free_error(error: BaseException) -> str:
    if isinstance(error, LoadTestError):
        return str(error)
    if isinstance(error, asyncio.TimeoutError):
        return "network operation timed out"
    if isinstance(error, asyncio.IncompleteReadError):
        return "the connection closed prematurely"
    if isinstance(error, json.JSONDecodeError):
        return "the server returned invalid JSON"
    if isinstance(error, UnicodeError):
        return "the server returned invalid UTF-8"
    if isinstance(error, OSError):
        return f"network error (errno {error.errno})"
    return type(error).__name__


async def close_writer(writer: asyncio.StreamWriter) -> None:
    writer.close()
    try:
        await writer.wait_closed()
    except (ConnectionError, OSError):
        pass


async def open_bound_connection(
    source_ip: str, port: int, timeout: float
) -> Tuple[asyncio.StreamReader, asyncio.StreamWriter]:
    try:
        return await asyncio.wait_for(
            asyncio.open_connection(
                "127.0.0.1",
                port,
                local_addr=(source_ip, 0),
                family=socket.AF_INET,
                limit=MAX_WEBSOCKET_PAYLOAD_BYTES + MAX_HTTP_HEADER_BYTES,
            ),
            timeout=timeout,
        )
    except asyncio.TimeoutError as error:
        raise LoadTestError("connection timed out") from error
    except OSError as error:
        raise LoadTestError(
            f"loopback connection failed (errno {error.errno})"
        ) from error


async def read_http_response(
    reader: asyncio.StreamReader, timeout: float
) -> HTTPResponse:
    try:
        head = await asyncio.wait_for(reader.readuntil(b"\r\n\r\n"), timeout)
    except asyncio.LimitOverrunError as error:
        raise LoadTestError("HTTP response headers exceeded the safety limit") from error
    if len(head) > MAX_HTTP_HEADER_BYTES:
        raise LoadTestError("HTTP response headers exceeded the safety limit")
    try:
        lines = head[:-4].decode("ascii").split("\r\n")
    except UnicodeDecodeError as error:
        raise LoadTestError("HTTP response headers were not ASCII") from error
    if not lines or not re.fullmatch(r"HTTP/1\.[01] [0-9]{3}(?: .*)?", lines[0]):
        raise LoadTestError("HTTP response status line was invalid")
    status = int(lines[0].split(" ", 2)[1])
    headers: Dict[str, List[str]] = collections.defaultdict(list)
    for line in lines[1:]:
        if not line or ":" not in line:
            raise LoadTestError("HTTP response contained an invalid header")
        name, value = line.split(":", 1)
        normalized_name = name.strip().lower()
        if not normalized_name or any(character.isspace() for character in normalized_name):
            raise LoadTestError("HTTP response contained an invalid header name")
        headers[normalized_name].append(value.strip())
    content_lengths = headers.get("content-length", [])
    if len(content_lengths) > 1:
        raise LoadTestError("HTTP response contained duplicate content lengths")
    if content_lengths:
        try:
            body_length = int(content_lengths[0])
        except ValueError as error:
            raise LoadTestError("HTTP response content length was invalid") from error
    else:
        body_length = 0
    if not (0 <= body_length <= MAX_HTTP_BODY_BYTES):
        raise LoadTestError("HTTP response body exceeded the safety limit")
    body = await asyncio.wait_for(reader.readexactly(body_length), timeout)
    return HTTPResponse(status=status, headers=dict(headers), body=body)


def parse_json_object(data: bytes, context: str) -> Dict[str, object]:
    try:
        value = json.loads(data.decode("utf-8"))
    except (UnicodeDecodeError, json.JSONDecodeError) as error:
        raise LoadTestError(f"{context} was not valid JSON") from error
    if not isinstance(value, dict):
        raise LoadTestError(f"{context} was not a JSON object")
    return value


def validate_snapshot(value: Dict[str, object], context: str) -> int:
    revision = value.get("revision")
    if isinstance(revision, bool) or not isinstance(revision, int) or revision < 0:
        raise LoadTestError(f"{context} had an invalid revision")
    if not isinstance(value.get("entries"), list) or not isinstance(value.get("phase"), str):
        raise LoadTestError(f"{context} had an invalid shape")
    return revision


def validate_uuid_string(value: object, context: str) -> None:
    try:
        if not isinstance(value, str):
            raise ValueError
        uuid.UUID(value)
    except ValueError as error:
        raise LoadTestError(f"{context} was invalid") from error


def encode_client_frame(opcode: int, payload: bytes = b"") -> bytes:
    if opcode >= 0x8 and len(payload) > 125:
        raise LoadTestError("attempted to send an oversized WebSocket control frame")
    mask = secrets.token_bytes(4)
    length = len(payload)
    result = bytearray([0x80 | opcode])
    if length <= 125:
        result.append(0x80 | length)
    elif length <= 65_535:
        result.append(0x80 | 126)
        result.extend(struct.pack("!H", length))
    else:
        result.append(0x80 | 127)
        result.extend(struct.pack("!Q", length))
    result.extend(mask)
    result.extend(byte ^ mask[index % 4] for index, byte in enumerate(payload))
    return bytes(result)


async def read_websocket_frame(
    reader: asyncio.StreamReader,
) -> Tuple[int, bytes]:
    header = await reader.readexactly(2)
    first, second = header
    if first & 0x80 == 0 or first & 0x70 != 0:
        raise LoadTestError("the server sent a fragmented or reserved WebSocket frame")
    opcode = first & 0x0F
    if opcode not in (0x1, 0x8, 0x9, 0xA):
        raise LoadTestError("the server sent an unsupported WebSocket opcode")
    if second & 0x80:
        raise LoadTestError("the server incorrectly masked a WebSocket frame")
    marker = second & 0x7F
    if marker <= 125:
        length = marker
    elif marker == 126:
        length = struct.unpack("!H", await reader.readexactly(2))[0]
        if length < 126:
            raise LoadTestError("the server used a non-canonical WebSocket length")
    else:
        length = struct.unpack("!Q", await reader.readexactly(8))[0]
        if length <= 65_535 or length & (1 << 63):
            raise LoadTestError("the server used an invalid WebSocket length")
    if length > MAX_WEBSOCKET_PAYLOAD_BYTES:
        raise LoadTestError("a WebSocket frame exceeded the safety limit")
    if opcode >= 0x8 and length > 125:
        raise LoadTestError("the server sent an oversized WebSocket control frame")
    return opcode, await reader.readexactly(length)


def close_code(payload: bytes) -> Optional[int]:
    if not payload:
        return None
    if len(payload) == 1:
        raise LoadTestError("the server sent an invalid WebSocket close frame")
    code = struct.unpack("!H", payload[:2])[0]
    try:
        payload[2:].decode("utf-8")
    except UnicodeDecodeError as error:
        raise LoadTestError("the server sent an invalid WebSocket close reason") from error
    is_protocol_code = 1000 <= code <= 1014 and code not in (1004, 1005, 1006)
    if not is_protocol_code and not (3000 <= code <= 4999):
        raise LoadTestError("the server sent an invalid WebSocket close code")
    return code


class WebSocketConnection:
    def __init__(
        self,
        client: "ListenerClient",
        reader: asyncio.StreamReader,
        writer: asyncio.StreamWriter,
    ) -> None:
        self.client = client
        self.reader = reader
        self.writer = writer
        self.expected_close = False
        self.close_received = False
        self.closed = asyncio.Event()
        self.initial_snapshot = asyncio.Event()
        self.pending_pongs: Dict[bytes, asyncio.Future] = {}
        self.send_lock = asyncio.Lock()
        self.receiver_task = asyncio.create_task(self.receive(), name=f"listener-{client.index}")

    async def send(self, opcode: int, payload: bytes = b"") -> None:
        async with self.send_lock:
            self.writer.write(encode_client_frame(opcode, payload))
            await self.writer.drain()

    async def probe(self, timeout: float) -> None:
        payload = secrets.token_bytes(12)
        future = asyncio.get_running_loop().create_future()
        self.pending_pongs[payload] = future
        try:
            await self.send(0x9, payload)
            await asyncio.wait_for(asyncio.shield(future), timeout)
        except asyncio.TimeoutError as error:
            raise LoadTestError("WebSocket ping was not acknowledged") from error
        finally:
            self.pending_pongs.pop(payload, None)

    async def receive(self) -> None:
        try:
            while True:
                opcode, payload = await read_websocket_frame(self.reader)
                if opcode == 0x1:
                    await self.client.record_envelope(payload, self.initial_snapshot)
                elif opcode == 0x8:
                    code = close_code(payload)
                    self.close_received = True
                    self.client.close_codes[code] += 1
                    if not self.expected_close:
                        self.client.record_failure(
                            f"server closed WebSocket unexpectedly (code {code})"
                        )
                    return
                elif opcode == 0x9:
                    self.client.server_pings += 1
                    await self.send(0xA, payload)
                elif opcode == 0xA:
                    self.client.pongs += 1
                    future = self.pending_pongs.get(payload)
                    if future is not None and not future.done():
                        future.set_result(None)
        except asyncio.CancelledError:
            raise
        except (ConnectionError, OSError, asyncio.IncompleteReadError) as error:
            if not self.expected_close:
                self.client.record_failure(credential_free_error(error))
        except BaseException as error:
            self.client.record_failure(credential_free_error(error))
        finally:
            self.closed.set()
            for future in self.pending_pongs.values():
                if not future.done():
                    future.cancel()

    async def close(self, timeout: float, require_handshake: bool) -> None:
        self.expected_close = True
        if not self.writer.is_closing():
            try:
                await self.send(0x8, struct.pack("!H", 1000))
                await asyncio.wait_for(self.closed.wait(), timeout)
            except (ConnectionError, OSError, asyncio.TimeoutError):
                pass
        await close_writer(self.writer)
        if not self.receiver_task.done():
            self.receiver_task.cancel()
        await asyncio.gather(self.receiver_task, return_exceptions=True)
        if require_handshake and not self.close_received:
            raise LoadTestError("server did not complete the WebSocket close handshake")

    async def abort(self) -> None:
        self.expected_close = True
        if not self.receiver_task.done():
            self.receiver_task.cancel()
        await close_writer(self.writer)
        await asyncio.gather(self.receiver_task, return_exceptions=True)


class ListenerClient:
    def __init__(self, index: int, configuration: Configuration) -> None:
        self.index = index
        self.source_ip = f"127.0.0.{index + 1}"
        self.configuration = configuration
        self.cookie: Optional[str] = None
        self.connection: Optional[WebSocketConnection] = None
        self.failures: List[str] = []
        self.event_counts: collections.Counter = collections.Counter()
        self.entry_fingerprints: List[str] = []
        self.revisions: Set[int] = set()
        self.last_revision: Optional[int] = None
        self.http_snapshots = 0
        self.asset_responses = 0
        self.websocket_connections = 0
        self.expected_snapshots = 0
        self.pongs = 0
        self.server_pings = 0
        self.close_codes: collections.Counter = collections.Counter()

    @property
    def host_header(self) -> str:
        return f"localhost:{self.configuration.invitation.port}"

    @property
    def origin(self) -> str:
        return f"http://{self.host_header}"

    def record_failure(self, message: str) -> None:
        if message not in self.failures:
            self.failures.append(message)

    async def request(self, request: bytes) -> HTTPResponse:
        reader, writer = await open_bound_connection(
            self.source_ip,
            self.configuration.invitation.port,
            self.configuration.connect_timeout,
        )
        try:
            writer.write(request)
            await asyncio.wait_for(writer.drain(), self.configuration.connect_timeout)
            return await read_http_response(
                reader, self.configuration.connect_timeout
            )
        finally:
            await close_writer(writer)

    async def pair(self) -> None:
        invitation = self.configuration.invitation
        body = json.dumps(
            {
                "invitationID": invitation.invitation_id,
                "fragmentCredential": invitation.fragment_credential,
                "peerMetadata": {
                    "displayName": f"Load listener {self.index:03d}",
                    "userAgentSummary": "Listener load-test harness",
                },
            },
            separators=(",", ":"),
        ).encode("utf-8")
        request = (
            f"POST /api/pair HTTP/1.1\r\n"
            f"Host: {self.host_header}\r\n"
            f"Origin: {self.origin}\r\n"
            "Content-Type: application/json\r\n"
            f"Content-Length: {len(body)}\r\n"
            "Connection: close\r\n\r\n"
        ).encode("ascii") + body
        response = await self.request(request)
        if response.status != 200:
            raise LoadTestError(f"pairing returned HTTP {response.status}")
        pair_result = parse_json_object(response.body, "pairing response")
        if pair_result.get("role") != "viewer":
            raise LoadTestError("pairing did not grant the viewer role")
        cookies = response.headers.get("set-cookie", [])
        if len(cookies) != 1:
            raise LoadTestError("pairing did not return exactly one grant cookie")
        first_field = cookies[0].split(";", 1)[0]
        name, separator, value = first_field.partition("=")
        if separator != "=" or name != "church_remote" or not GRANT_PATTERN.fullmatch(value):
            raise LoadTestError("pairing returned an invalid grant cookie")
        cookie_attributes = {
            attribute.strip().lower() for attribute in cookies[0].split(";")[1:]
        }
        if not {"path=/", "httponly", "samesite=strict"}.issubset(
            cookie_attributes
        ):
            raise LoadTestError("pairing grant cookie omitted a security attribute")
        self.cookie = f"church_remote={value}"

    async def fetch_cold_start_assets(self) -> None:
        async def fetch(
            path: str, expected_type: str, required_markers: Tuple[bytes, ...]
        ) -> None:
            request = (
                f"GET {path} HTTP/1.1\r\n"
                f"Host: {self.host_header}\r\n"
                "Connection: close\r\n\r\n"
            ).encode("ascii")
            response = await self.request(request)
            if response.status != 200:
                raise LoadTestError(
                    f"cold-start asset returned HTTP {response.status}"
                )
            content_types = response.headers.get("content-type", [])
            if len(content_types) != 1 or not content_types[0].lower().startswith(
                expected_type
            ):
                raise LoadTestError("cold-start asset had an invalid content type")
            if not response.body or any(
                marker not in response.body for marker in required_markers
            ):
                raise LoadTestError("cold-start asset body was invalid")
            self.asset_responses += 1

        await asyncio.gather(
            *(
                fetch(path, expected_type, required_markers)
                for path, expected_type, required_markers in COLD_START_ASSETS
            )
        )

    async def fetch_snapshot(self) -> None:
        if self.cookie is None:
            raise LoadTestError("snapshot requested before pairing")
        request = (
            f"GET /api/snapshot HTTP/1.1\r\n"
            f"Host: {self.host_header}\r\n"
            f"Cookie: {self.cookie}\r\n"
            "Connection: close\r\n\r\n"
        ).encode("ascii")
        response = await self.request(request)
        if response.status != 200:
            raise LoadTestError(f"snapshot returned HTTP {response.status}")
        if response.headers.get("x-remote-role") != ["viewer"]:
            raise LoadTestError("snapshot response did not confirm the viewer role")
        snapshot = parse_json_object(response.body, "snapshot response")
        revision = validate_snapshot(snapshot, "snapshot response")
        self.revisions.add(revision)
        self.http_snapshots += 1

    async def open_websocket(self) -> None:
        if self.cookie is None:
            raise LoadTestError("WebSocket requested before pairing")
        reader, writer = await open_bound_connection(
            self.source_ip,
            self.configuration.invitation.port,
            self.configuration.connect_timeout,
        )
        key = base64.b64encode(secrets.token_bytes(16)).decode("ascii")
        request = (
            "GET /ws HTTP/1.1\r\n"
            f"Host: {self.host_header}\r\n"
            f"Origin: {self.origin}\r\n"
            f"Cookie: {self.cookie}\r\n"
            "Upgrade: websocket\r\n"
            "Connection: Upgrade\r\n"
            f"Sec-WebSocket-Key: {key}\r\n"
            "Sec-WebSocket-Version: 13\r\n\r\n"
        ).encode("ascii")
        try:
            writer.write(request)
            await asyncio.wait_for(writer.drain(), self.configuration.connect_timeout)
            response = await read_http_response(
                reader, self.configuration.connect_timeout
            )
            if response.status != 101:
                raise LoadTestError(
                    f"WebSocket upgrade returned HTTP {response.status}"
                )
            expected_accept = base64.b64encode(
                hashlib.sha1(
                    (key + "258EAFA5-E914-47DA-95CA-C5AB0DC85B11").encode("ascii")
                ).digest()
            ).decode("ascii")
            accepts = response.headers.get("sec-websocket-accept", [])
            if accepts != [expected_accept]:
                raise LoadTestError("WebSocket handshake proof was invalid")
            if [value.lower() for value in response.headers.get("upgrade", [])] != [
                "websocket"
            ]:
                raise LoadTestError("WebSocket upgrade header was invalid")
            connection_values = response.headers.get("connection", [])
            if len(connection_values) != 1 or "upgrade" not in {
                token.strip().lower() for token in connection_values[0].split(",")
            }:
                raise LoadTestError("WebSocket connection header was invalid")
            connection = WebSocketConnection(self, reader, writer)
            self.connection = connection
            self.websocket_connections += 1
            self.expected_snapshots += 1
            try:
                await asyncio.wait_for(
                    connection.initial_snapshot.wait(),
                    self.configuration.connect_timeout,
                )
            except asyncio.TimeoutError as error:
                raise LoadTestError(
                    "WebSocket did not deliver its initial snapshot"
                ) from error
            if self.failures:
                raise LoadTestError("WebSocket failed during startup")
            await connection.probe(self.configuration.connect_timeout)
        except BaseException:
            if self.connection is None:
                await close_writer(writer)
            raise

    async def record_envelope(
        self, raw_payload: bytes, initial_snapshot: asyncio.Event
    ) -> None:
        envelope = parse_json_object(raw_payload, "WebSocket envelope")
        protocol_version = envelope.get("protocolVersion")
        if isinstance(protocol_version, bool) or protocol_version != 1:
            raise LoadTestError("WebSocket envelope had an unsupported protocol version")
        validate_uuid_string(envelope.get("messageID"), "WebSocket message identifier")
        payload = envelope.get("payload")
        if not isinstance(payload, dict):
            raise LoadTestError("WebSocket envelope payload was invalid")
        event_type = payload.get("type")
        if not isinstance(event_type, str) or event_type not in KNOWN_ENVELOPE_TYPES:
            raise LoadTestError("WebSocket envelope type was invalid")
        if not initial_snapshot.is_set() and event_type != "snapshot":
            raise LoadTestError("the first WebSocket envelope was not a snapshot")
        if event_type == "snapshot":
            snapshot = payload.get("snapshot")
            if not isinstance(snapshot, dict):
                raise LoadTestError("WebSocket snapshot payload was invalid")
            revision = validate_snapshot(snapshot, "WebSocket snapshot")
            initial_snapshot.set()
        elif event_type == "resyncRequired":
            revision = payload.get("latestRevision")
        else:
            revision = payload.get("revision")
        if event_type == "entryUpsert":
            entry = payload.get("entry")
            if not isinstance(entry, dict):
                raise LoadTestError("WebSocket entry payload was invalid")
            validate_uuid_string(payload.get("sessionID"), "WebSocket session identifier")
            validate_uuid_string(entry.get("id"), "WebSocket entry identifier")
            if not isinstance(entry.get("sourceText"), str) or not isinstance(
                entry.get("targetText"), str
            ):
                raise LoadTestError("WebSocket entry text fields were invalid")
            canonical_entry = json.dumps(
                {
                    "sessionID": payload.get("sessionID"),
                    "entry": entry,
                    "revision": revision,
                },
                ensure_ascii=False,
                allow_nan=False,
                sort_keys=True,
                separators=(",", ":"),
            ).encode("utf-8")
            entry_fingerprint = hashlib.sha256(canonical_entry).hexdigest()
        elif event_type == "stateChanged":
            if not isinstance(payload.get("phase"), str) or not isinstance(
                payload.get("message"), str
            ):
                raise LoadTestError("WebSocket state payload was invalid")
            entry_fingerprint = None
        else:
            entry_fingerprint = None
        if isinstance(revision, bool) or not isinstance(revision, int) or revision < 0:
            raise LoadTestError("WebSocket envelope had an invalid revision")
        if self.last_revision is not None and revision < self.last_revision:
            raise LoadTestError("WebSocket revisions moved backwards")
        self.last_revision = revision
        self.revisions.add(revision)
        self.event_counts[event_type] += 1
        if entry_fingerprint is not None:
            self.entry_fingerprints.append(entry_fingerprint)

    async def reconnect(self) -> None:
        await self.close_websocket(require_handshake=True)
        await self.open_websocket()

    async def probe(self) -> None:
        if self.connection is None:
            raise LoadTestError("listener was not connected for its liveness probe")
        await self.connection.probe(self.configuration.connect_timeout)

    async def close_websocket(self, require_handshake: bool = True) -> None:
        connection = self.connection
        self.connection = None
        if connection is not None:
            await connection.close(
                self.configuration.connect_timeout,
                require_handshake=require_handshake,
            )

    async def abort(self) -> None:
        connection = self.connection
        self.connection = None
        if connection is not None:
            await connection.abort()

    def validate(self) -> None:
        expected_assets = len(COLD_START_ASSETS) if self.configuration.cold_start_assets else 0
        if self.asset_responses != expected_assets:
            self.record_failure("cold-start asset response count was incorrect")
        if self.http_snapshots != 1:
            self.record_failure("authenticated HTTP snapshot count was incorrect")
        if self.event_counts["snapshot"] < self.expected_snapshots:
            self.record_failure("one or more WebSocket snapshots were missing")
        if self.pongs < self.websocket_connections + 1:
            self.record_failure("one or more WebSocket liveness probes were missing")
        for event_type in sorted(self.configuration.required_events):
            if self.event_counts[event_type] < 1:
                self.record_failure(f"missing required event: {event_type}")
        if not self.configuration.allow_resync and self.event_counts["resyncRequired"]:
            self.record_failure("server requested resynchronization after an event drop")


async def run_client_phase(
    name: str, clients: Iterable[ListenerClient], operation: str
) -> None:
    selected = list(clients)
    results = await asyncio.gather(
        *(getattr(client, operation)() for client in selected),
        return_exceptions=True,
    )
    failure_count = 0
    for client, result in zip(selected, results):
        if isinstance(result, BaseException):
            client.record_failure(credential_free_error(result))
            failure_count += 1
    if failure_count:
        raise LoadTestError(f"{name} failed for {failure_count} listener(s)")


def first_background_failure(clients: Iterable[ListenerClient]) -> Optional[str]:
    for client in clients:
        if client.failures:
            return f"listener {client.index:03d} failed during steady state"
    return None


def validate_entry_fingerprint_consensus(clients: List[ListenerClient]) -> None:
    sequences = {tuple(client.entry_fingerprints) for client in clients}
    if len(sequences) <= 1:
        return
    for client in clients:
        client.record_failure(
            "ordered entry-update fingerprints differed between listeners"
        )


async def monitor(
    clients: List[ListenerClient], duration: float
) -> None:
    deadline = time.monotonic() + max(0, duration)
    while True:
        failure = first_background_failure(clients)
        if failure:
            raise LoadTestError(failure)
        remaining = deadline - time.monotonic()
        if remaining <= 0:
            return
        await asyncio.sleep(min(0.25, remaining))


async def execute(
    configuration: Configuration, clients: List[ListenerClient]
) -> None:
    closed_cleanly = False
    try:
        if configuration.cold_start_assets:
            await run_client_phase(
                "cold-start asset burst", clients, "fetch_cold_start_assets"
            )
        await run_client_phase("pairing", clients, "pair")
        await asyncio.sleep(0.2)
        await run_client_phase("snapshot", clients, "fetch_snapshot")
        await asyncio.sleep(0.2)
        await run_client_phase("WebSocket connection", clients, "open_websocket")
        print(f"READY listener load test: {len(clients)} listeners connected")
        sys.stdout.flush()

        started = time.monotonic()
        if configuration.reconnect_count:
            assert configuration.reconnect_after is not None
            await monitor(clients, configuration.reconnect_after)
            reconnecting = clients[: configuration.reconnect_count]
            await run_client_phase("reconnect", reconnecting, "reconnect")
        elapsed = time.monotonic() - started
        await monitor(clients, configuration.duration - elapsed)

        await run_client_phase("final liveness probe", clients, "probe")
        validate_entry_fingerprint_consensus(clients)
        for client in clients:
            client.validate()
        failure = first_background_failure(clients)
        if failure:
            raise LoadTestError(failure)
        await run_client_phase("clean WebSocket shutdown", clients, "close_websocket")
        closed_cleanly = True
    finally:
        if not closed_cleanly:
            await asyncio.gather(*(client.abort() for client in clients), return_exceptions=True)


def print_failure(error: BaseException, clients: Optional[List[ListenerClient]]) -> None:
    print(f"FAIL listener load test: {credential_free_error(error)}", file=sys.stderr)
    if clients is None:
        return
    reported = 0
    for client in clients:
        for failure in client.failures:
            print(
                f"  listener {client.index:03d} ({client.source_ip}): {failure}",
                file=sys.stderr,
            )
            reported += 1
            if reported == 20:
                remaining = sum(len(item.failures) for item in clients) - reported
                if remaining > 0:
                    print(f"  ... {remaining} additional failure(s)", file=sys.stderr)
                return


def print_summary(clients: List[ListenerClient], configuration: Configuration) -> None:
    event_counts: collections.Counter = collections.Counter()
    close_codes: collections.Counter = collections.Counter()
    revisions: Set[int] = set()
    for client in clients:
        event_counts.update(client.event_counts)
        close_codes.update(client.close_codes)
        revisions.update(client.revisions)
    event_summary = ", ".join(
        f"{name}={event_counts[name]}" for name in sorted(event_counts)
    )
    close_summary = ", ".join(
        f"{code}={count}" for code, count in sorted(close_codes.items(), key=lambda item: str(item[0]))
    )
    total_websockets = sum(client.websocket_connections for client in clients)
    total_pongs = sum(client.pongs for client in clients)
    print("PASS listener load test")
    print(f"  listeners: {len(clients)}")
    print(f"  steady-state duration: {configuration.duration:.1f}s")
    print(
        f"  WebSocket connections: {total_websockets} "
        f"(reconnections: {configuration.reconnect_count})"
    )
    print(
        "  cold-start asset responses: "
        f"{sum(client.asset_responses for client in clients)}"
    )
    print(f"  authenticated HTTP snapshots: {sum(client.http_snapshots for client in clients)}")
    print(f"  acknowledged liveness probes: {total_pongs}")
    print(f"  envelope counts: {event_summary or 'none'}")
    print(
        "  ordered entry fingerprint consensus: "
        f"{len(clients[0].entry_fingerprints) if clients else 0} per listener"
    )
    if revisions:
        print(
            f"  revisions: distinct={len(revisions)}, min={min(revisions)}, max={max(revisions)}"
        )
    else:
        print("  revisions: none")
    print(f"  clean close codes: {close_summary or 'none'}")


async def async_main(configuration: Configuration) -> int:
    clients = [
        ListenerClient(index, configuration)
        for index in range(1, configuration.client_count + 1)
    ]
    try:
        await execute(configuration, clients)
    except BaseException as error:
        print_failure(error, clients)
        return 1
    print_summary(clients, configuration)
    return 0


def main(argv: Optional[List[str]] = None) -> int:
    try:
        arguments = parse_arguments(argv)
        configuration = make_configuration(arguments)
    except LoadTestError as error:
        print_failure(error, None)
        return 2
    aliases = LoopbackAliasManager(configuration)
    previous_sigterm = signal.getsignal(signal.SIGTERM)

    def interrupt_for_cleanup(signum: int, frame: object) -> None:
        del signum, frame
        raise KeyboardInterrupt

    signal.signal(signal.SIGTERM, interrupt_for_cleanup)
    try:
        aliases.prepare()
        result = asyncio.run(async_main(configuration))
    except LoadTestError as error:
        print_failure(error, None)
        result = 2
    except KeyboardInterrupt:
        print("FAIL listener load test: interrupted", file=sys.stderr)
        result = 130
    finally:
        signal.signal(signal.SIGTERM, signal.SIG_IGN)
        cleanup_error = aliases.cleanup()
        signal.signal(signal.SIGTERM, previous_sigterm)
    if cleanup_error is not None:
        print_failure(cleanup_error, None)
        return 1
    return result


if __name__ == "__main__":
    raise SystemExit(main())
