#!/usr/bin/env python3
"""Pre-commit audit engine for repository governance enforcement.

Deterministic checks for Protocol Zero compliance, crash risk detection,
debug artifact detection, deprecated API detection, secret leakage
scanning, Conventional Commits validation, and Combine prohibition.

Exit codes:
    0 — All checks pass. Commit allowed.
    1 — One or more violations detected. Commit blocked.
"""

from __future__ import annotations

import argparse
import os
import re
import subprocess
import sys
from dataclasses import dataclass, field
from pathlib import Path
from typing import NoReturn


@dataclass
class Violation:
    """Single audit violation."""

    check_id: str
    check_name: str
    file: str
    line: int
    detail: str


@dataclass
class AuditResult:
    """Aggregate audit result."""

    files_scanned: int = 0
    violations: list[Violation] = field(default_factory=list)

    @property
    def passed(self) -> bool:
        """Return True if no violations were recorded."""
        return len(self.violations) == 0


# ---------------------------------------------------------------------------
# Governance-exempt paths (these files reference forbidden phrases as rules)
# ---------------------------------------------------------------------------
GOVERNANCE_FILES = {
    "CLAUDE.md",
    "Design-Doc.md",
    "SKILL.md",
    "remediation.md",
}

EXCLUDED_PATH_SEGMENTS = {
    ".mypy_cache",
    "__pycache__",
    ".git",
    "DerivedData",
    ".build",
    "xcuserdata",
    "node_modules",
}

SWIFT_EXTENSIONS = {".swift"}
ALL_SCANNABLE_EXTENSIONS = {".swift", ".md", ".txt", ".json", ".yaml", ".yml", ".ahap"}

# ---------------------------------------------------------------------------
# CHECK 1: Protocol Zero — Forbidden phrases (PZ-001)
# ---------------------------------------------------------------------------
PROTOCOL_ZERO_PHRASES = [
    r"generated\s+by\s+ai",
    r"as\s+an\s+ai",
    r"i\s+have\s+updated",
    r"based\s+on\s+the\s+design\s+doc",
    r"llm[\s\-]optimized",
    r"claude[\s\-]generated",
    r"ai[\s\-]assisted",
    r"co-authored-by.*(?:ai|claude|gpt|copilot)",
    r"generated\s+with",
    r"ai[\s\-]generated",
    r"written\s+by\s+ai",
    r"produced\s+by\s+ai",
    r"created\s+by\s+ai",
]
PROTOCOL_ZERO_COMPILED = [re.compile(p, re.IGNORECASE) for p in PROTOCOL_ZERO_PHRASES]

# ---------------------------------------------------------------------------
# CHECK 2: Force unwrap detection (FU-001)
# ---------------------------------------------------------------------------
FORCE_UNWRAP_PATTERN = re.compile(r"[\w\)>\]\"]!")
FORCE_UNWRAP_FALSE_POSITIVES = re.compile(
    r"!=|!==|#available|#unavailable|XCTUnwrap|@IBOutlet|///|//.*!"
)

# ---------------------------------------------------------------------------
# CHECK 3: Debug artifact detection (DA-001)
# ---------------------------------------------------------------------------
DEBUG_PATTERNS = [
    re.compile(r"\bprint\s*\("),
    re.compile(r"\bdebugPrint\s*\("),
    re.compile(r"\bNSLog\s*\("),
    re.compile(r"\bdump\s*\("),
]

