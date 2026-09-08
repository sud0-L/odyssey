"""Odyssey lifecycle-manager constants."""

from manager.versioning import canonical_version

PROJECT_VERSION = canonical_version()
# Internal lifecycle-protocol compatibility. This is intentionally independent
# of the public product version so an older manager can accept a newer release.
MANAGER_VERSION = "0.3.0-dev"
CONTRACT_SCHEMA_VERSION = 1
