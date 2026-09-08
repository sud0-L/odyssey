"""Bounded official-release discovery and acquisition.

Network data is metadata only. Downloaded artifacts are always passed through the
existing Odyssey artifact verifier before they can reach lifecycle activation.
"""
from __future__ import annotations

import hashlib
import json
import tempfile
from pathlib import Path
from urllib.parse import urlparse
from urllib.request import HTTPRedirectHandler, Request, build_opener

from manager.artifact import verify
from manager.versioning import parse_public_version

MAX_DESCRIPTOR = 16 * 1024
MAX_RELEASES = 1024 * 1024
MAX_ARTIFACT = 512 * 1024 * 1024
DESCRIPTOR_ASSET = "odyssey-release.json"
ARTIFACT_ASSET = "odyssey.ody"


class AcquireError(ValueError):
    pass


_GITHUB_DELIVERY_HOSTS = {
    "objects.githubusercontent.com",
    "release-assets.githubusercontent.com",
    "github-releases.githubusercontent.com",
}


class _GitHubReleaseRedirect(HTTPRedirectHandler):
    """Allow only GitHub's HTTPS release-asset delivery redirects."""

    def redirect_request(self, request, fp, code, message, headers, target):
        source, destination = urlparse(request.full_url), urlparse(target)
        if (source.scheme == destination.scheme == "https"
                and source.hostname == "github.com"
                and destination.hostname in ({"github.com"} | _GITHUB_DELIVERY_HOSTS)):
            return super().redirect_request(request, fp, code, message, headers, target)
        return None


def _configuration(root: Path) -> dict[str, object]:
    try:
        value = json.loads((root / "manager/default-release.json").read_text())
    except (OSError, json.JSONDecodeError) as error:
        raise AcquireError("shipped release source is invalid") from error
    legacy = {"schema", "descriptorUrl"}
    current = legacy | {"githubReleasesUrl"}
    if set(value) == legacy and value.get("schema") == 1:
        descriptor = value.get("descriptorUrl")
        if descriptor is not None and (not isinstance(descriptor, str) or not _https(descriptor)):
            raise AcquireError("shipped release descriptor must be HTTPS")
        return value
    if set(value) != current or value.get("schema") != 2:
        raise AcquireError("shipped release source is invalid")
    descriptor, releases = value.get("descriptorUrl"), value.get("githubReleasesUrl")
    if descriptor is not None and (not isinstance(descriptor, str) or not _https(descriptor)):
        raise AcquireError("shipped release descriptor must be HTTPS")
    if (not isinstance(releases, str) or not _https(releases)
            or urlparse(releases).hostname != "api.github.com"):
        raise AcquireError("official GitHub release endpoint is invalid")
    return value


def default_url(root: Path) -> str | None:
    return _configuration(root)["descriptorUrl"]  # type: ignore[return-value]


def github_releases_url(root: Path) -> str:
    value = _configuration(root).get("githubReleasesUrl")
    if not isinstance(value, str):
        raise AcquireError("official GitHub release endpoint is not configured")
    return value


def discover_latest(releases_url: str) -> dict[str, str]:
    """Discover and validate metadata for the highest-version official release."""
    if not _https(releases_url) or urlparse(releases_url).hostname != "api.github.com":
        raise AcquireError("official GitHub release endpoint must use api.github.com HTTPS")
    releases = _json(_read(releases_url, MAX_RELEASES), "GitHub release response")
    if not isinstance(releases, list):
        raise AcquireError("GitHub release response must be an array")
    candidates: list[tuple[tuple[object, ...], str, dict[str, object]]] = []
    for release in releases:
        if not isinstance(release, dict) or release.get("draft") is not False:
            continue
        tag = release.get("tag_name")
        if not isinstance(tag, str):
            continue
        version = tag.removeprefix("v")
        try:
            key = parse_public_version(version)
        except ValueError:
            continue
        candidates.append((key, version, release))
    if not candidates:
        raise AcquireError("no official Odyssey GitHub Release is available")
    _, version, release = max(candidates, key=lambda item: item[0])
    assets = release.get("assets")
    if not isinstance(assets, list):
        raise AcquireError("latest GitHub Release has malformed assets")
    named: dict[str, str] = {}
    for asset in assets:
        if not isinstance(asset, dict):
            continue
        name, url = asset.get("name"), asset.get("browser_download_url")
        if name in (DESCRIPTOR_ASSET, ARTIFACT_ASSET) and isinstance(url, str):
            if name in named:
                raise AcquireError(f"latest GitHub Release has duplicate {name} assets")
            named[name] = url
    if set(named) != {DESCRIPTOR_ASSET, ARTIFACT_ASSET}:
        raise AcquireError("latest GitHub Release is incomplete")
    descriptor_url, artifact_url = named[DESCRIPTOR_ASSET], named[ARTIFACT_ASSET]
    github_origin = ("https", "github.com", 443)
    if (not _https(descriptor_url) or not _https(artifact_url)
            or _origin(descriptor_url) != github_origin
            or _origin(artifact_url) != github_origin):
        raise AcquireError("GitHub Release assets must use official github.com HTTPS URLs")
    descriptor = _descriptor(_read(descriptor_url, MAX_DESCRIPTOR), descriptor_url)
    if descriptor["version"] != version:
        raise AcquireError("release descriptor version does not match the GitHub tag")
    if descriptor["artifactUrl"] != artifact_url:
        raise AcquireError("release descriptor artifact does not match the GitHub Release asset")
    return {**descriptor, "descriptorUrl": descriptor_url,
            "githubReleasesUrl": releases_url}


