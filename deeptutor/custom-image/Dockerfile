FROM ghcr.io/hkuds/deeptutor:latest

# Patch prebuilt Next.js bundles so auth UI gates are enabled.
# Upstream currently ships AUTH_ENABLED=false in compiled chunks.
RUN python - <<'PY'
from pathlib import Path
import re

root = Path("/app/web/.next")
if not root.exists():
    raise SystemExit("Expected /app/web/.next to exist in base image")

patterns = [
    (re.compile(r'(\["AUTH_ENABLED",0,)!(1|0)'), r'\g<1>!0'),
    (re.compile(r'("AUTH_ENABLED",0,)!(1|0)'), r'\g<1>!0'),
]

patched_files = 0
patched_hits = 0
for path in root.rglob("*.js"):
    text = path.read_text(encoding="utf-8", errors="ignore")
    updated = text
    file_hits = 0
    for pattern, repl in patterns:
        updated, n = pattern.subn(repl, updated)
        file_hits += n
    if file_hits > 0:
        path.write_text(updated, encoding="utf-8")
        patched_files += 1
        patched_hits += file_hits

if patched_hits == 0:
    raise SystemExit("Did not find AUTH_ENABLED constant in compiled frontend bundle")

print(f"Patched AUTH_ENABLED in {patched_files} files ({patched_hits} replacements)")
PY
