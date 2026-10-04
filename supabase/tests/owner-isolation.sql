-- Run only in jadxcmzgptjkfalaqulq after the bootstrap. Fixtures never commit.
BEGIN;
SET LOCAL row_security = on;
INSERT INTO auth.users(id) VALUES
 ('10000000-0000-0000-0000-000000000001'),
 ('10000000-0000-0000-0000-000000000002');
INSERT INTO public.workspaces(id, owner_id, name) VALUES
 ('20000000-0000-0000-0000-000000000001', '10000000-0000-0000-0000-000000000001', 'QA owner A'),
 ('20000000-0000-0000-0000-000000000002', '10000000-0000-0000-0000-000000000002', 'QA owner B');
INSERT INTO public.leads(id, workspace_id, name) VALUES
 ('30000000-0000-0000-0000-000000000001', '20000000-0000-0000-0000-000000000001', 'QA lead A'),
 ('30000000-0000-0000-0000-000000000002', '20000000-0000-0000-0000-000000000002', 'QA lead B');
INSERT INTO public.lead_contacts(id, workspace_id, lead_id, name) VALUES
 ('40000000-0000-0000-0000-000000000001', '20000000-0000-0000-0000-000000000001', '30000000-0000-0000-0000-000000000001', 'QA contact A'),
 ('40000000-0000-0000-0000-000000000002', '20000000-0000-0000-0000-000000000002', '30000000-0000-0000-0000-000000000002', 'QA contact B');
INSERT INTO public.lead_lists(id, workspace_id, name) VALUES
 ('50000000-0000-0000-0000-000000000001', '20000000-0000-0000-0000-000000000001', 'QA list A'),
 ('50000000-0000-0000-0000-000000000002', '20000000-0000-0000-0000-000000000002', 'QA list B');
INSERT INTO public.lead_list_items(workspace_id, list_id, lead_id) VALUES
 ('20000000-0000-0000-0000-000000000001', '50000000-0000-0000-0000-000000000001', '30000000-0000-0000-0000-000000000001'),
 ('20000000-0000-0000-0000-000000000002', '50000000-0000-0000-0000-000000000002', '30000000-0000-0000-0000-000000000002');

SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claim.sub', '10000000-0000-0000-0000-000000000001', true);
SELECT set_config('request.jwt.claims', '{"sub":"10000000-0000-0000-0000-000000000001","role":"authenticated"}', true);