# ---------------------------------------------------------------------------
# CHECK 4 + 7: Deprecated API and Combine detection (DP-001, CB-001)
# ---------------------------------------------------------------------------
DEPRECATED_PATTERNS: list[tuple[re.Pattern, str, str]] = [
    (
        re.compile(r"\bObservableObject\b"),
        "DP-001",
        "Use @Observable instead of ObservableObject",
    ),
    (re.compile(r"@Published\b"), "DP-001", "Use @Observable instead of @Published"),
    (
        re.compile(r"@StateObject\b"),
        "DP-001",
        "Use @State with @Observable instead of @StateObject",
    ),
    (
        re.compile(r"@EnvironmentObject\b"),
        "DP-001",
        "Use @Environment with @Observable instead",
    ),
    (re.compile(r"\bimport\s+Combine\b"), "CB-001", "Combine framework prohibited"),
    (re.compile(r"\bPassthroughSubject\b"), "CB-001", "Combine type prohibited"),
    (re.compile(r"\bCurrentValueSubject\b"), "CB-001", "Combine type prohibited"),
    (re.compile(r"\bAnyCancellable\b"), "CB-001", "Combine type prohibited"),
    (re.compile(r"\.sink\s*\("), "CB-001", "Combine operator prohibited"),
    (re.compile(r"\.assign\s*\(\s*to:"), "CB-001", "Combine operator prohibited"),
    (re.compile(r"\bDispatchQueue\b"), "DP-001", "Use async/await instead of GCD"),
    (
        re.compile(r"\bDispatchGroup\b"),
        "DP-001",
        "Use TaskGroup instead of DispatchGroup",
    ),
    (re.compile(r"\bDispatchSemaphore\b"), "DP-001", "Use Swift concurrency instead"),
    (re.compile(r"\bperformSelector\b"), "DP-001", "Use Swift concurrency instead"),
    (
        re.compile(r"\bPreviewProvider\b"),
        "DP-001",
        "Use #Preview macro instead of PreviewProvider",
    ),
    (
        re.compile(r"\bUIHostingController\b"),
        "DP-001",
        "UIHostingController requires explicit approval",
    ),
    (
        re.compile(r"\bUIViewController\b"),
        "DP-001",
        "UIKit controllers prohibited — use SwiftUI",
    ),
    (
        re.compile(r"\bPublishers\.\b"),
        "CB-001",
        "Combine Publishers namespace prohibited",
    ),
    (
        re.compile(r"\bSubscribers\.\b"),
        "CB-001",
        "Combine Subscribers namespace prohibited",
    ),
    (re.compile(r"\bAnyPublisher\b"), "CB-001", "Combine type prohibited"),
    (re.compile(r"\bPublished\.Publisher\b"), "CB-001", "Combine type prohibited"),
    (re.compile(r"\bCancellable\b"), "CB-001", "Combine protocol prohibited"),
    (re.compile(r"\.receive\s*\(\s*on:"), "CB-001", "Combine operator prohibited"),
    (
        re.compile(r"\.eraseToAnyPublisher\s*\("),
        "CB-001",
        "Combine operator prohibited",
    ),
]

# ---------------------------------------------------------------------------
# CHECK 5: Secret leakage detection (SL-001)
# ---------------------------------------------------------------------------
SECRET_PATTERNS: list[tuple[re.Pattern, str]] = [
    (
        re.compile(r"https?://discord(?:app)?\.com/api/webhooks/", re.IGNORECASE),
        "Plaintext Discord webhook URL detected",
    ),
    (
        re.compile(
            r"(?i)(?:api[_\-]?key|api[_\-]?secret|access[_\-]?token|auth[_\-]?token|"
            r"bearer|secret[_\-]?key|private[_\-]?key)\s*[:=]\s*[\"'][A-Za-z0-9+/=_\-]{16,}[\"']"
        ),
        "Potential secret or API key in plaintext",
    ),
    (
        re.compile(r"[\"'][A-Za-z0-9+/=]{40,}[\"']"),
        "High-entropy string literal (potential encoded secret)",
    ),
]
SECRET_FALSE_POSITIVE_PATTERNS = re.compile(
    r"test_|mock_|fake_|example_|XOR|xor|\.xcassets|bundleIdentifier|UTType"
)

