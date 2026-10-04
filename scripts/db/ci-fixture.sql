-- TEST FIXTURE ONLY. This is not a production migration or a full Auth service.
-- The runner requires an empty, disposable loopback database before loading it.
CREATE ROLE anon NOLOGIN;
CREATE ROLE authenticated NOLOGIN;
CREATE ROLE service_role NOLOGIN BYPASSRLS;
CREATE SCHEMA auth;
CREATE TABLE auth.users (id uuid PRIMARY KEY);
CREATE FUNCTION auth.uid() RETURNS uuid LANGUAGE sql STABLE AS $$
  SELECT coalesce(
    nullif(current_setting('request.jwt.claim.sub', true), ''),
    nullif(current_setting('request.jwt.claims', true), '')::jsonb ->> 'sub'
  )::uuid;
$$;
GRANT USAGE ON SCHEMA auth TO anon, authenticated, service_role;
GRANT EXECUTE ON FUNCTION auth.uid() TO anon, authenticated, service_role;
GRANT ALL ON auth.users TO service_role;

-- Reproduce the project's pre-existing administrative hook so the exact
-- hardening migration and its regression test can run from a clean database.
CREATE FUNCTION public.rls_auto_enable() RETURNS event_trigger
LANGUAGE plpgsql SECURITY DEFINER SET search_path = pg_catalog AS $$
DECLARE cmd record;
BEGIN
  FOR cmd IN SELECT * FROM pg_event_trigger_ddl_commands()
    WHERE command_tag IN ('CREATE TABLE', 'CREATE TABLE AS', 'SELECT INTO')
      AND object_type IN ('table', 'partitioned table')
  LOOP
    IF cmd.schema_name = 'public' THEN
      EXECUTE format('ALTER TABLE IF EXISTS %s ENABLE ROW LEVEL SECURITY', cmd.object_identity);
    END IF;
  END LOOP;
END;
$$;
CREATE EVENT TRIGGER ensure_rls ON ddl_command_end EXECUTE FUNCTION public.rls_auto_enable();
GRANT EXECUTE ON FUNCTION public.rls_auto_enable() TO anon, authenticated, service_role;