DO $$
DECLARE t text; n bigint;
BEGIN
  ASSERT current_user = 'authenticated', 'Test must run as the client role';
  FOREACH t IN ARRAY ARRAY['workspaces','leads','lead_contacts','lead_lists','lead_list_items'] LOOP
    EXECUTE format('SELECT count(*) FROM public.%I', t) INTO n;
    ASSERT n = 1, 'Owner sees only own rows: ' || t;
    EXECUTE format('UPDATE public.%I SET %I = %I WHERE %I = $1', t,
      CASE WHEN t = 'workspaces' THEN 'name' WHEN t = 'lead_list_items' THEN 'added_at' ELSE 'workspace_id' END,
      CASE WHEN t = 'workspaces' THEN 'name' WHEN t = 'lead_list_items' THEN 'added_at' ELSE 'workspace_id' END,
      CASE WHEN t = 'workspaces' THEN 'id' ELSE 'workspace_id' END
    ) USING '20000000-0000-0000-0000-000000000002'::uuid;
    GET DIAGNOSTICS n = ROW_COUNT;
    ASSERT n = 0, 'Cross-owner update blocked: ' || t;
    EXECUTE format('DELETE FROM public.%I WHERE %I = $1', t, CASE WHEN t = 'workspaces' THEN 'id' ELSE 'workspace_id' END)
      USING '20000000-0000-0000-0000-000000000002'::uuid;
    GET DIAGNOSTICS n = ROW_COUNT;
    ASSERT n = 0, 'Cross-owner delete blocked: ' || t;
  END LOOP;

  BEGIN
    INSERT INTO public.workspaces(owner_id,name) VALUES ('10000000-0000-0000-0000-000000000002','QA spoofed owner');
    RAISE EXCEPTION 'Owner spoofing was allowed';
  EXCEPTION WHEN insufficient_privilege THEN NULL;
  END;
  BEGIN
    UPDATE public.workspaces SET owner_id = '10000000-0000-0000-0000-000000000002' WHERE id = '20000000-0000-0000-0000-000000000001';
    RAISE EXCEPTION 'Owner transfer was allowed';
  EXCEPTION WHEN insufficient_privilege THEN NULL;
  END;
  BEGIN
    INSERT INTO public.leads(workspace_id,name) VALUES ('20000000-0000-0000-0000-000000000002','QA intrusion');
    RAISE EXCEPTION 'Cross-owner lead insert was allowed';
  EXCEPTION WHEN insufficient_privilege THEN NULL;
  END;
  BEGIN
    INSERT INTO public.lead_contacts(workspace_id,lead_id,name) VALUES ('20000000-0000-0000-0000-000000000002','30000000-0000-0000-0000-000000000002','QA intrusion');
    RAISE EXCEPTION 'Cross-owner contact insert was allowed';
  EXCEPTION WHEN insufficient_privilege THEN NULL;
  END;
  BEGIN
    INSERT INTO public.lead_lists(workspace_id,name) VALUES ('20000000-0000-0000-0000-000000000002','QA intrusion');
    RAISE EXCEPTION 'Cross-owner list insert was allowed';
  EXCEPTION WHEN insufficient_privilege THEN NULL;
  END;
  BEGIN
    INSERT INTO public.lead_list_items(workspace_id,list_id,lead_id) VALUES ('20000000-0000-0000-0000-000000000002','50000000-0000-0000-0000-000000000002','30000000-0000-0000-0000-000000000002');
    RAISE EXCEPTION 'Cross-owner membership insert was allowed';
  EXCEPTION WHEN insufficient_privilege THEN NULL;
  END;

  INSERT INTO public.workspaces(id,name) VALUES ('20000000-0000-0000-0000-000000000003','QA CRUD');
  ASSERT (SELECT owner_id = auth.uid() FROM public.workspaces WHERE id = '20000000-0000-0000-0000-000000000003'), 'Default workspace owner';
  INSERT INTO public.leads(id,workspace_id,entity_type,name) VALUES ('30000000-0000-0000-0000-000000000003','20000000-0000-0000-0000-000000000003','person','QA CRUD');
  INSERT INTO public.lead_contacts(workspace_id,lead_id,name) VALUES ('20000000-0000-0000-0000-000000000003','30000000-0000-0000-0000-000000000003','QA CRUD');
  INSERT INTO public.lead_lists(id,workspace_id,name) VALUES ('50000000-0000-0000-0000-000000000003','20000000-0000-0000-0000-000000000003','QA CRUD');
  INSERT INTO public.lead_list_items(workspace_id,list_id,lead_id) VALUES ('20000000-0000-0000-0000-000000000003','50000000-0000-0000-0000-000000000003','30000000-0000-0000-0000-000000000003');
  ASSERT (SELECT email_status = 'unknown' AND enrichment_status = 'unknown' AND fit_score IS NULL FROM public.leads WHERE id = '30000000-0000-0000-0000-000000000003'), 'Unknown quality remains unknown';

  BEGIN
    INSERT INTO public.lead_list_items(workspace_id,list_id,lead_id) VALUES ('20000000-0000-0000-0000-000000000001','50000000-0000-0000-0000-000000000001','30000000-0000-0000-0000-000000000003');
    RAISE EXCEPTION 'Cross-workspace list/lead link allowed';
  EXCEPTION WHEN foreign_key_violation THEN NULL;
  END;
  BEGIN
    INSERT INTO public.lead_contacts(workspace_id,lead_id,name) VALUES ('20000000-0000-0000-0000-000000000001','30000000-0000-0000-0000-000000000003','QA bad link');
    RAISE EXCEPTION 'Cross-workspace contact link allowed';
  EXCEPTION WHEN foreign_key_violation THEN NULL;
  END;
  BEGIN
    INSERT INTO public.lead_list_items(workspace_id,list_id,lead_id) VALUES ('20000000-0000-0000-0000-000000000003','50000000-0000-0000-0000-000000000003','30000000-0000-0000-0000-000000000003');
    RAISE EXCEPTION 'Duplicate list membership allowed';
  EXCEPTION WHEN unique_violation THEN NULL;
  END;
  BEGIN
    UPDATE public.leads SET evidence = '{}'::jsonb WHERE id = '30000000-0000-0000-0000-000000000003';
    RAISE EXCEPTION 'Invalid evidence shape allowed';
  EXCEPTION WHEN check_violation THEN NULL;
  END;
  BEGIN
    UPDATE public.leads SET fit_score = 101 WHERE id = '30000000-0000-0000-0000-000000000003';
    RAISE EXCEPTION 'Invalid fit score allowed';
  EXCEPTION WHEN check_violation THEN NULL;
  END;

  FOREACH t IN ARRAY ARRAY['workspaces','leads','lead_contacts','lead_lists','lead_list_items'] LOOP
    EXECUTE format('UPDATE public.%I SET %I = %I WHERE %I = $1', t,
      CASE WHEN t = 'workspaces' THEN 'name' WHEN t = 'lead_list_items' THEN 'added_at' ELSE 'workspace_id' END,
      CASE WHEN t = 'workspaces' THEN 'name' WHEN t = 'lead_list_items' THEN 'added_at' ELSE 'workspace_id' END,
      CASE WHEN t = 'workspaces' THEN 'id' ELSE 'workspace_id' END
    ) USING '20000000-0000-0000-0000-000000000003'::uuid;
    GET DIAGNOSTICS n = ROW_COUNT;
    ASSERT n = 1, 'Owner update allowed: ' || t;
  END LOOP;
  FOREACH t IN ARRAY ARRAY['lead_list_items','lead_contacts','lead_lists','leads','workspaces'] LOOP
    EXECUTE format('DELETE FROM public.%I WHERE %I = $1', t, CASE WHEN t = 'workspaces' THEN 'id' ELSE 'workspace_id' END)
      USING '20000000-0000-0000-0000-000000000003'::uuid;
    GET DIAGNOSTICS n = ROW_COUNT;
    ASSERT n = 1, 'Owner delete allowed: ' || t;
  END LOOP;