# ---------------------------------------------------------------------------
# CHECK 6: Conventional Commits (CC-001)
# ---------------------------------------------------------------------------
COMMIT_MSG_PATTERN = re.compile(
    r"^(feat|fix|refactor|test|chore|docs)"
    r"\((coordinator|audio|haptics|webhook|ch[1-6]|assets|tests)\):\s"
    r"[a-z].*$"
)


def is_governance_file(filepath: str) -> bool:
    """Check if a file is a governance document exempt from Protocol Zero scanning."""
    basename = os.path.basename(filepath)
    return basename in GOVERNANCE_FILES


def is_test_file(filepath: str) -> bool:
    """Check if a file belongs to a test target."""
    basename = os.path.basename(filepath)
    return basename.endswith("Tests.swift") or basename.endswith("TestCase.swift")


def is_in_debug_block(lines: list[str], line_idx: int) -> bool:
    """Determine whether a line is inside a #if DEBUG block."""
    depth = 0
    for i in range(line_idx):
        stripped = lines[i].strip()
        if stripped == "#if DEBUG":
            depth += 1
        elif stripped == "#endif" and depth > 0:
            depth -= 1
    return depth > 0


# ---------------------------------------------------------------------------
# Individual check runners
# ---------------------------------------------------------------------------


def check_protocol_zero(filepath: str, lines: list[str], result: AuditResult) -> None:
    """PZ-001: Scan for forbidden attribution phrases."""
    if is_governance_file(filepath):
        return
    for line_num, line in enumerate(lines, start=1):
        for pattern in PROTOCOL_ZERO_COMPILED:
            if pattern.search(line):
                result.violations.append(
                    Violation(
                        check_id="PZ-001",
                        check_name="Protocol Zero",
                        file=filepath,
                        line=line_num,
                        detail=f"Forbidden phrase matched: {pattern.pattern}",
                    )
                )
                break


def check_force_unwrap(filepath: str, lines: list[str], result: AuditResult) -> None:
    """FU-001: Detect force unwrap operators in Swift files."""
    if not filepath.endswith(".swift"):
        return
    for line_num, line in enumerate(lines, start=1):
        stripped = line.strip()
        if stripped.startswith("//") or stripped.startswith("///"):
            continue
        if FORCE_UNWRAP_FALSE_POSITIVES.search(line):
            continue
        if FORCE_UNWRAP_PATTERN.search(line):
            if "!" in line:
                idx = line.index("!")
                if idx > 0 and line[idx - 1] not in (
                    " ",
                    "\t",
                    "(",
                    "{",
                    "[",
                    ",",
                    "=",
                    ":",
                ):
                    if idx + 1 < len(line) and line[idx + 1] == "=":
                        continue
                    result.violations.append(
                        Violation(
                            check_id="FU-001",
                            check_name="Force Unwrap",
                            file=filepath,
                            line=line_num,
                            detail="Force unwrap operator detected",
                        )
                    )


def check_debug_artifacts(filepath: str, lines: list[str], result: AuditResult) -> None:
    """DA-001: Detect print/debug statements outside #if DEBUG."""
    if not filepath.endswith(".swift"):
        return
    if is_test_file(filepath):
        return
    for line_num, line in enumerate(lines, start=1):
        stripped = line.strip()
        if stripped.startswith("//") or stripped.startswith("///"):
            continue
        if is_in_debug_block(lines, line_num - 1):
            continue
        for pattern in DEBUG_PATTERNS:
            if pattern.search(line):
                result.violations.append(
                    Violation(
                        check_id="DA-001",
                        check_name="Debug Artifact",
                        file=filepath,
                        line=line_num,
                        detail=f"Debug statement detected: {stripped[:60]}",
                    )
                )
                break


