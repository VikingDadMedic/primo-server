-- DATABASE

-- Create tables
CREATE TABLE public.sites (
    id text NOT NULL,
    name text,
    password text,
    active_editor text,
    host text,
    active_deployment text,
    created_at timestamp with time zone DEFAULT now()
);

CREATE TABLE public.users (
    id bigint NOT NULL,
    email text,
    role text,
    sites text,
    created_at timestamp with time zone DEFAULT now(),
    updated_at timestamp with time zone DEFAULT now()
);

CREATE TABLE public.hosts (
    id bigint NOT NULL,
    name text,
    token text,
    created_at timestamp with time zone DEFAULT now(),
    updated_at timestamp with time zone DEFAULT now()
);

CREATE TABLE public.config (
    id text NOT NULL,
    value text,
    created_at timestamp with time zone DEFAULT now(),
    updated_at timestamp with time zone DEFAULT now()
);

INSERT INTO public.config (id, value, created_at, updated_at) VALUES
    ('server-token', null, now(), now());
INSERT INTO public.config (id, value, created_at, updated_at) VALUES
    ('invitation-key', null, now(), now());

-- Set owner
ALTER TABLE public.sites OWNER TO supabase_admin;
ALTER TABLE public.users OWNER TO supabase_admin;
ALTER TABLE public.hosts OWNER TO supabase_admin;
ALTER TABLE public.config OWNER TO supabase_admin;


-- Auto-generate row ID

ALTER TABLE public.users ALTER COLUMN id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.users_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);

ALTER TABLE public.hosts ALTER COLUMN id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.hosts_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);

-- Set Primary Key
ALTER TABLE ONLY public.sites
    ADD CONSTRAINT sites_pkey PRIMARY KEY (id);
ALTER TABLE ONLY public.users
    ADD CONSTRAINT users_pkey PRIMARY KEY (id);
ALTER TABLE ONLY public.hosts
    ADD CONSTRAINT hosts_pkey PRIMARY KEY (id);
ALTER TABLE ONLY public.config
    ADD CONSTRAINT config_pkey PRIMARY KEY (id);

-- Set Row Level Security
ALTER TABLE public.sites ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.users ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.hosts ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.config ENABLE ROW LEVEL SECURITY;

-- Set RLS Policy
CREATE POLICY "Authenticated users can access sites" ON public.sites FOR ALL USING (auth.role() = 'authenticated') WITH CHECK (auth.role() = 'authenticated');
CREATE POLICY "Authenticated users can access users" ON public.users FOR ALL USING (auth.role() = 'authenticated') WITH CHECK (auth.role() = 'authenticated');
CREATE POLICY "Authenticated users can access config" ON public.config FOR ALL USING (auth.role() = 'authenticated') WITH CHECK (auth.role() = 'authenticated');
-- No users can access Hosts (to secure Tokens)

-- Set permissions for tables
GRANT ALL ON TABLE public.sites TO postgres;
GRANT ALL ON TABLE public.sites TO anon;
GRANT ALL ON TABLE public.sites TO authenticated;
GRANT ALL ON TABLE public.sites TO service_role;

GRANT ALL ON TABLE public.users TO postgres;
GRANT ALL ON TABLE public.users TO anon;
GRANT ALL ON TABLE public.users TO authenticated;
GRANT ALL ON TABLE public.users TO service_role;

GRANT ALL ON TABLE public.hosts TO postgres;
GRANT ALL ON TABLE public.hosts TO anon;
GRANT ALL ON TABLE public.hosts TO authenticated;
GRANT ALL ON TABLE public.hosts TO service_role;

GRANT ALL ON TABLE public.config TO postgres;
GRANT ALL ON TABLE public.config TO anon;
GRANT ALL ON TABLE public.config TO authenticated;
GRANT ALL ON TABLE public.config TO service_role;

-- Set permissions for table sequence

GRANT ALL ON SEQUENCE public.users_id_seq TO postgres;
GRANT ALL ON SEQUENCE public.users_id_seq TO anon;
GRANT ALL ON SEQUENCE public.users_id_seq TO authenticated;
GRANT ALL ON SEQUENCE public.users_id_seq TO service_role;

GRANT ALL ON SEQUENCE public.hosts_id_seq TO postgres;
GRANT ALL ON SEQUENCE public.hosts_id_seq TO anon;
GRANT ALL ON SEQUENCE public.hosts_id_seq TO authenticated;
GRANT ALL ON SEQUENCE public.hosts_id_seq TO service_role;


-- STORAGE (for saving site data & images)
INSERT INTO storage.buckets (id, name, created_at, updated_at, public) VALUES
    ('sites', 'sites', now(), now(), true);

-- Set storage security
CREATE POLICY "Public access to view sites" ON storage.objects FOR SELECT USING (((bucket_id = 'sites'::text)));
CREATE POLICY "Give Authenticated users access to upload new sites" ON storage.objects FOR INSERT WITH CHECK (((bucket_id = 'sites'::text) AND (auth.role() = 'authenticated'::text)));
CREATE POLICY "Give Authenticated users access to update sites" ON storage.objects FOR UPDATE USING (((bucket_id = 'sites'::text) AND (auth.role() = 'authenticated'::text)));
CREATE POLICY "Give Authenticated users access to delete sites" ON storage.objects FOR DELETE USING (((bucket_id = 'sites'::text) AND (auth.role() = 'authenticated'::text)));


-- Function (for setting active user)
-- Setup
CREATE EXTENSION IF NOT EXISTS "plv8" WITH SCHEMA "pg_catalog";
COMMENT ON EXTENSION "plv8" IS 'PL/JavaScript (v8) trusted procedural language';

CREATE FUNCTION "public"."remove_active_editor"("site" "text") RETURNS smallint
    LANGUAGE "plv8"
    AS $_$

    var num_affected = plv8.execute( 
        'select pg_sleep(10); update sites set active_editor = NULL where id = $1;', 
        [site]
    );

    return num_affected;
$_$;

ALTER FUNCTION "public"."remove_active_editor"("site" "text") OWNER TO "supabase_admin";
GRANT ALL ON FUNCTION "public"."remove_active_editor"("site" "text") TO "postgres";
GRANT ALL ON FUNCTION "public"."remove_active_editor"("site" "text") TO "anon";
GRANT ALL ON FUNCTION "public"."remove_active_editor"("site" "text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."remove_active_editor"("site" "text") TO "service_role";
