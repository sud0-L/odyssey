"""Bounded public-release acquisition; verification remains in ``artifact``."""
from __future__ import annotations
import hashlib, json, tempfile
from pathlib import Path
from urllib.parse import urlparse
from urllib.request import Request, build_opener, HTTPRedirectHandler

MAX_DESCRIPTOR, MAX_ARTIFACT = 16 * 1024, 512 * 1024 * 1024

class AcquireError(ValueError): pass
_GITHUB_DELIVERY_HOSTS = {"objects.githubusercontent.com", "release-assets.githubusercontent.com", "github-releases.githubusercontent.com"}
class _GitHubReleaseRedirect(HTTPRedirectHandler):
    """GitHub release URLs redirect to a signed GitHubusercontent asset URL."""
    def redirect_request(self, request, fp, code, message, headers, target):
        source, destination = urlparse(request.full_url), urlparse(target)
        if source.scheme == destination.scheme == "https" and source.hostname == "github.com" and destination.hostname in ({"github.com"} | _GITHUB_DELIVERY_HOSTS):
            return super().redirect_request(request, fp, code, message, headers, target)
        return None

def default_url(root: Path) -> str | None:
    try: value = json.loads((root / "manager/default-release.json").read_text())
    except (OSError, json.JSONDecodeError) as error: raise AcquireError("shipped release source is invalid") from error
    if set(value) != {"schema", "descriptorUrl"} or value["schema"] != 1: raise AcquireError("shipped release source is invalid")
    url = value["descriptorUrl"]
    if url is None: return None
    if not isinstance(url, str) or not _https(url): raise AcquireError("shipped release descriptor must be HTTPS")
    return url

def acquire(descriptor_url: str, directory: Path) -> tuple[Path, str, dict[str, str]]:
    descriptor = _json(_read(descriptor_url, MAX_DESCRIPTOR), "release descriptor")
    if set(descriptor) != {"schema", "releaseId", "artifactUrl", "artifactSha256"} or descriptor.get("schema") != 1: raise AcquireError("release descriptor schema is invalid")
    artifact, digest, release = descriptor.get("artifactUrl"), descriptor.get("artifactSha256"), descriptor.get("releaseId")
    if not all(isinstance(v, str) for v in (artifact, digest, release)) or len(digest) != 64 or any(c not in "0123456789abcdef" for c in digest): raise AcquireError("release descriptor identity is invalid")
    if not _https(artifact) or _origin(artifact) != _origin(descriptor_url): raise AcquireError("release artifact must be same-origin HTTPS")
    data = _read(artifact, MAX_ARTIFACT); container = hashlib.sha256(data).hexdigest()
    directory.mkdir(parents=True, exist_ok=True); fd, name = tempfile.mkstemp(prefix="artifact-", suffix=".ody", dir=directory)
    with open(fd, "wb", closefd=True) as out: out.write(data)
    return Path(name), digest, {"kind":"https", "descriptorUrl":descriptor_url, "releaseId":release, "artifactUrl":artifact, "containerSha256":container}

def _read(url: str, maximum: int) -> bytes:
    try:
        with build_opener(_GitHubReleaseRedirect).open(Request(url, headers={"Accept":"application/json"}), timeout=15) as response:
            final = response.geturl()
            if final != url and not _github_delivery(url, final): raise AcquireError("release source redirect is refused")
            length = response.headers.get("Content-Length")
            if length and (not length.isdigit() or int(length) > maximum): raise AcquireError("release source exceeds size limit")
            data = response.read(maximum + 1)
    except AcquireError: raise
    except Exception as error: raise AcquireError("release source is unavailable") from error
    if len(data) > maximum: raise AcquireError("release source exceeds size limit")
    return data
def _json(data, label):
    try: return json.loads(data.decode("utf-8"))
    except (UnicodeDecodeError, json.JSONDecodeError) as error: raise AcquireError(f"{label} is invalid JSON") from error
def _https(url):
    p=urlparse(url); return p.scheme == "https" and bool(p.hostname) and not p.username and not p.password and not p.fragment
def _origin(url):
    p=urlparse(url); return (p.scheme, p.hostname, p.port or 443)
def _github_delivery(source, destination):
    first, last = urlparse(source), urlparse(destination)
    return first.scheme == last.scheme == "https" and first.hostname == "github.com" and last.hostname in ({"github.com"} | _GITHUB_DELIVERY_HOSTS)
