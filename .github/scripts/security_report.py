"""Publish findings without retaining secret matches or source excerpts."""

import collections
import json
import os
import sys
from pathlib import Path

raw_dir, report_dir = map(Path, sys.argv[1:])
report_dir.mkdir(parents=True, exist_ok=True)
summary = [
    "## Security pilot",
    "",
    "Findings are advisory during this pilot. Scanner/build failures still fail the job.",
    "Image coverage: linux/amd64. Secret matches and source excerpts are removed from reports.",
    "",
    "| Scan | Critical CVEs | High CVEs | Other CVEs | Misconfigurations | Secrets |",
    "| --- | ---: | ---: | ---: | ---: | ---: |",
]
reports = sorted(raw_dir.glob("*.json"))
for source in reports:
    data = json.loads(source.read_text())
    # Image history and environment can retain credentials independently of findings.
    data.get("Metadata", {}).pop("ImageConfig", None)
    counts: collections.Counter[str] = collections.Counter()
    bind_packages = set()
    for result in data.get("Results", []):
        for vulnerability in result.get("Vulnerabilities", []):
            counts[vulnerability.get("Severity", "UNKNOWN")] += 1
        counts["misconfig"] += len(result.get("Misconfigurations", []))
        secrets = result.get("Secrets", [])
        counts["secrets"] += len(secrets)
        for secret in secrets:
            secret.pop("Match", None)
            secret.pop("Code", None)
        for finding in result.get("Misconfigurations", []):
            # Configuration excerpts can also contain credentials.
            cause = finding.get("CauseMetadata", {})
            cause.pop("Code", None)
            finding.pop("Traces", None)
        for package in result.get("Packages", []):
            if package.get("Name", "").startswith("bind9"):
                bind_packages.add((package["Name"], package.get("Version", "unknown")))
    (report_dir / source.name).write_text(json.dumps(data, indent=2) + "\n")
    other = sum(counts[level] for level in ["UNKNOWN", "LOW", "MEDIUM"])
    summary.append(
        f"| {source.stem} | {counts['CRITICAL']} | {counts['HIGH']} | {other} | "
        f"{counts['misconfig']} | {counts['secrets']} |"
    )
    if bind_packages:
        package_lines = [
            f"{name}: {version}" for name, version in sorted(bind_packages)
        ]
        inventory = "\n".join(package_lines)
        (report_dir / f"{source.stem}-bind-packages.txt").write_text(inventory + "\n")
if not reports:
    summary += [
        "",
        "No scan reports were produced; inspect the failed installation or scan step.",
    ]
digest_file = report_dir / "published-image-digest.txt"
if digest_file.exists():
    summary += ["", "Published image: `" + digest_file.read_text().strip() + "`"]
summary += [
    "",
    (
        "Third-party OS packages may not be covered by distribution advisories. "
        "For BIND images, compare the recorded installed version with upstream ISC advisories."
    ),
]
TEXT = "\n".join(summary) + "\n"
(report_dir / "summary.md").write_text(TEXT)
if os.environ.get("GITHUB_STEP_SUMMARY"):
    with open(os.environ["GITHUB_STEP_SUMMARY"], "a", encoding="utf-8") as stream:
        stream.write(TEXT)
