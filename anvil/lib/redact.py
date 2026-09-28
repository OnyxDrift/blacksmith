#!/usr/bin/env python3
"""Remove secrets from text before anvil drafts notes from it.

Used by bin/session-read (session transcripts) and bin/ingest (web pages,
PDFs, files). The vault syncs to every machine via Syncthing, so a secret
that reaches a note spreads. Redaction happens before Claude reads the
text, so a secret never reaches a draft in the first place.

Pattern matching is not a guarantee. It catches common high-confidence
shapes; it cannot catch a secret with no recognizable shape. The approval
gate is still the final check.

Library: redact(text) -> (clean_text, {pattern_name: count})
CLI:     redact.py < in > out     (counts go to stderr)
"""
import re
import sys

# <private>...</private> lets a user mark anything for removal by hand.
PRIVATE_TAG = re.compile(r"<private>[\s\S]*?</private>", re.IGNORECASE)

# Ordered: specific shapes first, the generic assignment rule last.
PATTERNS = [
    ("private-key", re.compile(
        r"-----BEGIN [A-Z0-9 ]*PRIVATE KEY-----[\s\S]*?-----END [A-Z0-9 ]*PRIVATE KEY-----")),
    ("anthropic-key", re.compile(r"\bsk-ant-[A-Za-z0-9_\-]{20,}")),
    ("openai-key", re.compile(r"\bsk-(?:proj-|svcacct-)?[A-Za-z0-9_\-]{20,}")),
    ("github-token", re.compile(r"\b(?:gh[pousr]_[A-Za-z0-9]{30,}|github_pat_[A-Za-z0-9_]{30,})")),
    ("gitlab-token", re.compile(r"\bglpat-[A-Za-z0-9_\-]{20,}")),
    ("aws-access-key", re.compile(r"\b(?:AKIA|ASIA)[A-Z0-9]{16}\b")),
    ("slack-token", re.compile(r"\bxox[abposr]-[A-Za-z0-9\-]{10,}")),
    ("google-api-key", re.compile(r"\bAIza[A-Za-z0-9_\-]{35}\b")),
    ("xai-key", re.compile(r"\bxai-[A-Za-z0-9]{20,}")),
    ("jwt", re.compile(r"\beyJ[A-Za-z0-9_\-]{10,}\.eyJ[A-Za-z0-9_\-]{10,}\.[A-Za-z0-9_\-]{10,}")),
    ("bearer-token", re.compile(r"(?i)\bbearer\s+[A-Za-z0-9._\-~+/]{20,}=*")),
    ("url-credentials", re.compile(r"(?i)\b([a-z][a-z0-9+.\-]*://)[^\s:/@]+:[^\s/@]+@")),
]

# key = value / key: "value" where the key names a secret. Keeps the key,
# replaces only the value, so the text still reads sensibly.
ASSIGNMENT = re.compile(
    r"(?i)\b([A-Z0-9_]*(?:api[_-]?key|secret|token|passwd|password|access[_-]?key)[A-Z0-9_]*)"
    r"(\s*[:=]\s*)([\"']?)(?!\[REDACTED)([^\s\"']{8,})(\3)")


def redact(text):
    counts = {}

    def count(name, n):
        if n:
            counts[name] = counts.get(name, 0) + n

    text, n = PRIVATE_TAG.subn("[PRIVATE REMOVED]", text)
    count("private-tag", n)
    for name, pattern in PATTERNS:
        if name == "url-credentials":
            text, n = pattern.subn(r"\1[REDACTED]@", text)
        else:
            text, n = pattern.subn("[REDACTED:%s]" % name, text)
        count(name, n)
    text, n = ASSIGNMENT.subn(lambda m: m.group(1) + m.group(2) + m.group(3) + "[REDACTED]" + m.group(5), text)
    count("assignment", n)
    return text, counts


def summary(counts):
    if not counts:
        return ""
    parts = ", ".join("%s x%d" % (k, v) for k, v in sorted(counts.items()))
    return "redacted: " + parts


if __name__ == "__main__":
    clean, found = redact(sys.stdin.read())
    sys.stdout.write(clean)
    if found:
        print("(%s)" % summary(found), file=sys.stderr)
