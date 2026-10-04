-- Lean backend for jadxcmzgptjkfalaqulq only. Do not apply the legacy app migrations.
-- New objects only: an existing object with the same name stops this transaction.
BEGIN;

CREATE TABLE public.workspaces (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  owner_id uuid NOT NULL DEFAULT auth.uid() REFERENCES auth.users(id) ON DELETE CASCADE,
  name text NOT NULL CHECK (length(btrim(name)) BETWEEN 1 AND 120),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX workspaces_owner_idx ON public.workspaces(owner_id);

CREATE TABLE public.leads (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  workspace_id uuid NOT NULL REFERENCES public.workspaces(id) ON DELETE CASCADE,
  entity_type text NOT NULL DEFAULT 'business' CHECK (entity_type IN ('business', 'person')),
  name text NOT NULL CHECK (length(btrim(name)) BETWEEN 1 AND 300),
  company_name text,
  job_title text,
  website text,
  industry text,
  city text,
  country text,
  email text,
  phone text,
  email_status text NOT NULL DEFAULT 'unknown' CHECK (email_status IN ('unknown', 'sourced', 'verified', 'risky', 'invalid')),
  enrichment_status text NOT NULL DEFAULT 'unknown' CHECK (enrichment_status IN ('unknown', 'queued', 'running', 'enriched', 'failed')),
  fit_score smallint CHECK (fit_score BETWEEN 0 AND 100),
  source_url text,
  researched_at timestamptz,
  evidence jsonb NOT NULL DEFAULT '[]'::jsonb CHECK (jsonb_typeof(evidence) = 'array' AND octet_length(evidence::text) <= 32768),
  notes text CHECK (length(notes) <= 10000),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (workspace_id, id)
);
CREATE INDEX leads_workspace_created_idx ON public.leads(workspace_id, created_at DESC);
CREATE INDEX leads_workspace_name_idx ON public.leads(workspace_id, lower(name));
CREATE INDEX leads_workspace_type_idx ON public.leads(workspace_id, entity_type);

CREATE TABLE public.lead_contacts (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  workspace_id uuid NOT NULL REFERENCES public.workspaces(id) ON DELETE CASCADE,
  lead_id uuid NOT NULL,
  name text NOT NULL CHECK (length(btrim(name)) BETWEEN 1 AND 300),
  job_title text,
  email text,
  phone text,
  linkedin_url text,
  email_status text NOT NULL DEFAULT 'unknown' CHECK (email_status IN ('unknown', 'sourced', 'verified', 'risky', 'invalid')),
  source_url text,
  researched_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  FOREIGN KEY (workspace_id, lead_id) REFERENCES public.leads(workspace_id, id) ON DELETE CASCADE
);
CREATE INDEX lead_contacts_workspace_lead_idx ON public.lead_contacts(workspace_id, lead_id);

CREATE TABLE public.lead_lists (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  workspace_id uuid NOT NULL REFERENCES public.workspaces(id) ON DELETE CASCADE,
  name text NOT NULL CHECK (length(btrim(name)) BETWEEN 1 AND 120),
  description text CHECK (length(description) <= 2000),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (workspace_id, id)
);
CREATE UNIQUE INDEX lead_lists_workspace_name_idx ON public.lead_lists(workspace_id, lower(name));

CREATE TABLE public.lead_list_items (
  workspace_id uuid NOT NULL REFERENCES public.workspaces(id) ON DELETE CASCADE,
  list_id uuid NOT NULL,
  lead_id uuid NOT NULL,
  added_at timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (list_id, lead_id),
  FOREIGN KEY (workspace_id, list_id) REFERENCES public.lead_lists(workspace_id, id) ON DELETE CASCADE,
  FOREIGN KEY (workspace_id, lead_id) REFERENCES public.leads(workspace_id, id) ON DELETE CASCADE
);
CREATE INDEX lead_list_items_workspace_lead_idx ON public.lead_list_items(workspace_id, lead_id);

CREATE FUNCTION public.leads_core_touch_updated_at()
RETURNS trigger LANGUAGE plpgsql SECURITY INVOKER SET search_path = '' AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$;
REVOKE ALL ON FUNCTION public.leads_core_touch_updated_at() FROM PUBLIC, anon, authenticated;

ALTER TABLE public.workspaces ENABLE ROW LEVEL SECURITY;
CREATE POLICY workspace_owner_access ON public.workspaces FOR ALL TO authenticated
  USING (owner_id = (SELECT auth.uid()))
  WITH CHECK (owner_id = (SELECT auth.uid()));

DO $$
DECLARE table_name text;
BEGIN
  FOREACH table_name IN ARRAY ARRAY['leads', 'lead_contacts', 'lead_lists', 'lead_list_items'] LOOP
    EXECUTE format('ALTER TABLE public.%I ENABLE ROW LEVEL SECURITY', table_name);
    EXECUTE format(
      'CREATE POLICY workspace_owner_access ON public.%I FOR ALL TO authenticated USING (EXISTS (SELECT 1 FROM public.workspaces w WHERE w.id = workspace_id AND w.owner_id = (SELECT auth.uid()))) WITH CHECK (EXISTS (SELECT 1 FROM public.workspaces w WHERE w.id = workspace_id AND w.owner_id = (SELECT auth.uid())))', table_name
    );
  END LOOP;
  FOREACH table_name IN ARRAY ARRAY['workspaces', 'leads', 'lead_contacts', 'lead_lists'] LOOP
    EXECUTE format('CREATE TRIGGER leads_core_updated_at BEFORE UPDATE ON public.%I FOR EACH ROW EXECUTE FUNCTION public.leads_core_touch_updated_at()', table_name);
  END LOOP;
END;
$$;

REVOKE ALL ON TABLE public.workspaces, public.leads, public.lead_contacts, public.lead_lists, public.lead_list_items FROM PUBLIC, anon, authenticated;
GRANT USAGE ON SCHEMA public TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE public.workspaces, public.leads, public.lead_contacts, public.lead_lists, public.lead_list_items TO authenticated;
GRANT ALL ON TABLE public.workspaces, public.leads, public.lead_contacts, public.lead_lists, public.lead_list_items TO service_role;

COMMIT;

SELECT tablename, rowsecurity FROM pg_tables
WHERE schemaname = 'public' AND tablename IN ('workspaces', 'leads', 'lead_contacts', 'lead_lists', 'lead_list_items')
ORDER BY tablename;