def check_deprecated_apis(filepath: str, lines: list[str], result: AuditResult) -> None:
    """DP-001 + CB-001: Detect deprecated APIs and Combine usage."""
    if not filepath.endswith(".swift"):
        return
    for line_num, line in enumerate(lines, start=1):
        stripped = line.strip()
        if stripped.startswith("//") or stripped.startswith("///"):
            continue
        for pattern, check_id, detail in DEPRECATED_PATTERNS:
            if pattern.search(line):
                result.violations.append(
                    Violation(
                        check_id=check_id,
                        check_name="Deprecated API"
                        if check_id == "DP-001"
                        else "Combine Usage",
                        file=filepath,
                        line=line_num,
                        detail=detail,
                    )
                )


def is_secret_scan_exempt(filepath: str) -> bool:
    """Check if a file is exempt from secret scanning (skill refs, epic docs)."""
    normalized = filepath.replace(os.sep, "/")
    if normalized.startswith(".claude/skills/") and "/references/" in normalized:
        return True
    if normalized.startswith("docs/"):
        return True
    return False


def check_secret_leakage(filepath: str, lines: list[str], result: AuditResult) -> None:
    """SL-001: Detect plaintext secrets and tokens."""
    if is_governance_file(filepath):
        return
    if is_secret_scan_exempt(filepath):
        return
    for line_num, line in enumerate(lines, start=1):
        if SECRET_FALSE_POSITIVE_PATTERNS.search(line):
            continue
        for pattern, detail in SECRET_PATTERNS:
            if pattern.search(line):
                result.violations.append(
                    Violation(
                        check_id="SL-001",
                        check_name="Secret Leakage",
                        file=filepath,
                        line=line_num,
                        detail=detail,
                    )
                )
                break


def check_commit_message(message: str, result: AuditResult) -> None:
    """CC-001: Validate Conventional Commits format."""
    if not message or not message.strip():
        result.violations.append(
            Violation(
                check_id="CC-001",
                check_name="Commit Message",
                file="<commit>",
                line=1,
                detail="Empty commit message",
            )
        )
        return

    first_line = message.strip().split("\n")[0]

    if len(first_line) > 72:
        result.violations.append(
            Violation(
                check_id="CC-001",
                check_name="Commit Message",
                file="<commit>",
                line=1,
                detail=f"First line exceeds 72 characters ({len(first_line)} chars)",
            )
        )

    if not COMMIT_MSG_PATTERN.match(first_line):
        result.violations.append(
            Violation(
                check_id="CC-001",
                check_name="Commit Message",
                file="<commit>",
                line=1,
                detail=f"Does not match format: type(scope): description — got: {first_line}",
            )
        )

    if first_line.endswith("."):
        result.violations.append(
            Violation(
                check_id="CC-001",
                check_name="Commit Message",
                file="<commit>",
                line=1,
                detail="Description must not end with a period",
            )
        )

    for pattern in PROTOCOL_ZERO_COMPILED:
        if pattern.search(first_line):
            result.violations.append(
                Violation(
                    check_id="CC-001",
                    check_name="Commit Message",
                    file="<commit>",
                    line=1,
                    detail=f"Contains forbidden attribution phrase: {pattern.pattern}",
                )
            )
            break


# ---------------------------------------------------------------------------
# File collection
# ---------------------------------------------------------------------------


def get_staged_files() -> list[str]:
    """Retrieve list of staged files from git."""
    try:
        output = subprocess.check_output(
            ["git", "diff", "--cached", "--name-only", "--diff-filter=ACMR"],
            text=True,
            stderr=subprocess.DEVNULL,
        )
        return [f.strip() for f in output.strip().split("\n") if f.strip()]
    except (subprocess.CalledProcessError, FileNotFoundError):
        return []


def get_all_tracked_files() -> list[str]:
    """Retrieve all tracked files in the repository."""
    try:
        output = subprocess.check_output(
            ["git", "ls-files"],
            text=True,
            stderr=subprocess.DEVNULL,
        )
        return [f.strip() for f in output.strip().split("\n") if f.strip()]
    except (subprocess.CalledProcessError, FileNotFoundError):
        return collect_files_fallback()


