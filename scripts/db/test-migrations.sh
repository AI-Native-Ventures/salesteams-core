#!/usr/bin/env bash
set -euo pipefail

# These are connection fields, not a URL: the endpoint guard cannot be bypassed
# using URI query parameters or embedded host options. No hosted secrets needed.
case "${PGHOST:-}" in
  127.0.0.1|localhost|::1) ;;
  *) echo 'Refusing migration tests: PGHOST must be loopback.' >&2; exit 2 ;;
esac
if [[ "${PGDATABASE:-}" != salesteams_core_ci ]]; then
  echo 'Refusing migration tests: PGDATABASE must be salesteams_core_ci.' >&2
  exit 2
fi
unset PGSERVICE PGSERVICEFILE PGOPTIONS PGHOSTADDR
export PGCONNECT_TIMEOUT=5
repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$repo_root"

# Fail before writes on accidental reruns or an unexpected existing database.
psql -X -v ON_ERROR_STOP=1 <<'SQL'
DO $$
BEGIN
  ASSERT NOT EXISTS (SELECT 1 FROM pg_tables WHERE schemaname IN ('public', 'auth')),
    'Migration tests require a new empty disposable database';
  ASSERT NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname IN ('anon', 'authenticated', 'service_role')),
    'Migration tests require a fresh PostgreSQL cluster';
END;
$$;
SQL

psql -X -v ON_ERROR_STOP=1 -f scripts/db/ci-fixture.sql
for migration in supabase/migrations/*.sql; do
  echo "Applying $migration"
  psql -X -v ON_ERROR_STOP=1 -f "$migration"
done
for test in owner-isolation rls-event-helper final-state; do
  echo "Testing $test"
  psql -X -v ON_ERROR_STOP=1 -f "supabase/tests/$test.sql"
done
echo 'PASS: clean migration replay, authorization, constraints and rollback gates.'
