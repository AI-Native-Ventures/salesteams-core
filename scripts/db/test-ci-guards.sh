#!/usr/bin/env bash
set -euo pipefail
repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$repo_root"

# No connection should be attempted for these two rejected destinations.
if output=$(PGHOST=not-loopback.invalid bash scripts/db/test-migrations.sh 2>&1); then
  echo 'FAIL: remote destination was accepted.' >&2; exit 1
fi
[[ "$output" == *'PGHOST must be loopback.'* ]] || { echo "$output" >&2; exit 1; }
if output=$(PGDATABASE=production bash scripts/db/test-migrations.sh 2>&1); then
  echo 'FAIL: wrong database name was accepted.' >&2; exit 1
fi
[[ "$output" == *'PGDATABASE must be salesteams_core_ci.'* ]] || { echo "$output" >&2; exit 1; }

# The prior replay populated this disposable schema: another replay must refuse
# it before attempting CREATE ROLE, migrations or test fixtures.
if output=$(bash scripts/db/test-migrations.sh 2>&1); then
  echo 'FAIL: populated database was accepted.' >&2; exit 1
fi
[[ "$output" == *'require a new empty disposable database'* ]] || { echo "$output" >&2; exit 1; }

# This script runs only after the guarded replay job succeeds against its fixed
# ephemeral service. Deliberately inject an authorization bug and prove the
# acceptance test catches the specific fault, rather than any unrelated error.
unset PGSERVICE PGSERVICEFILE PGOPTIONS PGHOSTADDR
psql -X -v ON_ERROR_STOP=1 -c 'GRANT SELECT ON public.leads TO anon;'
if output=$(psql -X -v ON_ERROR_STOP=1 -f supabase/tests/owner-isolation.sql 2>&1); then
  echo 'FAIL: access test accepted an anonymous read grant.' >&2; exit 1
fi
[[ "$output" == *'Anonymous read grant: leads'* ]] || { echo "$output" >&2; exit 1; }
psql -X -v ON_ERROR_STOP=1 -c 'REVOKE SELECT ON public.leads FROM anon;'
psql -X -v ON_ERROR_STOP=1 -f supabase/tests/final-state.sql
echo 'PASS: endpoint/database/rerun guards and injected anonymous-grant detection.'