def collect_files_fallback() -> list[str]:
    """Walk the project directory when git is unavailable."""
    files = []
    for root, dirs, filenames in os.walk("."):
        dirs[:] = [d for d in dirs if d not in EXCLUDED_PATH_SEGMENTS]
        for fname in filenames:
            ext = os.path.splitext(fname)[1]
            if ext in ALL_SCANNABLE_EXTENSIONS:
                files.append(os.path.join(root, fname))
    return files


def is_excluded_path(filepath: str) -> bool:
    """Check if a file path passes through an excluded directory."""
    parts = Path(filepath).parts
    return bool(EXCLUDED_PATH_SEGMENTS.intersection(parts))


def filter_scannable(files: list[str]) -> list[str]:
    """Filter files to scannable extensions, excluding build artifacts."""
    return [
        f
        for f in files
        if os.path.splitext(f)[1] in ALL_SCANNABLE_EXTENSIONS
        and not is_excluded_path(f)
    ]


# ---------------------------------------------------------------------------
# Orchestrator
# ---------------------------------------------------------------------------


def run_audit(
    files: list[str],
    commit_message: str | None = None,
) -> AuditResult:
    """Execute all checks across the provided file list."""
    result = AuditResult()
    scannable = filter_scannable(files)
    result.files_scanned = len(scannable)

    for filepath in scannable:
        if not os.path.isfile(filepath):
            continue
        try:
            with open(filepath, encoding="utf-8", errors="replace") as fh:
                content = fh.read()
        except OSError:
            continue

        lines = content.split("\n")

        check_protocol_zero(filepath, lines, result)
        check_force_unwrap(filepath, lines, result)
        check_debug_artifacts(filepath, lines, result)
        check_deprecated_apis(filepath, lines, result)
        check_secret_leakage(filepath, lines, result)

    if commit_message is not None:
        check_commit_message(commit_message, result)

    return result


def format_report(result: AuditResult) -> str:
    """Format audit result as human-readable report."""
    lines = []
    status = "PASS" if result.passed else "FAIL"
    lines.append(f"PRE-COMMIT AUDIT: {status}")
    lines.append(f"  Scanned: {result.files_scanned} files")
    lines.append(f"  Violations: {len(result.violations)}")

    if not result.passed:
        lines.append("")
        grouped: dict[str, list[Violation]] = {}
        for v in result.violations:
            key = f"[{v.check_id}] {v.check_name}"
            grouped.setdefault(key, []).append(v)

        for group_key, violations in grouped.items():
            lines.append(f"  {group_key}")
            for v in violations:
                lines.append(f"    {v.file}:{v.line} — {v.detail}")
            lines.append("")

    commit_status = "COMMIT ALLOWED" if result.passed else "COMMIT BLOCKED"
    lines.append(f"  Status: {commit_status}")
    return "\n".join(lines)


# ---------------------------------------------------------------------------
# CLI entry point
# ---------------------------------------------------------------------------


def main() -> NoReturn:
    """Parse arguments and run audit."""
    parser = argparse.ArgumentParser(
        description="Pre-commit audit engine for repository governance enforcement."
    )
    mode = parser.add_mutually_exclusive_group(required=True)
    mode.add_argument(
        "--staged",
        action="store_true",
        help="Audit staged files only (git diff --cached)",
    )
    mode.add_argument(
        "--all",
        action="store_true",
        help="Audit all tracked files in the repository",
    )
    mode.add_argument(
        "--file",
        type=str,
        help="Audit a single file",
    )
    parser.add_argument(
        "--commit-msg",
        type=str,
        default=None,
        help="Commit message to validate (optional)",
    )

    args = parser.parse_args()

    if args.staged:
        files = get_staged_files()
    elif args.all:
        files = get_all_tracked_files()
    else:
        files = [args.file]

    result = run_audit(files, commit_message=args.commit_msg)
    report = format_report(result)

    print(report)
    sys.exit(0 if result.passed else 1)


if __name__ == "__main__":
    main()
