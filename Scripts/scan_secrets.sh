#!/usr/bin/env bash
set -euo pipefail

echo "==> Running secret scan on Git-tracked files..."

if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    echo "ERROR: Not inside a Git repository." >&2
    exit 1
fi

FOUND_SECRETS=0

# Check tracked filenames for forbidden extension patterns
echo "--> Checking tracked filenames..."
while IFS= read -r file; do
    case "$file" in
        *.mobileprovision|*.provisionprofile|*.p12|*.pfx|*.cer|*.p8|*.keystore)
            echo "ERROR: Forbidden certificate or provisioning file tracked in git: $file" >&2
            FOUND_SECRETS=1
            ;;
    esac
done < <(git ls-files)

# Check tracked file contents
echo "--> Scanning file contents..."
PATTERNS=(
    '-----BEGIN [A-Z ]*PRIVATE KEY-----'
    '-----BEGIN CERTIFICATE-----'
    'ghp_[a-zA-Z0-9]{36}'
    'gho_[a-zA-Z0-9]{36}'
    'github_pat_[a-zA-Z0-9]{22}_[a-zA-Z0-9]{59}'
    'AKIA[0-9A-Z]{16}'
    'AIza[0-9A-Za-z\-_]{35}'
    'sk-[a-zA-Z0-9]{32,}'
)

while IFS= read -r file; do
    # Skip the scanner itself, symlinks/missing files, and test fixtures
    if [[ "$file" == "Scripts/scan_secrets.sh" ]] || [[ "$file" =~ (^|/)[fF]ixtures(/|$) ]]; then
        continue
    fi

    if [[ ! -f "$file" ]]; then
        continue
    fi

    for pattern in "${PATTERNS[@]}"; do
        if grep -E -q "$pattern" "$file" 2>/dev/null; then
            echo "ERROR: Potential secret detected matching '$pattern' in $file" >&2
            FOUND_SECRETS=1
        fi
    done
done < <(git ls-files)

if [ "$FOUND_SECRETS" -ne 0 ]; then
    echo "==> Secret scan FAILED: Potential secrets detected." >&2
    exit 1
fi

echo "==> Secret scan PASSED: No tracked secrets detected."
exit 0