END;
$$;

SELECT set_config('request.jwt.claim.sub', '', true);
SELECT set_config('request.jwt.claims', '{}', true);
DO $$
DECLARE t text; n bigint;
BEGIN
  FOREACH t IN ARRAY ARRAY['workspaces','leads','lead_contacts','lead_lists','lead_list_items'] LOOP
    EXECUTE format('SELECT count(*) FROM public.%I',t) INTO n;
    ASSERT n = 0, 'Missing user claim exposes rows: ' || t;
  END LOOP;
END;
$$;

SET LOCAL ROLE anon;
DO $$
DECLARE t text; statement text;
BEGIN
  FOREACH t IN ARRAY ARRAY['workspaces','leads','lead_contacts','lead_lists','lead_list_items'] LOOP
    ASSERT NOT has_table_privilege(current_user, 'public.' || t, 'SELECT'), 'Anonymous read grant: ' || t;
    ASSERT NOT has_table_privilege(current_user, 'public.' || t, 'INSERT'), 'Anonymous insert grant: ' || t;
    ASSERT NOT has_table_privilege(current_user, 'public.' || t, 'UPDATE'), 'Anonymous update grant: ' || t;
    ASSERT NOT has_table_privilege(current_user, 'public.' || t, 'DELETE'), 'Anonymous delete grant: ' || t;
    FOREACH statement IN ARRAY ARRAY[
      format('SELECT 1 FROM public.%I LIMIT 1',t),
      format('INSERT INTO public.%I DEFAULT VALUES',t),
      format('UPDATE public.%I SET %I = %I WHERE false',t,CASE WHEN t = 'workspaces' THEN 'name' ELSE 'workspace_id' END,CASE WHEN t = 'workspaces' THEN 'name' ELSE 'workspace_id' END),
      format('DELETE FROM public.%I WHERE false',t)
    ] LOOP
      BEGIN
        EXECUTE statement;
        RAISE EXCEPTION 'Anonymous operation allowed: %', statement;
      EXCEPTION WHEN insufficient_privilege THEN NULL;
      END;
    END LOOP;
  END LOOP;
END;
$$;
RESET ROLE;
ROLLBACK;
SELECT 'PASS: owner CRUD, cross-owner isolation, missing-identity isolation, anonymous denial, cross-workspace constraints and data validation; all fixtures rolled back' AS result;
