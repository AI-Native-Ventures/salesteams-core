# SalesTeams Core

The foundation for a focused leads product: discovery, research and enrichment, review, saved lists and export.

This repository currently contains the minimal database and migration tests. The application UI, discovery providers, export endpoints and deployment are not implemented here yet.

## Database

Five owner-scoped tables: `workspaces`, `leads`, `lead_contacts`, `lead_lists`, `lead_list_items`. Row-level security isolates owners. Anonymous access is denied, and composite foreign keys prevent cross-workspace references. Team sharing and agent API credentials are not implemented.

The legacy application's outreach, inbox, billing and other modules are excluded. The old repository and migration history remain separate.

## CI

GitHub Actions creates a disposable PostgreSQL 17 database, replays both migrations, and tests owner CRUD, cross-owner isolation, missing identity, anonymous denial, cross-workspace constraints, validation and rolled-back fixtures. It also verifies the administrative automatic-RLS hook still works after its permissions are restricted.

The fixture provides minimal Supabase-compatible roles, `auth.users`, `auth.uid()` and the existing administrative event trigger. It is a test fixture, not a full Supabase Auth service. CI proves PostgreSQL schema and authorization behavior; real sign-in, JWT validation, email and HTTP API integration require separate tests.

The workflow uses a standard Ubuntu runner, with no production credentials, no deployment step, and no artifact/cache uploads. Standard public-repository runners are free: https://docs.github.com/en/billing/concepts/product-billing/github-actions.

Run locally against a new disposable PostgreSQL instance with database `salesteams_core_ci`:

```sh
PGHOST=127.0.0.1 PGPORT=54339 PGDATABASE=salesteams_core_ci \
  PGUSER=postgres PGPASSWORD=disposable-ci-only \
  bash scripts/db/test-migrations.sh
```

The runner refuses non-loopback endpoints, any other database name, and a nonempty database. Create a new disposable instance for each replay; do not point this runner at your development or production data.

## Hosted migration deployment

CI testing and hosted deployment are separate. The existing hosted core tables were bootstrapped manually through SQL Editor. Before enabling `supabase db push`, verify schema equivalence and reconcile the already-applied migration versions. Do not replay the bootstrap into that initialized project, reset production, or apply the legacy application's migration chain to it.

The second migration requires the project's existing `rls_auto_enable()` administrative helper. The CI fixture provides that prerequisite. The test fixture must never be applied to the hosted project.

## License

Licensed under [PolyForm Noncommercial 1.0.0](LICENSE), using the official license text. Non-commercial use, modification and redistribution are permitted subject to its terms. Commercial use requires separate permission from the relevant rights holders. The license also defines permitted uses for certain non-commercial organizations; read the complete text.

This is source-available software. It is not licensed as open source. Third-party software and dependencies retain their own licenses.

Required Notice: Copyright 2026 SalesTeams contributors.

The project's owners retain the ability to license code they own commercially. Before accepting external code contributions, we must establish contribution terms granting the commercial rights needed for the hosted product. Please open issues for now; external code contributions are not being accepted until those terms are in place.
