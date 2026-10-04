-- Read-only acceptance gate after the rollback-only tests.
DO $$
BEGIN
  ASSERT (SELECT count(*) FROM public.workspaces) = 0, 'Unexpected workspace rows';
  ASSERT (SELECT count(*) FROM public.leads) = 0, 'Unexpected lead rows';
  ASSERT (SELECT count(*) FROM public.lead_contacts) = 0, 'Unexpected contact rows';
  ASSERT (SELECT count(*) FROM public.lead_lists) = 0, 'Unexpected list rows';
  ASSERT (SELECT count(*) FROM public.lead_list_items) = 0, 'Unexpected list membership rows';
  ASSERT (SELECT count(*) FROM auth.users WHERE id IN ('10000000-0000-0000-0000-000000000001','10000000-0000-0000-0000-000000000002')) = 0, 'QA identities remain';
END;
$$;
WITH row_counts AS (
 SELECT 'workspaces' AS table_name, count(*) AS records FROM public.workspaces
 UNION ALL SELECT 'leads', count(*) FROM public.leads
 UNION ALL SELECT 'lead_contacts', count(*) FROM public.lead_contacts
 UNION ALL SELECT 'lead_lists', count(*) FROM public.lead_lists
 UNION ALL SELECT 'lead_list_items', count(*) FROM public.lead_list_items
)
SELECT r.table_name, r.records, t.rowsecurity AS rls_enabled,
 NOT has_table_privilege('anon', 'public.' || r.table_name, 'SELECT') AS anonymous_reads_blocked,
 pg_size_pretty(pg_database_size(current_database())) AS database_size
FROM row_counts r JOIN pg_tables t ON t.schemaname = 'public' AND t.tablename = r.table_name
ORDER BY r.table_name;
