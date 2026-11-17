#!/usr/bin/env bash
set -euo pipefail

# Apply versioned server migrations before starting the client.
repo_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_dir"
supabase_cli="${SUPABASE_CLI:-supabase}"
flutter_cli="${FLUTTER_CLI:-flutter}"
backend_config="${BACKEND_CONFIG:-config/backend.local.json}"
device="${ANDROID_DEVICE:-emulator-5554}"

if ! command -v "$supabase_cli" >/dev/null 2>&1; then
  if [[ -x "${HOME}/.supabase/bin/supabase" ]]; then
    supabase_cli="${HOME}/.supabase/bin/supabase"
  else
    printf 'Supabase CLI is required. Install it and run supabase login.\n' >&2
    exit 1
  fi
fi
if ! command -v "$flutter_cli" >/dev/null 2>&1; then
  printf 'Flutter is required. Add it to PATH or set FLUTTER_CLI.\n' >&2
  exit 1
fi
if [[ ! -f "$backend_config" ]]; then
  printf 'Copy config/backend.example.json to %s and fill in your public project configuration.\n' "$backend_config" >&2
  exit 1
fi

project_ref="$(python3 - "$backend_config" <<'PY'
import json, re, sys
from urllib.parse import urlparse
with open(sys.argv[1]) as config_file:
    config = json.load(config_file)
host = urlparse(config.get('SUPABASE_URL', '')).hostname or ''
match = re.fullmatch(r'([a-z]{20})\.supabase\.co', host)
if not match:
    sys.exit('SUPABASE_URL must identify the hosted project to migrate.')
print(match.group(1))
PY
)"

"$supabase_cli" db push --remote="$project_ref" --yes
"$flutter_cli" pub get
exec "$flutter_cli" run -d "$device" --dart-define-from-file="$backend_config" "$@"
