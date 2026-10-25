# Dependency and security pilot

Renovate manages version and security-fix PRs for this repository. Dependabot alerts and the
dependency graph stay enabled. Routine updates are grouped by manager, run on Sundays in
Europe/London, and have a maximum of three open PRs. Security fixes bypass routine scheduling and
have a separate limit of two PRs. Major upgrades require approval in the Dependency Dashboard.
Automerge is disabled.

The Security pilot workflow scans repository dependencies (including development dependencies),
secrets and supported configuration, and builds/scans an unpublished linux/amd64 image. Scheduled
and manually dispatched runs also scan the published image and record its resolved digest. Scan
findings do not fail the pilot, but installation, database, build and scan errors do. ARM64 is not
yet scanned.

Read the Actions job summary and the seven-day security-pilot-amd64 artifact. Reports omit secret
matches and code excerpts. No SARIF upload or paid Code Security entitlement is required. Scanner
jobs have no publishing/deployment credentials; a short-lived read-only GitHub token is used only
for release verification and pulling the published GHCR image. The Trivy release is pinned by
version, SHA-256 and verified GitHub provenance. Update the version and checksum together after
verifying a newer release.

For the BIND image, packages from packages.sury.org may be skipped or incorrectly matched against
Debian advisories. The report includes installed bind9 package versions; check these against [ISC
advisories](https://kb.isc.org/docs/aa-00913) before claiming BIND vulnerability coverage. The
existing upstream-release check and rebuild process remains necessary.

Evaluate actionable findings, noise, runtime and update PR volume before expanding or introducing
blocking rules. To stop Renovate, remove this repository from its GitHub app installation and
restore Dependabot configuration after removing the repo-sync exception. To stop scans, disable the
Security pilot workflow.
