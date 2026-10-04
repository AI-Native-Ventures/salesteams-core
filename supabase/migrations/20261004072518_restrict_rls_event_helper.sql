-- The dashboard-created event trigger is administrative, not an application RPC.
-- Preserve ensure_rls and its SECURITY DEFINER implementation; narrow callers only.
BEGIN;
DO $$
BEGIN
  ASSERT EXISTS (
    SELECT 1 FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
    WHERE n.nspname = 'public' AND p.proname = 'rls_auto_enable'
      AND p.prorettype = 'event_trigger'::regtype
  ), 'Expected the existing RLS event-trigger helper';
END;
$$;
REVOKE EXECUTE ON FUNCTION public.rls_auto_enable() FROM PUBLIC, anon, authenticated;
COMMIT;

SELECT NOT has_function_privilege('anon', 'public.rls_auto_enable()', 'EXECUTE') AS anonymous_execution_blocked,
       NOT has_function_privilege('authenticated', 'public.rls_auto_enable()', 'EXECUTE') AS authenticated_execution_blocked;
