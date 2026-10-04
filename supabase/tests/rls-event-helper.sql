-- Rollback-only check: the administrative event trigger still protects new tables.
BEGIN;
CREATE TABLE public.leads_core_rls_hook_probe (id integer);
DO $$
BEGIN
  ASSERT (SELECT relrowsecurity FROM pg_class WHERE oid = 'public.leads_core_rls_hook_probe'::regclass),
    'Existing ensure_rls event trigger must still enable RLS';
END;
$$;
ROLLBACK;

SELECT NOT has_function_privilege('anon', 'public.rls_auto_enable()', 'EXECUTE') AS anonymous_execution_blocked,
       NOT has_function_privilege('authenticated', 'public.rls_auto_enable()', 'EXECUTE') AS authenticated_execution_blocked,
       to_regclass('public.leads_core_rls_hook_probe') IS NULL AS probe_rolled_back,
       'PASS: automatic RLS hook still works; probe rolled back' AS result;