def acquire_candidate(candidate: dict[str, str], directory: Path) -> tuple[Path, str, dict[str, str]]:
    artifact_url = candidate.get("artifactUrl", "")
    digest = candidate.get("artifactSha256", "")
    release_id = candidate.get("releaseId", "")
    if not _https(artifact_url) or _origin(artifact_url) != ("https", "github.com", 443):
        raise AcquireError("release artifact must use official github.com HTTPS")
    data = _read(artifact_url, MAX_ARTIFACT)
    container = hashlib.sha256(data).hexdigest()
    path = _write_artifact(data, directory)
    try:
        identity = verify(path, digest)
    except (OSError, ValueError) as error:
        raise AcquireError(f"downloaded release artifact verification failed: {error}") from error
    if identity.get("releaseId") != release_id:
        raise AcquireError("downloaded artifact identity does not match its release descriptor")
    return path, digest, {
        "kind": "github-release",
        "descriptorUrl": candidate["descriptorUrl"],
        "releaseId": release_id,
        "version": candidate["version"],
        "artifactUrl": artifact_url,
        "containerSha256": container,
    }


def acquire(descriptor_url: str, directory: Path) -> tuple[Path, str, dict[str, str]]:
    """Acquire a directly configured descriptor (the pre-existing path)."""
    descriptor = _descriptor(_read(descriptor_url, MAX_DESCRIPTOR), descriptor_url,
                             allow_legacy=True)
    data = _read(descriptor["artifactUrl"], MAX_ARTIFACT)
    path = _write_artifact(data, directory)
    return path, descriptor["artifactSha256"], {
        "kind": "https", "descriptorUrl": descriptor_url,
        "releaseId": descriptor["releaseId"],
        "artifactUrl": descriptor["artifactUrl"],
        "containerSha256": hashlib.sha256(data).hexdigest(),
    }


def _descriptor(data: bytes, descriptor_url: str, *,
                allow_legacy: bool = False) -> dict[str, str]:
    value = _json(data, "release descriptor")
    legacy = {"schema", "releaseId", "artifactUrl", "artifactSha256"}
    current = legacy | {"product", "version"}
    accepted = (legacy, current) if allow_legacy else (current,)
    if not isinstance(value, dict) or set(value) not in accepted:
        raise AcquireError("release descriptor schema is invalid")
    schemas = (1, 2) if allow_legacy else (2,)
    if value.get("schema") not in schemas:
        raise AcquireError("release descriptor schema is invalid")
    if set(value) == current:
        if value.get("schema") != 2 or value.get("product") != "odyssey":
            raise AcquireError("release descriptor schema is invalid")
        try:
            parse_public_version(value.get("version"))  # type: ignore[arg-type]
        except (TypeError, ValueError) as error:
            raise AcquireError("release descriptor version is invalid") from error
    artifact = value.get("artifactUrl")
    digest = value.get("artifactSha256")
    release = value.get("releaseId")
    if (not all(isinstance(item, str) for item in (artifact, digest, release))
            or len(digest) != 64
            or any(character not in "0123456789abcdef" for character in digest)):
        raise AcquireError("release descriptor identity is invalid")
    if set(value) == current and release != f"{value['version']}-{digest}":
        raise AcquireError("release descriptor does not bind its public version and digest")
    if not _https(artifact) or _origin(artifact) != _origin(descriptor_url):
        raise AcquireError("release artifact must be same-origin HTTPS")
    result = {
        "releaseId": str(release),
        "artifactUrl": str(artifact),
        "artifactSha256": str(digest),
    }
    if set(value) == current:
        result["version"] = str(value["version"])
    return result


def _write_artifact(data: bytes, directory: Path) -> Path:
    directory.mkdir(parents=True, exist_ok=True)
    descriptor, name = tempfile.mkstemp(
        prefix="artifact-", suffix=".ody", dir=directory)
    with open(descriptor, "wb", closefd=True) as output:
        output.write(data)
    return Path(name)


def _read(url: str, maximum: int) -> bytes:
    try:
        request = Request(url, headers={
            "Accept": "application/vnd.github+json, application/json",
            "User-Agent": "odyssey-lifecycle-manager",
        })
        with build_opener(_GitHubReleaseRedirect).open(request, timeout=15) as response:
            final = response.geturl()
            if final != url and not _github_delivery(url, final):
                raise AcquireError("release source redirect is refused")
            length = response.headers.get("Content-Length")
            if length and (not length.isdigit() or int(length) > maximum):
                raise AcquireError("release source exceeds size limit")
            data = response.read(maximum + 1)
    except AcquireError:
        raise
    except Exception as error:
        raise AcquireError("release source is unavailable") from error
    if len(data) > maximum:
        raise AcquireError("release source exceeds size limit")
    return data


def _json(data: bytes, label: str):
    try:
        return json.loads(data.decode("utf-8"))
    except (UnicodeDecodeError, json.JSONDecodeError) as error:
        raise AcquireError(f"{label} is invalid JSON") from error


def _https(url: object) -> bool:
    if not isinstance(url, str):
        return False
    parsed = urlparse(url)
    return (parsed.scheme == "https" and bool(parsed.hostname)
            and not parsed.username and not parsed.password and not parsed.fragment)


def _origin(url: str) -> tuple[str, str | None, int]:
    parsed = urlparse(url)
    return parsed.scheme, parsed.hostname, parsed.port or 443


def _github_delivery(source: str, destination: str) -> bool:
    first, last = urlparse(source), urlparse(destination)
    return (first.scheme == last.scheme == "https"
            and first.hostname == "github.com"
            and last.hostname in ({"github.com"} | _GITHUB_DELIVERY_HOSTS))
