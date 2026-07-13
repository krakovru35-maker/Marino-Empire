-- Canonical Marino legacy gameplay schema reconstructed from a reviewed

-- production schema-only export. No production rows, owners or secrets.

-- Legacy economy function bodies are preserved; only security boundaries differ.



begin;



set local check_function_bodies = false;

set local search_path = pg_catalog, public;



-- TABLE: marino_achievements
CREATE TABLE public.marino_achievements (
    id integer NOT NULL,
    achievement_key text NOT NULL,
    achievement_name text NOT NULL,
    description text DEFAULT ''::text,
    icon text DEFAULT '🏅'::text,
    reward_coin bigint DEFAULT 0,
    reward_token integer DEFAULT 0,
    sort_order integer DEFAULT 0
);

-- TABLE: marino_ad_reward_logs
CREATE TABLE public.marino_ad_reward_logs (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    telegram_id text,
    reward_coin numeric DEFAULT 250 NOT NULL,
    request_id text,
    created_at timestamp with time zone DEFAULT now()
);

-- TABLE: marino_buildings
CREATE TABLE public.marino_buildings (
    id integer NOT NULL,
    building_key text NOT NULL,
    building_name text NOT NULL,
    base_cost bigint DEFAULT 1000 NOT NULL,
    base_income bigint DEFAULT 100 NOT NULL,
    cost_multiplier numeric(6,4) DEFAULT 1.15,
    unlock_level integer DEFAULT 1,
    sort_order integer DEFAULT 0
);

-- TABLE: marino_daily_cipher
CREATE TABLE public.marino_daily_cipher (
    id bigint NOT NULL,
    telegram_id text NOT NULL,
    cipher_date date NOT NULL,
    attempts integer DEFAULT 0 NOT NULL,
    won boolean DEFAULT false,
    reward_claimed bigint DEFAULT 0,
    updated_at timestamp with time zone DEFAULT now()
);

-- TABLE: marino_daily_combo
CREATE TABLE public.marino_daily_combo (
    id bigint NOT NULL,
    telegram_id text NOT NULL,
    combo_date date NOT NULL,
    attempts_left integer DEFAULT 6 NOT NULL,
    picks jsonb DEFAULT '[]'::jsonb,
    won boolean DEFAULT false,
    reward_claimed bigint DEFAULT 0,
    updated_at timestamp with time zone DEFAULT now()
);

-- TABLE: marino_daily_login
CREATE TABLE public.marino_daily_login (
    id bigint NOT NULL,
    player_id bigint NOT NULL,
    current_streak integer DEFAULT 0,
    longest_streak integer DEFAULT 0,
    last_login_date date,
    total_logins integer DEFAULT 0,
    last_claim_at timestamp with time zone,
    mini_games_played integer DEFAULT 0
);

-- TABLE: marino_player_achievements
CREATE TABLE public.marino_player_achievements (
    id bigint NOT NULL,
    player_id bigint NOT NULL,
    achievement_key text NOT NULL,
    earned_at timestamp with time zone DEFAULT now()
);

-- TABLE: marino_player_boosts
CREATE TABLE public.marino_player_boosts (
    telegram_id text NOT NULL,
    multitap_lvl integer DEFAULT 0 NOT NULL,
    energy_lvl integer DEFAULT 0 NOT NULL,
    auto_tap_until timestamp with time zone,
    full_energy_date date,
    full_energy_used integer DEFAULT 0 NOT NULL,
    tap_boost_date date,
    tap_boost_used integer DEFAULT 0 NOT NULL,
    updated_at timestamp with time zone DEFAULT now()
);

-- TABLE: marino_player_buildings
CREATE TABLE public.marino_player_buildings (
    id bigint NOT NULL,
    player_id bigint NOT NULL,
    building_key text NOT NULL,
    level integer DEFAULT 0
);

-- TABLE: marino_player_seasons
CREATE TABLE public.marino_player_seasons (
    id bigint NOT NULL,
    player_id bigint NOT NULL,
    season_key text NOT NULL,
    season_xp bigint DEFAULT 0,
    tier integer DEFAULT 0
);

-- TABLE: marino_player_tasks
CREATE TABLE public.marino_player_tasks (
    id bigint NOT NULL,
    player_id bigint NOT NULL,
    task_key text NOT NULL,
    claimed_at timestamp with time zone DEFAULT now()
);

-- TABLE: marino_players
CREATE TABLE public.marino_players (
    id bigint NOT NULL,
    telegram_id text NOT NULL,
    telegram_username text DEFAULT ''::text,
    site_username text DEFAULT ''::text,
    first_name text DEFAULT 'Oyuncu'::text,
    last_name text DEFAULT ''::text,
    display_name text DEFAULT 'Oyuncu'::text,
    language_code text DEFAULT 'tr'::text,
    country_code text DEFAULT 'TR'::text,
    country_name text DEFAULT 'Türkiye'::text,
    marino_coin bigint DEFAULT 0,
    reward_token integer DEFAULT 0,
    energy integer DEFAULT 500,
    max_energy integer DEFAULT 500,
    tap_power integer DEFAULT 1,
    passive_income_per_hour bigint DEFAULT 0,
    claimable_coin bigint DEFAULT 0,
    casino_level integer DEFAULT 1,
    reputation bigint DEFAULT 0,
    prestige_points integer DEFAULT 0,
    offline_capacity_hours integer DEFAULT 8,
    last_income_collect timestamp with time zone DEFAULT now(),
    last_energy_update timestamp with time zone DEFAULT now(),
    sound_enabled boolean DEFAULT true,
    music_enabled boolean DEFAULT false,
    music_path text DEFAULT 'public/assets/audio/fon.mp3'::text,
    is_admin boolean DEFAULT false,
    created_at timestamp with time zone DEFAULT now(),
    updated_at timestamp with time zone DEFAULT now(),
    is_banned boolean DEFAULT false NOT NULL,
    referred_by text DEFAULT ''::text,
    completed_tasks jsonb DEFAULT '[]'::jsonb,
    casino_chips bigint DEFAULT 0,
    active_game_state jsonb
);

-- TABLE: marino_processed_requests
CREATE TABLE public.marino_processed_requests (
    request_id text NOT NULL,
    created_at timestamp with time zone DEFAULT now()
);

-- TABLE: marino_reward_requests
CREATE TABLE public.marino_reward_requests (
    id bigint NOT NULL,
    player_id bigint NOT NULL,
    telegram_id text NOT NULL,
    item_code text NOT NULL,
    item_name text DEFAULT ''::text,
    site_username text DEFAULT ''::text,
    display_name text DEFAULT ''::text,
    status text DEFAULT 'pending'::text,
    admin_note text DEFAULT ''::text,
    request_id text DEFAULT ''::text,
    created_at timestamp with time zone DEFAULT now(),
    reviewed_at timestamp with time zone,
    reviewed_by text DEFAULT ''::text,
    is_read boolean DEFAULT false,
    CONSTRAINT marino_reward_requests_status_check CHECK ((status = ANY (ARRAY['pending'::text, 'approved'::text, 'rejected'::text])))
);

-- TABLE: marino_seasons
CREATE TABLE public.marino_seasons (
    id integer NOT NULL,
    season_key text NOT NULL,
    season_name text NOT NULL,
    starts_at timestamp with time zone NOT NULL,
    ends_at timestamp with time zone NOT NULL,
    is_active boolean DEFAULT false
);

-- TABLE: marino_sink_purchases
CREATE TABLE public.marino_sink_purchases (
    id bigint NOT NULL,
    telegram_id text NOT NULL,
    sink_code text NOT NULL,
    cost_coin numeric NOT NULL,
    cost_token integer DEFAULT 0 NOT NULL,
    request_id text,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);

-- TABLE: marino_sports_coupons
CREATE TABLE public.marino_sports_coupons (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    telegram_id text NOT NULL,
    match_id uuid,
    selection text NOT NULL,
    amount bigint NOT NULL,
    locked_odds numeric NOT NULL,
    status text DEFAULT 'pending'::text,
    created_at timestamp with time zone DEFAULT now()
);

-- TABLE: marino_sports_matches
CREATE TABLE public.marino_sports_matches (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    home_team_id integer,
    away_team_id integer,
    start_time timestamp with time zone NOT NULL,
    duration_secs integer DEFAULT 300,
    events jsonb DEFAULT '[]'::jsonb,
    is_finished boolean DEFAULT false
);

-- TABLE: marino_sports_players
CREATE TABLE public.marino_sports_players (
    id integer NOT NULL,
    team_id integer,
    name text NOT NULL,
    "position" text NOT NULL,
    overall integer NOT NULL
);

-- TABLE: marino_sports_teams
CREATE TABLE public.marino_sports_teams (
    id integer NOT NULL,
    name text NOT NULL,
    logo_url text DEFAULT ''::text,
    power_rating integer NOT NULL
);

-- TABLE: marino_store_items
CREATE TABLE public.marino_store_items (
    id integer NOT NULL,
    item_code text NOT NULL,
    item_name text NOT NULL,
    description text DEFAULT ''::text,
    cost_coin bigint DEFAULT 0,
    cost_token integer DEFAULT 0,
    cooldown_hours integer DEFAULT 24,
    min_level integer DEFAULT 1,
    is_active boolean DEFAULT true,
    sort_order integer DEFAULT 0
);

-- TABLE: marino_task_claims
CREATE TABLE public.marino_task_claims (
    telegram_id text NOT NULL,
    task_id text NOT NULL,
    level_no integer NOT NULL,
    reward_coin numeric DEFAULT 0 NOT NULL,
    created_at timestamp with time zone DEFAULT now(),
    task_level integer DEFAULT 1,
    reward_token integer DEFAULT 0
);

-- TABLE: marino_tasks
CREATE TABLE public.marino_tasks (
    id integer NOT NULL,
    task_key text NOT NULL,
    task_name text NOT NULL,
    description text DEFAULT ''::text,
    task_type text DEFAULT 'level'::text,
    reward_coin bigint DEFAULT 0,
    reward_token integer DEFAULT 0,
    reward_xp bigint DEFAULT 0,
    required_level integer DEFAULT 1,
    sort_order integer DEFAULT 0,
    is_active boolean DEFAULT true,
    CONSTRAINT marino_tasks_task_type_check CHECK ((task_type = ANY (ARRAY['daily'::text, 'weekly'::text, 'level'::text, 'achievement'::text, 'event'::text])))
);

-- TABLE: marino_wallets
CREATE TABLE public.marino_wallets (
    telegram_id text NOT NULL,
    ton_address text,
    connected_at timestamp with time zone DEFAULT now(),
    airdrop_eligible boolean DEFAULT false,
    updated_at timestamp with time zone DEFAULT now()
);

-- SEQUENCE: marino_achievements_id_seq
CREATE SEQUENCE public.marino_achievements_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;

-- SEQUENCE: marino_buildings_id_seq
CREATE SEQUENCE public.marino_buildings_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;

-- SEQUENCE: marino_daily_cipher_id_seq
CREATE SEQUENCE public.marino_daily_cipher_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;

-- SEQUENCE: marino_daily_combo_id_seq
CREATE SEQUENCE public.marino_daily_combo_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;

-- SEQUENCE: marino_daily_login_id_seq
CREATE SEQUENCE public.marino_daily_login_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;

-- SEQUENCE: marino_player_achievements_id_seq
CREATE SEQUENCE public.marino_player_achievements_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;

-- SEQUENCE: marino_player_buildings_id_seq
CREATE SEQUENCE public.marino_player_buildings_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;

-- SEQUENCE: marino_player_seasons_id_seq
CREATE SEQUENCE public.marino_player_seasons_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;

-- SEQUENCE: marino_player_tasks_id_seq
CREATE SEQUENCE public.marino_player_tasks_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;

-- SEQUENCE: marino_players_id_seq
CREATE SEQUENCE public.marino_players_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;

-- SEQUENCE: marino_reward_requests_id_seq
CREATE SEQUENCE public.marino_reward_requests_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;

-- SEQUENCE: marino_seasons_id_seq
CREATE SEQUENCE public.marino_seasons_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;

-- SEQUENCE: marino_sink_purchases_id_seq
CREATE SEQUENCE public.marino_sink_purchases_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;

-- SEQUENCE: marino_sports_players_id_seq
CREATE SEQUENCE public.marino_sports_players_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;

-- SEQUENCE: marino_sports_teams_id_seq
CREATE SEQUENCE public.marino_sports_teams_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;

-- SEQUENCE: marino_store_items_id_seq
CREATE SEQUENCE public.marino_store_items_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;

-- SEQUENCE: marino_tasks_id_seq
CREATE SEQUENCE public.marino_tasks_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;

-- SEQUENCE OWNED BY: marino_achievements_id_seq
ALTER SEQUENCE public.marino_achievements_id_seq OWNED BY public.marino_achievements.id;

-- SEQUENCE OWNED BY: marino_buildings_id_seq
ALTER SEQUENCE public.marino_buildings_id_seq OWNED BY public.marino_buildings.id;

-- SEQUENCE OWNED BY: marino_daily_cipher_id_seq
ALTER SEQUENCE public.marino_daily_cipher_id_seq OWNED BY public.marino_daily_cipher.id;

-- SEQUENCE OWNED BY: marino_daily_combo_id_seq
ALTER SEQUENCE public.marino_daily_combo_id_seq OWNED BY public.marino_daily_combo.id;

-- SEQUENCE OWNED BY: marino_daily_login_id_seq
ALTER SEQUENCE public.marino_daily_login_id_seq OWNED BY public.marino_daily_login.id;

-- SEQUENCE OWNED BY: marino_player_achievements_id_seq
ALTER SEQUENCE public.marino_player_achievements_id_seq OWNED BY public.marino_player_achievements.id;

-- SEQUENCE OWNED BY: marino_player_buildings_id_seq
ALTER SEQUENCE public.marino_player_buildings_id_seq OWNED BY public.marino_player_buildings.id;

-- SEQUENCE OWNED BY: marino_player_seasons_id_seq
ALTER SEQUENCE public.marino_player_seasons_id_seq OWNED BY public.marino_player_seasons.id;

-- SEQUENCE OWNED BY: marino_player_tasks_id_seq
ALTER SEQUENCE public.marino_player_tasks_id_seq OWNED BY public.marino_player_tasks.id;

-- SEQUENCE OWNED BY: marino_players_id_seq
ALTER SEQUENCE public.marino_players_id_seq OWNED BY public.marino_players.id;

-- SEQUENCE OWNED BY: marino_reward_requests_id_seq
ALTER SEQUENCE public.marino_reward_requests_id_seq OWNED BY public.marino_reward_requests.id;

-- SEQUENCE OWNED BY: marino_seasons_id_seq
ALTER SEQUENCE public.marino_seasons_id_seq OWNED BY public.marino_seasons.id;

-- SEQUENCE OWNED BY: marino_sink_purchases_id_seq
ALTER SEQUENCE public.marino_sink_purchases_id_seq OWNED BY public.marino_sink_purchases.id;

-- SEQUENCE OWNED BY: marino_sports_players_id_seq
ALTER SEQUENCE public.marino_sports_players_id_seq OWNED BY public.marino_sports_players.id;

-- SEQUENCE OWNED BY: marino_sports_teams_id_seq
ALTER SEQUENCE public.marino_sports_teams_id_seq OWNED BY public.marino_sports_teams.id;

-- SEQUENCE OWNED BY: marino_store_items_id_seq
ALTER SEQUENCE public.marino_store_items_id_seq OWNED BY public.marino_store_items.id;

-- SEQUENCE OWNED BY: marino_tasks_id_seq
ALTER SEQUENCE public.marino_tasks_id_seq OWNED BY public.marino_tasks.id;

-- DEFAULT: marino_achievements id
ALTER TABLE ONLY public.marino_achievements ALTER COLUMN id SET DEFAULT nextval('public.marino_achievements_id_seq'::regclass);

-- DEFAULT: marino_buildings id
ALTER TABLE ONLY public.marino_buildings ALTER COLUMN id SET DEFAULT nextval('public.marino_buildings_id_seq'::regclass);

-- DEFAULT: marino_daily_cipher id
ALTER TABLE ONLY public.marino_daily_cipher ALTER COLUMN id SET DEFAULT nextval('public.marino_daily_cipher_id_seq'::regclass);

-- DEFAULT: marino_daily_combo id
ALTER TABLE ONLY public.marino_daily_combo ALTER COLUMN id SET DEFAULT nextval('public.marino_daily_combo_id_seq'::regclass);

-- DEFAULT: marino_daily_login id
ALTER TABLE ONLY public.marino_daily_login ALTER COLUMN id SET DEFAULT nextval('public.marino_daily_login_id_seq'::regclass);

-- DEFAULT: marino_player_achievements id
ALTER TABLE ONLY public.marino_player_achievements ALTER COLUMN id SET DEFAULT nextval('public.marino_player_achievements_id_seq'::regclass);

-- DEFAULT: marino_player_buildings id
ALTER TABLE ONLY public.marino_player_buildings ALTER COLUMN id SET DEFAULT nextval('public.marino_player_buildings_id_seq'::regclass);

-- DEFAULT: marino_player_seasons id
ALTER TABLE ONLY public.marino_player_seasons ALTER COLUMN id SET DEFAULT nextval('public.marino_player_seasons_id_seq'::regclass);

-- DEFAULT: marino_player_tasks id
ALTER TABLE ONLY public.marino_player_tasks ALTER COLUMN id SET DEFAULT nextval('public.marino_player_tasks_id_seq'::regclass);

-- DEFAULT: marino_players id
ALTER TABLE ONLY public.marino_players ALTER COLUMN id SET DEFAULT nextval('public.marino_players_id_seq'::regclass);

-- DEFAULT: marino_reward_requests id
ALTER TABLE ONLY public.marino_reward_requests ALTER COLUMN id SET DEFAULT nextval('public.marino_reward_requests_id_seq'::regclass);

-- DEFAULT: marino_seasons id
ALTER TABLE ONLY public.marino_seasons ALTER COLUMN id SET DEFAULT nextval('public.marino_seasons_id_seq'::regclass);

-- DEFAULT: marino_sink_purchases id
ALTER TABLE ONLY public.marino_sink_purchases ALTER COLUMN id SET DEFAULT nextval('public.marino_sink_purchases_id_seq'::regclass);

-- DEFAULT: marino_sports_players id
ALTER TABLE ONLY public.marino_sports_players ALTER COLUMN id SET DEFAULT nextval('public.marino_sports_players_id_seq'::regclass);

-- DEFAULT: marino_sports_teams id
ALTER TABLE ONLY public.marino_sports_teams ALTER COLUMN id SET DEFAULT nextval('public.marino_sports_teams_id_seq'::regclass);

-- DEFAULT: marino_store_items id
ALTER TABLE ONLY public.marino_store_items ALTER COLUMN id SET DEFAULT nextval('public.marino_store_items_id_seq'::regclass);

-- DEFAULT: marino_tasks id
ALTER TABLE ONLY public.marino_tasks ALTER COLUMN id SET DEFAULT nextval('public.marino_tasks_id_seq'::regclass);

-- CONSTRAINT: marino_achievements marino_achievements_achievement_key_key
ALTER TABLE ONLY public.marino_achievements
    ADD CONSTRAINT marino_achievements_achievement_key_key UNIQUE (achievement_key);

-- CONSTRAINT: marino_achievements marino_achievements_pkey
ALTER TABLE ONLY public.marino_achievements
    ADD CONSTRAINT marino_achievements_pkey PRIMARY KEY (id);

-- CONSTRAINT: marino_ad_reward_logs marino_ad_reward_logs_pkey
ALTER TABLE ONLY public.marino_ad_reward_logs
    ADD CONSTRAINT marino_ad_reward_logs_pkey PRIMARY KEY (id);

-- CONSTRAINT: marino_ad_reward_logs marino_ad_reward_logs_request_id_key
ALTER TABLE ONLY public.marino_ad_reward_logs
    ADD CONSTRAINT marino_ad_reward_logs_request_id_key UNIQUE (request_id);

-- CONSTRAINT: marino_buildings marino_buildings_building_key_key
ALTER TABLE ONLY public.marino_buildings
    ADD CONSTRAINT marino_buildings_building_key_key UNIQUE (building_key);

-- CONSTRAINT: marino_buildings marino_buildings_pkey
ALTER TABLE ONLY public.marino_buildings
    ADD CONSTRAINT marino_buildings_pkey PRIMARY KEY (id);

-- CONSTRAINT: marino_daily_cipher marino_daily_cipher_pkey
ALTER TABLE ONLY public.marino_daily_cipher
    ADD CONSTRAINT marino_daily_cipher_pkey PRIMARY KEY (id);

-- CONSTRAINT: marino_daily_cipher marino_daily_cipher_telegram_id_cipher_date_key
ALTER TABLE ONLY public.marino_daily_cipher
    ADD CONSTRAINT marino_daily_cipher_telegram_id_cipher_date_key UNIQUE (telegram_id, cipher_date);

-- CONSTRAINT: marino_daily_combo marino_daily_combo_pkey
ALTER TABLE ONLY public.marino_daily_combo
    ADD CONSTRAINT marino_daily_combo_pkey PRIMARY KEY (id);

-- CONSTRAINT: marino_daily_combo marino_daily_combo_telegram_id_combo_date_key
ALTER TABLE ONLY public.marino_daily_combo
    ADD CONSTRAINT marino_daily_combo_telegram_id_combo_date_key UNIQUE (telegram_id, combo_date);

-- CONSTRAINT: marino_daily_login marino_daily_login_pkey
ALTER TABLE ONLY public.marino_daily_login
    ADD CONSTRAINT marino_daily_login_pkey PRIMARY KEY (id);

-- CONSTRAINT: marino_daily_login marino_daily_login_player_id_key
ALTER TABLE ONLY public.marino_daily_login
    ADD CONSTRAINT marino_daily_login_player_id_key UNIQUE (player_id);

-- CONSTRAINT: marino_player_achievements marino_player_achievements_pkey
ALTER TABLE ONLY public.marino_player_achievements
    ADD CONSTRAINT marino_player_achievements_pkey PRIMARY KEY (id);

-- CONSTRAINT: marino_player_achievements marino_player_achievements_player_id_achievement_key_key
ALTER TABLE ONLY public.marino_player_achievements
    ADD CONSTRAINT marino_player_achievements_player_id_achievement_key_key UNIQUE (player_id, achievement_key);

-- CONSTRAINT: marino_player_boosts marino_player_boosts_pkey
ALTER TABLE ONLY public.marino_player_boosts
    ADD CONSTRAINT marino_player_boosts_pkey PRIMARY KEY (telegram_id);

-- CONSTRAINT: marino_player_buildings marino_player_buildings_pkey
ALTER TABLE ONLY public.marino_player_buildings
    ADD CONSTRAINT marino_player_buildings_pkey PRIMARY KEY (id);

-- CONSTRAINT: marino_player_buildings marino_player_buildings_player_id_building_key_key
ALTER TABLE ONLY public.marino_player_buildings
    ADD CONSTRAINT marino_player_buildings_player_id_building_key_key UNIQUE (player_id, building_key);

-- CONSTRAINT: marino_player_seasons marino_player_seasons_pkey
ALTER TABLE ONLY public.marino_player_seasons
    ADD CONSTRAINT marino_player_seasons_pkey PRIMARY KEY (id);

-- CONSTRAINT: marino_player_seasons marino_player_seasons_player_id_season_key_key
ALTER TABLE ONLY public.marino_player_seasons
    ADD CONSTRAINT marino_player_seasons_player_id_season_key_key UNIQUE (player_id, season_key);

-- CONSTRAINT: marino_player_tasks marino_player_tasks_pkey
ALTER TABLE ONLY public.marino_player_tasks
    ADD CONSTRAINT marino_player_tasks_pkey PRIMARY KEY (id);

-- CONSTRAINT: marino_player_tasks marino_player_tasks_player_id_task_key_key
ALTER TABLE ONLY public.marino_player_tasks
    ADD CONSTRAINT marino_player_tasks_player_id_task_key_key UNIQUE (player_id, task_key);

-- CONSTRAINT: marino_players marino_players_pkey
ALTER TABLE ONLY public.marino_players
    ADD CONSTRAINT marino_players_pkey PRIMARY KEY (id);

-- CONSTRAINT: marino_players marino_players_telegram_id_key
ALTER TABLE ONLY public.marino_players
    ADD CONSTRAINT marino_players_telegram_id_key UNIQUE (telegram_id);

-- CONSTRAINT: marino_processed_requests marino_processed_requests_pkey
ALTER TABLE ONLY public.marino_processed_requests
    ADD CONSTRAINT marino_processed_requests_pkey PRIMARY KEY (request_id);

-- CONSTRAINT: marino_reward_requests marino_reward_requests_pkey
ALTER TABLE ONLY public.marino_reward_requests
    ADD CONSTRAINT marino_reward_requests_pkey PRIMARY KEY (id);

-- CONSTRAINT: marino_seasons marino_seasons_pkey
ALTER TABLE ONLY public.marino_seasons
    ADD CONSTRAINT marino_seasons_pkey PRIMARY KEY (id);

-- CONSTRAINT: marino_seasons marino_seasons_season_key_key
ALTER TABLE ONLY public.marino_seasons
    ADD CONSTRAINT marino_seasons_season_key_key UNIQUE (season_key);

-- CONSTRAINT: marino_sink_purchases marino_sink_purchases_pkey
ALTER TABLE ONLY public.marino_sink_purchases
    ADD CONSTRAINT marino_sink_purchases_pkey PRIMARY KEY (id);

-- CONSTRAINT: marino_sports_coupons marino_sports_coupons_pkey
ALTER TABLE ONLY public.marino_sports_coupons
    ADD CONSTRAINT marino_sports_coupons_pkey PRIMARY KEY (id);

-- CONSTRAINT: marino_sports_matches marino_sports_matches_pkey
ALTER TABLE ONLY public.marino_sports_matches
    ADD CONSTRAINT marino_sports_matches_pkey PRIMARY KEY (id);

-- CONSTRAINT: marino_sports_players marino_sports_players_pkey
ALTER TABLE ONLY public.marino_sports_players
    ADD CONSTRAINT marino_sports_players_pkey PRIMARY KEY (id);

-- CONSTRAINT: marino_sports_teams marino_sports_teams_pkey
ALTER TABLE ONLY public.marino_sports_teams
    ADD CONSTRAINT marino_sports_teams_pkey PRIMARY KEY (id);

-- CONSTRAINT: marino_store_items marino_store_items_item_code_key
ALTER TABLE ONLY public.marino_store_items
    ADD CONSTRAINT marino_store_items_item_code_key UNIQUE (item_code);

-- CONSTRAINT: marino_store_items marino_store_items_pkey
ALTER TABLE ONLY public.marino_store_items
    ADD CONSTRAINT marino_store_items_pkey PRIMARY KEY (id);

-- CONSTRAINT: marino_task_claims marino_task_claims_pkey
ALTER TABLE ONLY public.marino_task_claims
    ADD CONSTRAINT marino_task_claims_pkey PRIMARY KEY (telegram_id, task_id);

-- CONSTRAINT: marino_tasks marino_tasks_pkey
ALTER TABLE ONLY public.marino_tasks
    ADD CONSTRAINT marino_tasks_pkey PRIMARY KEY (id);

-- CONSTRAINT: marino_tasks marino_tasks_task_key_key
ALTER TABLE ONLY public.marino_tasks
    ADD CONSTRAINT marino_tasks_task_key_key UNIQUE (task_key);

-- CONSTRAINT: marino_wallets marino_wallets_pkey
ALTER TABLE ONLY public.marino_wallets
    ADD CONSTRAINT marino_wallets_pkey PRIMARY KEY (telegram_id);

-- INDEX: idx_marino_cipher_player
CREATE INDEX idx_marino_cipher_player ON public.marino_daily_cipher USING btree (telegram_id, cipher_date DESC);

-- INDEX: idx_marino_combo_player
CREATE INDEX idx_marino_combo_player ON public.marino_daily_combo USING btree (telegram_id, combo_date DESC);

-- INDEX: idx_pb_player
CREATE INDEX idx_pb_player ON public.marino_player_buildings USING btree (player_id);

-- INDEX: idx_players_country
CREATE INDEX idx_players_country ON public.marino_players USING btree (country_code);

-- INDEX: idx_players_level
CREATE INDEX idx_players_level ON public.marino_players USING btree (casino_level DESC, reputation DESC);

-- INDEX: idx_players_telegram
CREATE INDEX idx_players_telegram ON public.marino_players USING btree (telegram_id);

-- INDEX: idx_pt_player
CREATE INDEX idx_pt_player ON public.marino_player_tasks USING btree (player_id);

-- INDEX: idx_rr_player
CREATE INDEX idx_rr_player ON public.marino_reward_requests USING btree (player_id);

-- INDEX: idx_rr_status
CREATE INDEX idx_rr_status ON public.marino_reward_requests USING btree (status);

-- INDEX: idx_rr_telegram
CREATE INDEX idx_rr_telegram ON public.marino_reward_requests USING btree (telegram_id);

-- FK CONSTRAINT: marino_daily_login marino_daily_login_player_id_fkey
ALTER TABLE ONLY public.marino_daily_login
    ADD CONSTRAINT marino_daily_login_player_id_fkey FOREIGN KEY (player_id) REFERENCES public.marino_players(id) ON DELETE CASCADE;

-- FK CONSTRAINT: marino_player_achievements marino_player_achievements_achievement_key_fkey
ALTER TABLE ONLY public.marino_player_achievements
    ADD CONSTRAINT marino_player_achievements_achievement_key_fkey FOREIGN KEY (achievement_key) REFERENCES public.marino_achievements(achievement_key);

-- FK CONSTRAINT: marino_player_achievements marino_player_achievements_player_id_fkey
ALTER TABLE ONLY public.marino_player_achievements
    ADD CONSTRAINT marino_player_achievements_player_id_fkey FOREIGN KEY (player_id) REFERENCES public.marino_players(id) ON DELETE CASCADE;

-- FK CONSTRAINT: marino_player_buildings marino_player_buildings_building_key_fkey
ALTER TABLE ONLY public.marino_player_buildings
    ADD CONSTRAINT marino_player_buildings_building_key_fkey FOREIGN KEY (building_key) REFERENCES public.marino_buildings(building_key);

-- FK CONSTRAINT: marino_player_buildings marino_player_buildings_player_id_fkey
ALTER TABLE ONLY public.marino_player_buildings
    ADD CONSTRAINT marino_player_buildings_player_id_fkey FOREIGN KEY (player_id) REFERENCES public.marino_players(id) ON DELETE CASCADE;

-- FK CONSTRAINT: marino_player_seasons marino_player_seasons_player_id_fkey
ALTER TABLE ONLY public.marino_player_seasons
    ADD CONSTRAINT marino_player_seasons_player_id_fkey FOREIGN KEY (player_id) REFERENCES public.marino_players(id) ON DELETE CASCADE;

-- FK CONSTRAINT: marino_player_tasks marino_player_tasks_player_id_fkey
ALTER TABLE ONLY public.marino_player_tasks
    ADD CONSTRAINT marino_player_tasks_player_id_fkey FOREIGN KEY (player_id) REFERENCES public.marino_players(id) ON DELETE CASCADE;

-- FK CONSTRAINT: marino_reward_requests marino_reward_requests_player_id_fkey
ALTER TABLE ONLY public.marino_reward_requests
    ADD CONSTRAINT marino_reward_requests_player_id_fkey FOREIGN KEY (player_id) REFERENCES public.marino_players(id) ON DELETE CASCADE;

-- FK CONSTRAINT: marino_sports_coupons marino_sports_coupons_match_id_fkey
ALTER TABLE ONLY public.marino_sports_coupons
    ADD CONSTRAINT marino_sports_coupons_match_id_fkey FOREIGN KEY (match_id) REFERENCES public.marino_sports_matches(id);

-- FK CONSTRAINT: marino_sports_matches marino_sports_matches_away_team_id_fkey
ALTER TABLE ONLY public.marino_sports_matches
    ADD CONSTRAINT marino_sports_matches_away_team_id_fkey FOREIGN KEY (away_team_id) REFERENCES public.marino_sports_teams(id);

-- FK CONSTRAINT: marino_sports_matches marino_sports_matches_home_team_id_fkey
ALTER TABLE ONLY public.marino_sports_matches
    ADD CONSTRAINT marino_sports_matches_home_team_id_fkey FOREIGN KEY (home_team_id) REFERENCES public.marino_sports_teams(id);

-- FK CONSTRAINT: marino_sports_players marino_sports_players_team_id_fkey
ALTER TABLE ONLY public.marino_sports_players
    ADD CONSTRAINT marino_sports_players_team_id_fkey FOREIGN KEY (team_id) REFERENCES public.marino_sports_teams(id) ON DELETE CASCADE;

-- ROW SECURITY: marino_achievements
ALTER TABLE public.marino_achievements ENABLE ROW LEVEL SECURITY;

-- ROW SECURITY: marino_ad_reward_logs
ALTER TABLE public.marino_ad_reward_logs ENABLE ROW LEVEL SECURITY;

-- ROW SECURITY: marino_buildings
ALTER TABLE public.marino_buildings ENABLE ROW LEVEL SECURITY;

-- ROW SECURITY: marino_daily_cipher
ALTER TABLE public.marino_daily_cipher ENABLE ROW LEVEL SECURITY;

-- ROW SECURITY: marino_daily_combo
ALTER TABLE public.marino_daily_combo ENABLE ROW LEVEL SECURITY;

-- ROW SECURITY: marino_daily_login
ALTER TABLE public.marino_daily_login ENABLE ROW LEVEL SECURITY;

-- ROW SECURITY: marino_player_achievements
ALTER TABLE public.marino_player_achievements ENABLE ROW LEVEL SECURITY;

-- ROW SECURITY: marino_player_boosts
ALTER TABLE public.marino_player_boosts ENABLE ROW LEVEL SECURITY;

-- ROW SECURITY: marino_player_buildings
ALTER TABLE public.marino_player_buildings ENABLE ROW LEVEL SECURITY;

-- ROW SECURITY: marino_player_seasons
ALTER TABLE public.marino_player_seasons ENABLE ROW LEVEL SECURITY;

-- ROW SECURITY: marino_player_tasks
ALTER TABLE public.marino_player_tasks ENABLE ROW LEVEL SECURITY;

-- ROW SECURITY: marino_players
ALTER TABLE public.marino_players ENABLE ROW LEVEL SECURITY;

-- ROW SECURITY: marino_processed_requests
ALTER TABLE public.marino_processed_requests ENABLE ROW LEVEL SECURITY;

-- ROW SECURITY: marino_reward_requests
ALTER TABLE public.marino_reward_requests ENABLE ROW LEVEL SECURITY;

-- ROW SECURITY: marino_seasons
ALTER TABLE public.marino_seasons ENABLE ROW LEVEL SECURITY;

-- ROW SECURITY: marino_sink_purchases
ALTER TABLE public.marino_sink_purchases ENABLE ROW LEVEL SECURITY;

-- ROW SECURITY: marino_sports_coupons
ALTER TABLE public.marino_sports_coupons ENABLE ROW LEVEL SECURITY;

-- ROW SECURITY: marino_sports_matches
ALTER TABLE public.marino_sports_matches ENABLE ROW LEVEL SECURITY;

-- ROW SECURITY: marino_sports_players
ALTER TABLE public.marino_sports_players ENABLE ROW LEVEL SECURITY;

-- ROW SECURITY: marino_sports_teams
ALTER TABLE public.marino_sports_teams ENABLE ROW LEVEL SECURITY;

-- ROW SECURITY: marino_store_items
ALTER TABLE public.marino_store_items ENABLE ROW LEVEL SECURITY;

-- ROW SECURITY: marino_task_claims
ALTER TABLE public.marino_task_claims ENABLE ROW LEVEL SECURITY;

-- ROW SECURITY: marino_tasks
ALTER TABLE public.marino_tasks ENABLE ROW LEVEL SECURITY;

-- ROW SECURITY: marino_wallets
ALTER TABLE public.marino_wallets ENABLE ROW LEVEL SECURITY;


-- PostgreSQL database dump complete

\unrestrict LPtiTchaljY35j3U5fcQ8djasfedCEqUVv3pNP3ILczfA17F42Ac0OthjAREgnE

-- FUNCTION: _marino_ensure_boost(text)
CREATE FUNCTION public._marino_ensure_boost(p_telegram_id text) RETURNS void
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path = pg_catalog, public
    AS $$
BEGIN
  INSERT INTO marino_player_boosts(telegram_id) VALUES (p_telegram_id)
  ON CONFLICT (telegram_id) DO NOTHING;
  UPDATE marino_player_boosts
    SET full_energy_used = CASE WHEN full_energy_date = CURRENT_DATE THEN full_energy_used ELSE 0 END,
        full_energy_date = CURRENT_DATE,
        tap_boost_used = CASE WHEN tap_boost_date = CURRENT_DATE THEN tap_boost_used ELSE 0 END,
        tap_boost_date = CURRENT_DATE
    WHERE telegram_id = p_telegram_id;
END$$;

-- FUNCTION: _marino_next_cost(bigint, integer)
CREATE FUNCTION public._marino_next_cost(p_base bigint, p_level integer) RETURNS bigint
    LANGUAGE sql IMMUTABLE
    AS $$
  select greatest(
    1,
    floor(coalesce(p_base, 1)::numeric * power(greatest(coalesce(p_level, 1), 1)::numeric, 1.45))::bigint
  );
$$;

-- FUNCTION: _marino_recalc_income(text)
CREATE FUNCTION public._marino_recalc_income(p_telegram_id text) RETURNS void
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path = pg_catalog, public
    AS $$
declare
  v_income bigint;
begin
  select coalesce(sum(current_income_per_hour), 0)
  into v_income
  from public.marino_player_buildings
  where telegram_id = p_telegram_id;

  update public.marino_players
  set
    passive_income_per_hour = greatest(v_income, 0),
    casino_level = greatest(1, floor(greatest(v_income, 1)::numeric / 180)::integer),
    reputation = greatest(0, floor(greatest(v_income, 1)::numeric / 12)::integer),
    updated_at = now()
  where telegram_id = p_telegram_id;
end;
$$;

-- FUNCTION: _marino_refresh_energy(text)
CREATE FUNCTION public._marino_refresh_energy(p_telegram_id text) RETURNS void
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path = pg_catalog, public
    AS $$
declare
  v_player public.marino_players%rowtype;
  v_add integer;
  v_new_energy integer;
begin
  select *
  into v_player
  from public.marino_players
  where telegram_id = p_telegram_id
  for update;

  if not found then
    return;
  end if;

  if v_player.energy >= v_player.max_energy then
    update public.marino_players
    set last_energy_at = now()
    where telegram_id = p_telegram_id;
    return;
  end if;

  v_add := floor(extract(epoch from (now() - v_player.last_energy_at)) / 45)::integer;

  if v_add <= 0 then
    return;
  end if;

  v_new_energy := least(v_player.max_energy, v_player.energy + v_add);

  update public.marino_players
  set
    energy = v_new_energy,
    last_energy_at = case
      when v_new_energy >= v_player.max_energy then now()
      else v_player.last_energy_at + (v_add * interval '45 seconds')
    end,
    updated_at = now()
  where telegram_id = p_telegram_id;
end;
$$;

-- FUNCTION: _marino_rpc_id(text)
CREATE FUNCTION public._marino_rpc_id(p_value text) RETURNS bigint
    LANGUAGE plpgsql IMMUTABLE
    AS $_$
begin
  if p_value is null or trim(p_value) = '' then
    return 0;
  end if;

  -- Telegram gerçek ID ise direkt bigint kullan
  if p_value ~ '^[0-9]+$' then
    return p_value::bigint;
  end if;

  -- WEB_ gibi test id ise sabit numeric id üret
  return abs(hashtext(p_value)::bigint);
end;
$_$;

-- FUNCTION: _marino_seed_buildings(text)
CREATE FUNCTION public._marino_seed_buildings(p_telegram_id text) RETURNS void
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path = pg_catalog, public
    AS $$
begin
  insert into public.marino_player_buildings
    (
      telegram_id,
      building_key,
      building_name,
      level,
      base_cost_coin,
      base_income_per_hour,
      current_income_per_hour,
      sort_order
    )
  values
    (p_telegram_id, 'casino_lobby', 'Casino Lobby', 1, 500, 60, 60, 1),
    (p_telegram_id, 'slot_area', 'Slot Alanı', 1, 650, 90, 90, 2),
    (p_telegram_id, 'sportsbook_area', 'Sportsbook Alanı', 1, 700, 75, 75, 3),
    (p_telegram_id, 'vip_casino', 'VIP Casino', 1, 900, 55, 55, 4),
    (p_telegram_id, 'rewards_office', 'Ödül Mağazası', 1, 800, 40, 40, 5),
    (p_telegram_id, 'admin_control', 'Admin Kontrol Merkezi', 1, 1000, 40, 40, 6)
  on conflict (telegram_id, building_key) do nothing;
end;
$$;

-- FUNCTION: _marino_seed_store()
CREATE FUNCTION public._marino_seed_store() RETURNS void
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path = pg_catalog, public
    AS $$
begin
  insert into public.marino_store_items
    (item_code, item_name, category, cost_coin, cost_token, description, active, sort_order)
  values
    (
      'FREE_SPIN_25',
      '25 Free Spin',
      'reward',
      2500,
      100,
      'Admin onaylı Free Spin talebi oluşturur.',
      true,
      1
    ),
    (
      'FREEBET_100',
      '100 TL Freebet',
      'reward',
      4000,
      150,
      'Admin onaylı Freebet talebi oluşturur.',
      true,
      2
    ),
    (
      'FREE_SPIN_100',
      '100 Free Spin',
      'reward',
      8500,
      300,
      'Yüksek seviye Free Spin talebi oluşturur.',
      true,
      3
    )
  on conflict (item_code) do update set
    item_name = excluded.item_name,
    category = excluded.category,
    cost_coin = excluded.cost_coin,
    cost_token = excluded.cost_token,
    description = excluded.description,
    active = excluded.active,
    sort_order = excluded.sort_order;
end;
$$;

-- FUNCTION: _marino_state(text)
CREATE FUNCTION public._marino_state(p_telegram_id text) RETURNS jsonb
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path = pg_catalog, public
    AS $$
declare
  v_player public.marino_players%rowtype;
  v_claimable_coin bigint;
  v_last_reward_status text;
begin
  perform public._marino_seed_store();
  perform public._marino_seed_buildings(p_telegram_id);
  perform public._marino_recalc_income(p_telegram_id);
  perform public._marino_refresh_energy(p_telegram_id);

  select *
  into v_player
  from public.marino_players
  where telegram_id = p_telegram_id;

  if not found then
    raise exception 'Oyuncu bulunamadı';
  end if;

  v_claimable_coin :=
    greatest(
      0,
      floor(
        extract(epoch from (now() - v_player.last_income_at))
        * v_player.passive_income_per_hour::numeric
        / 3600
      )::bigint
    );

  select r.status
  into v_last_reward_status
  from public.marino_reward_requests r
  where r.telegram_id = p_telegram_id
  order by r.created_at desc
  limit 1;

  return jsonb_build_object(
    'user',
      jsonb_build_object(
        'telegram_id', v_player.telegram_id,
        'telegram_username', v_player.telegram_username,
        'first_name', v_player.first_name,
        'last_name', v_player.last_name,
        'site_username', v_player.site_username,
        'is_admin', v_player.is_admin
      ),

    'state',
      to_jsonb(v_player) || jsonb_build_object(
        'claimable_coin', v_claimable_coin
      ),

    'upgrades',
      coalesce(
        (
          select jsonb_agg(
            to_jsonb(b) || jsonb_build_object(
              'next_cost_coin',
              public._marino_next_cost(b.base_cost_coin, b.level)
            )
            order by b.sort_order
          )
          from public.marino_player_buildings b
          where b.telegram_id = p_telegram_id
        ),
        '[]'::jsonb
      ),

    'store',
      coalesce(
        (
          select jsonb_agg(to_jsonb(s) order by s.sort_order)
          from public.marino_store_items s
          where s.active = true
        ),
        '[]'::jsonb
      ),

    'leaderboard',
      coalesce(
        (
          select jsonb_agg(x order by x.rank_no)
          from (
            select
              row_number() over (order by p.season_points desc, p.marino_coin desc) as rank_no,
              coalesce(nullif(p.telegram_username, ''), nullif(p.site_username, ''), p.first_name, 'Oyuncu') as display_name,
              p.site_username,
              p.casino_level,
              p.reputation,
              p.season_points
            from public.marino_players p
            order by p.season_points desc, p.marino_coin desc
            limit 10
          ) x
        ),
        '[]'::jsonb
      ),

    'reward_request_status',
      v_last_reward_status
  );
end;
$$;

-- FUNCTION: calc_building_cost(bigint, numeric, integer)
CREATE FUNCTION public.calc_building_cost(p_base_cost bigint, p_multiplier numeric, p_level integer) RETURNS bigint
    LANGUAGE sql IMMUTABLE
    AS $$
  select greatest(
    0,
    ceiling(coalesce(p_base_cost, 0)::numeric * power(coalesce(p_multiplier, 1.65), greatest(coalesce(p_level, 0), 0)))::bigint
  );
$$;

-- FUNCTION: collect_income(text, text)
CREATE FUNCTION public.collect_income(p_telegram_id text, p_request_id text DEFAULT ''::text) RETURNS jsonb
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path = pg_catalog, public
    AS $$
DECLARE
  v_player marino_players%ROWTYPE;
  v_collected BIGINT;
BEGIN
  -- Çift tıklama koruması
  IF p_request_id != '' THEN
    INSERT INTO marino_processed_requests (request_id) VALUES (p_request_id)
    ON CONFLICT DO NOTHING;
    IF NOT FOUND THEN
      RAISE EXCEPTION 'Bu işlem zaten işlendi.';
    END IF;
  END IF;

  SELECT * INTO v_player FROM marino_players WHERE telegram_id = p_telegram_id;
  IF NOT FOUND THEN RAISE EXCEPTION 'Oyuncu bulunamadı.'; END IF;

  -- Çevrimdışı birikimi hesapla
  DECLARE
    v_hours NUMERIC;
    v_new_income BIGINT;
  BEGIN
    v_hours := LEAST(
      v_player.offline_capacity_hours,
      EXTRACT(EPOCH FROM (NOW() - v_player.last_income_collect)) / 3600.0
    );
    v_new_income := FLOOR(v_player.passive_income_per_hour * v_hours);
    v_collected := v_player.claimable_coin + v_new_income;
  END;

  IF v_collected <= 0 THEN
    RAISE EXCEPTION 'Toplanacak gelir yok. Bina yükselt veya biraz bekle.';
  END IF;

  UPDATE marino_players SET
    marino_coin = marino_coin + v_collected,
    claimable_coin = 0,
    last_income_collect = NOW(),
    updated_at = NOW()
  WHERE id = v_player.id
  RETURNING * INTO v_player;

  RETURN jsonb_build_object(
    'state', jsonb_build_object(
      'marino_coin', v_player.marino_coin,
      'reward_token', v_player.reward_token,
      'energy', v_player.energy,
      'max_energy', v_player.max_energy,
      'tap_power', v_player.tap_power,
      'passive_income_per_hour', v_player.passive_income_per_hour,
      'casino_level', v_player.casino_level,
      'reputation', v_player.reputation,
      'claimable_coin', v_player.claimable_coin,
      'offline_capacity_hours', v_player.offline_capacity_hours,
      'prestige_points', v_player.prestige_points
    ),
    'collected', v_collected
  );
END;
$$;

-- FUNCTION: get_game_state(text)
CREATE FUNCTION public.get_game_state(p_telegram_id text) RETURNS jsonb
    LANGUAGE sql SECURITY DEFINER
    SET search_path = pg_catalog, public
    AS $$
  select public._marino_state(p_telegram_id);
$$;

-- FUNCTION: marino_activate_auto_tap(text)
CREATE FUNCTION public.marino_activate_auto_tap(p_telegram_id text) RETURNS jsonb
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path = pg_catalog, public
    AS $$
DECLARE p marino_players; cost bigint := 5000;
BEGIN
  PERFORM _marino_ensure_boost(p_telegram_id);
  SELECT * INTO p FROM marino_players WHERE telegram_id = p_telegram_id FOR UPDATE;
  IF p.marino_coin < cost THEN RETURN jsonb_build_object('ok',false,'error','insufficient_coin','cost',cost); END IF;
  UPDATE marino_players SET marino_coin = marino_coin - cost, updated_at = NOW() WHERE telegram_id = p_telegram_id;
  UPDATE marino_player_boosts SET auto_tap_until = NOW() + INTERVAL '12 hours', updated_at = NOW()
    WHERE telegram_id = p_telegram_id;
  RETURN jsonb_build_object('ok',true,'until', (NOW() + INTERVAL '12 hours'),'cost',cost);
END$$;

-- FUNCTION: marino_admin_get_requests(text)
CREATE FUNCTION public.marino_admin_get_requests(p_admin_id text) RETURNS jsonb
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path = pg_catalog, public
    AS $$
BEGIN
    RETURN (SELECT COALESCE(jsonb_agg(jsonb_build_object('req_id', r.id, 'user_id', r.telegram_id, 'name', r.display_name, 'item', r.item_code, 'status', r.status, 'date', r.created_at) ORDER BY r.created_at DESC), '[]'::jsonb) FROM public.marino_reward_requests r);
END;
$$;

-- FUNCTION: marino_admin_get_users(text)
CREATE FUNCTION public.marino_admin_get_users(p_admin_id text) RETURNS jsonb
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path = pg_catalog, public
    AS $$
BEGIN
    RETURN (SELECT COALESCE(jsonb_agg(
        jsonb_build_object(
            'id', u.telegram_id,
            'name', u.display_name,
            'banned', u.is_banned,
            'coin', u.marino_coin,
            'casino_chips', u.casino_chips,
            'level', u.casino_level,
            'energy', u.energy,
            'prestige', u.prestige_points  -- Doğru sütun adı bu kanka
        ) ORDER BY u.marino_coin DESC), '[]'::jsonb) FROM public.marino_players u);
END;
$$;

-- FUNCTION: marino_admin_resolve_request(text, integer, text)
CREATE FUNCTION public.marino_admin_resolve_request(p_admin_id text, p_req_id integer, p_action text) RETURNS text
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path = pg_catalog, public
    AS $$
BEGIN
    UPDATE public.marino_reward_requests SET status = p_action, updated_at = now() WHERE id = p_req_id AND status = 'pending';
    RETURN 'Başarılı';
END;
$$;

-- FUNCTION: marino_admin_resolve_request(text, integer, text, text)
CREATE FUNCTION public.marino_admin_resolve_request(p_admin_id text, p_req_id integer, p_action text, p_note text DEFAULT ''::text) RETURNS text
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path = pg_catalog, public
    AS $$
BEGIN
    UPDATE public.marino_reward_requests
    SET status = p_action,
        reviewed_at = now(),
        admin_note = p_note,
        is_read = false
    WHERE id = p_req_id AND status = 'pending';
    RETURN 'Başarılı';
END;
$$;

-- FUNCTION: marino_admin_toggle_ban(text, text)
CREATE FUNCTION public.marino_admin_toggle_ban(p_admin_id text, p_target_id text) RETURNS text
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path = pg_catalog, public
    AS $$
DECLARE v_stat boolean;
BEGIN
    UPDATE public.marino_players SET is_banned = NOT is_banned WHERE telegram_id = p_target_id RETURNING is_banned INTO v_stat;
    RETURN CASE WHEN v_stat THEN 'Banlandı' ELSE 'Ban Kaldırıldı' END;
END;
$$;

-- FUNCTION: marino_admin_update_user(text, text, bigint, bigint, integer)
CREATE FUNCTION public.marino_admin_update_user(p_admin_id text, p_target_id text, p_coin bigint, p_chips bigint, p_prestige integer) RETURNS void
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path = pg_catalog, public
    AS $$
BEGIN
  UPDATE public.marino_players
  SET marino_coin = p_coin,
      casino_chips = p_chips,
      prestige_points = p_prestige, -- Doğru sütun adı bu kanka
      updated_at = now()
  WHERE telegram_id = p_target_id;
END;
$$;

-- FUNCTION: marino_airdrop_status(text)
CREATE FUNCTION public.marino_airdrop_status(p_telegram_id text) RETURNS jsonb
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path = pg_catalog, public
    AS $$
DECLARE p marino_players; w marino_wallets;
BEGIN
  SELECT * INTO p FROM marino_players WHERE telegram_id = p_telegram_id;
  SELECT * INTO w FROM marino_wallets WHERE telegram_id = p_telegram_id;
  RETURN jsonb_build_object(
    'wallet_connected', w.ton_address IS NOT NULL,
    'ton_address', w.ton_address,
    'casino_level', COALESCE(p.casino_level, 0),
    'casino_chips', COALESCE(p.casino_chips, 0),
    'reputation', COALESCE(p.reputation, 0),
    'referrals', (SELECT COUNT(*) FROM marino_players WHERE referred_by = p_telegram_id),
    'tasks_completed', COALESCE(jsonb_array_length(to_jsonb(p.completed_tasks)), 0)
  );
END$$;

-- FUNCTION: marino_bj_deal(text, bigint)
CREATE FUNCTION public.marino_bj_deal(p_telegram_id text, p_bet_amount bigint) RETURNS jsonb
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path = pg_catalog, public
    AS $$
DECLARE
    v_player record;
    v_state jsonb;
    p_hand jsonb;
    d_hand jsonb;
    p_score int;
BEGIN
    SELECT * INTO v_player FROM public.marino_players WHERE telegram_id = p_telegram_id;
    IF NOT FOUND THEN RAISE EXCEPTION 'Oyuncu bulunamadı.'; END IF;

    -- Kullanıcının zaten aktif eli varsa ona dönemez (veya hata verelim ki yenilesin)
    IF v_player.active_game_state IS NOT NULL AND (v_player.active_game_state->>'status') = 'playing' THEN
        RETURN v_player.active_game_state;
    END IF;

    IF p_bet_amount <= 0 THEN RAISE EXCEPTION 'Geçerli bir bahis girin.'; END IF;
    IF COALESCE(v_player.casino_chips, 0) < p_bet_amount THEN RAISE EXCEPTION 'Yetersiz Çip.'; END IF;

    -- Çipleri düş
    UPDATE public.marino_players SET casino_chips = casino_chips - p_bet_amount WHERE id = v_player.id;

    -- Kartları dağıt
    p_hand := jsonb_build_array(marino_random_card(), marino_random_card());
    d_hand := jsonb_build_array(marino_random_card(), marino_random_card());
    p_score := marino_bj_score(p_hand);

    IF p_score = 21 THEN
        -- Oyuncu direkt Blackjack yaptı (3:2 ödeme)
        UPDATE public.marino_players
        SET casino_chips = casino_chips + floor(p_bet_amount * 2.5), active_game_state = NULL
        WHERE id = v_player.id;

        v_state := jsonb_build_object('game', 'blackjack', 'bet', p_bet_amount, 'player_hand', p_hand, 'dealer_hand', d_hand, 'status', 'blackjack', 'win_amount', floor(p_bet_amount * 2.5));
    ELSE
        -- Normal oyun başlangıcı
        v_state := jsonb_build_object('game', 'blackjack', 'bet', p_bet_amount, 'player_hand', p_hand, 'dealer_hand', d_hand, 'status', 'playing');
        UPDATE public.marino_players SET active_game_state = v_state WHERE id = v_player.id;
    END IF;

    SELECT * INTO v_player FROM public.marino_players WHERE id = v_player.id;
    RETURN jsonb_build_object('state', v_state, 'player', row_to_json(v_player));
END;
$$;

-- FUNCTION: marino_bj_hit(text)
CREATE FUNCTION public.marino_bj_hit(p_telegram_id text) RETURNS jsonb
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path = pg_catalog, public
    AS $$
DECLARE
    v_player record;
    v_state jsonb;
    p_hand jsonb;
    p_score int;
BEGIN
    SELECT * INTO v_player FROM public.marino_players WHERE telegram_id = p_telegram_id;
    IF v_player.active_game_state IS NULL OR (v_player.active_game_state->>'status') != 'playing' THEN
        RAISE EXCEPTION 'Aktif bir blackjack oyununuz yok.';
    END IF;

    v_state := v_player.active_game_state;
    p_hand := v_state->'player_hand';

    -- Kart Ekle
    p_hand := p_hand || to_jsonb(marino_random_card());
    p_score := marino_bj_score(p_hand);

    v_state := jsonb_set(v_state, '{player_hand}', p_hand);

    IF p_score > 21 THEN
        -- Busted
        v_state := jsonb_set(jsonb_set(v_state, '{status}', '"busted"'), '{win_amount}', '0');
        UPDATE public.marino_players SET active_game_state = NULL WHERE id = v_player.id;
    ELSE
        -- Oyuna devam
        UPDATE public.marino_players SET active_game_state = v_state WHERE id = v_player.id;
    END IF;

    SELECT * INTO v_player FROM public.marino_players WHERE id = v_player.id;
    RETURN jsonb_build_object('state', v_state, 'player', row_to_json(v_player));
END;
$$;

-- FUNCTION: marino_bj_score(jsonb)
CREATE FUNCTION public.marino_bj_score(p_hand jsonb) RETURNS integer
    LANGUAGE plpgsql
    AS $$
DECLARE
    v_score int := 0;
    v_aces int := 0;
    v_card text;
    v_val text;
BEGIN
    FOR v_card IN SELECT * FROM jsonb_array_elements_text(p_hand) LOOP
        v_val := left(v_card, 1);
        IF v_val IN ('0', 'J', 'Q', 'K') THEN
            v_score := v_score + 10;
        ELSIF v_val = 'A' THEN
            v_aces := v_aces + 1;
            v_score := v_score + 11;
        ELSE
            v_score := v_score + v_val::int;
        END IF;
    END LOOP;

    -- Asları 1 olarak say
    WHILE v_score > 21 AND v_aces > 0 LOOP
        v_score := v_score - 10;
        v_aces := v_aces - 1;
    END LOOP;

    RETURN v_score;
END;
$$;

-- FUNCTION: marino_bj_stand(text)
CREATE FUNCTION public.marino_bj_stand(p_telegram_id text) RETURNS jsonb
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path = pg_catalog, public
    AS $$
DECLARE
    v_player record;
    v_state jsonb;
    p_hand jsonb;
    d_hand jsonb;
    p_score int;
    d_score int;
    v_bet bigint;
    v_win_amount bigint := 0;
    v_end_status text := '';
BEGIN
    SELECT * INTO v_player FROM public.marino_players WHERE telegram_id = p_telegram_id;
    IF v_player.active_game_state IS NULL OR (v_player.active_game_state->>'status') != 'playing' THEN
        RAISE EXCEPTION 'Aktif bir blackjack oyununuz yok.';
    END IF;

    v_state := v_player.active_game_state;
    p_hand := v_state->'player_hand';
    d_hand := v_state->'dealer_hand';
    v_bet := (v_state->>'bet')::bigint;

    p_score := marino_bj_score(p_hand);
    d_score := marino_bj_score(d_hand);

    -- Dealer kuralı: 17 olana kadar çeker
    WHILE d_score < 17 LOOP
        d_hand := d_hand || to_jsonb(marino_random_card());
        d_score := marino_bj_score(d_hand);
    END LOOP;

    -- Kim Kazandı?
    IF d_score > 21 THEN
        v_end_status := 'player_win';
        v_win_amount := v_bet * 2;
    ELSIF p_score > d_score THEN
        v_end_status := 'player_win';
        v_win_amount := v_bet * 2;
    ELSIF p_score = d_score THEN
        v_end_status := 'push';
        v_win_amount := v_bet;
    ELSE
        v_end_status := 'dealer_win';
        v_win_amount := 0;
    END IF;

    v_state := jsonb_build_object('game', 'blackjack', 'bet', v_bet, 'player_hand', p_hand, 'dealer_hand', d_hand, 'status', v_end_status, 'win_amount', v_win_amount);

    -- Ödeme yap ve masayı kapat
    IF v_win_amount > 0 THEN
        UPDATE public.marino_players SET casino_chips = casino_chips + v_win_amount, active_game_state = NULL WHERE id = v_player.id;
    ELSE
        UPDATE public.marino_players SET active_game_state = NULL WHERE id = v_player.id;
    END IF;

    SELECT * INTO v_player FROM public.marino_players WHERE id = v_player.id;
    RETURN jsonb_build_object('state', v_state, 'player', row_to_json(v_player));
END;
$$;

-- FUNCTION: marino_bootstrap(text)
CREATE FUNCTION public.marino_bootstrap(p_telegram_id text) RETURNS void
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path = pg_catalog, public
    AS $$
begin
  insert into marino_game_state (telegram_id, marino_coin, reward_token, energy, max_energy, tap_power, passive_income_per_hour, casino_level, reputation, claimable_coin)
  values (p_telegram_id, 1000, 25, 500, 500, 1, 0, 1, 0, 0)
  on conflict (telegram_id) do nothing;

  insert into marino_user_buildings (telegram_id, building_key, level)
  select p_telegram_id, building_key, 0
  from marino_building_types
  where is_active = true
  on conflict (telegram_id, building_key) do nothing;

  perform marino_recalculate_income(p_telegram_id);
end;
$$;

-- FUNCTION: marino_building_income(integer, numeric, numeric)
CREATE FUNCTION public.marino_building_income(p_level integer, p_base numeric, p_multi numeric) RETURNS numeric
    LANGUAGE sql IMMUTABLE
    AS $$
  select case when coalesce(p_level,0) <= 0 then 0 else round((p_base * p_level * power(p_multi, greatest(p_level-1,0)))::numeric, 0) end;
$$;

-- FUNCTION: marino_buy_chips(text, bigint)
CREATE FUNCTION public.marino_buy_chips(p_telegram_id text, p_chip_amount bigint) RETURNS jsonb
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path = pg_catalog, public
    AS $$
DECLARE
    v_player record;
    v_cost bigint;
BEGIN
    v_cost := p_chip_amount * 1000;
    SELECT * INTO v_player FROM public.marino_players WHERE telegram_id = p_telegram_id;
    IF NOT FOUND THEN RAISE EXCEPTION 'Oyuncu bulunamadı.'; END IF;
    IF v_player.marino_coin < v_cost THEN RAISE EXCEPTION 'Yetersiz Marino Coin. % Coin gerekli.', v_cost; END IF;

    UPDATE public.marino_players
    SET marino_coin = marino_coin - v_cost, casino_chips = COALESCE(casino_chips, 0) + p_chip_amount, updated_at = now()
    WHERE telegram_id = p_telegram_id
    RETURNING * INTO v_player;

    RETURN row_to_json(v_player)::jsonb;
END;
$$;

-- FUNCTION: marino_buy_sink(text, text, text)
CREATE FUNCTION public.marino_buy_sink(p_telegram_id text, p_sink_code text, p_request_id text DEFAULT ''::text) RETURNS jsonb
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path = pg_catalog, public
    AS $$
DECLARE
  v_player marino_players%ROWTYPE;
  v_cost BIGINT;
  v_token_cost INT;
  v_msg TEXT;
BEGIN
  IF p_request_id != '' THEN
    INSERT INTO marino_processed_requests (request_id) VALUES (p_request_id)
    ON CONFLICT DO NOTHING;
    IF NOT FOUND THEN RAISE EXCEPTION 'Bu işlem zaten işlendi.'; END IF;
  END IF;

  SELECT * INTO v_player FROM marino_players WHERE telegram_id = p_telegram_id;
  IF NOT FOUND THEN RAISE EXCEPTION 'Oyuncu bulunamadı.'; END IF;

  -- Sink ürünleri
  CASE p_sink_code
    WHEN 'season_pass' THEN v_cost := 15000; v_token_cost := 0; v_msg := 'Sezon Bileti aktifleştirildi!';
    WHEN 'vip_badge' THEN v_cost := 25000; v_token_cost := 5; v_msg := 'VIP Rozet kazanıldı!';
    WHEN 'income_boost' THEN v_cost := 12000; v_token_cost := 2; v_msg := '2 Saatlik Gelir Artışı aktif!';
    WHEN 'profile_frame' THEN v_cost := 18000; v_token_cost := 3; v_msg := 'Profil Çerçevesi eklendi!';
    ELSE RAISE EXCEPTION 'Bilinmeyen ürün kodu.';
  END CASE;

  IF v_player.marino_coin < v_cost THEN
    RAISE EXCEPTION 'Yetersiz coin. Gerekli: %', v_cost;
  END IF;
  IF v_player.reward_token < v_token_cost THEN
    RAISE EXCEPTION 'Yetersiz ödül bileti. Gerekli: %', v_token_cost;
  END IF;

  UPDATE marino_players SET
    marino_coin = marino_coin - v_cost,
    reward_token = reward_token - v_token_cost,
    reputation = reputation + 10,
    updated_at = NOW()
  WHERE id = v_player.id
  RETURNING * INTO v_player;

  RETURN jsonb_build_object(
    'state', jsonb_build_object(
      'marino_coin', v_player.marino_coin,
      'reward_token', v_player.reward_token,
      'energy', v_player.energy,
      'max_energy', v_player.max_energy,
      'tap_power', v_player.tap_power,
      'passive_income_per_hour', v_player.passive_income_per_hour,
      'casino_level', v_player.casino_level,
      'reputation', v_player.reputation,
      'claimable_coin', v_player.claimable_coin,
      'offline_capacity_hours', v_player.offline_capacity_hours,
      'prestige_points', v_player.prestige_points
    ),
    'message', v_msg
  );
END;
$$;

-- FUNCTION: marino_check_coupons(text)
CREATE FUNCTION public.marino_check_coupons(p_telegram_id text) RETURNS jsonb
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path = pg_catalog, public
    AS $$
DECLARE
    v_coupon record;
    v_match record;
    v_home_score int;
    v_away_score int;
    v_event jsonb;
    v_win_amount bigint;
    v_total_win bigint := 0;
    v_win_count int := 0;
    v_match_result text;
BEGIN
    FOR v_coupon IN
        SELECT c.* FROM public.marino_sports_coupons c
        JOIN public.marino_sports_matches m ON c.match_id = m.id
        WHERE c.telegram_id = p_telegram_id AND c.status = 'pending'
        AND EXTRACT(EPOCH FROM (now() - m.start_time)) >= m.duration_secs
    LOOP
        SELECT * INTO v_match FROM public.marino_sports_matches WHERE id = v_coupon.match_id;
        v_home_score := 0;
        v_away_score := 0;

        FOR v_event IN SELECT * FROM jsonb_array_elements(v_match.events) LOOP
            IF (v_event->>'team_id')::int = v_match.home_team_id THEN
                v_home_score := v_home_score + 1;
            ELSE
                v_away_score := v_away_score + 1;
            END IF;
        END LOOP;

        IF v_home_score > v_away_score THEN v_match_result := '1';
        ELSIF v_away_score > v_home_score THEN v_match_result := '2';
        ELSE v_match_result := 'X'; END IF;

        IF v_coupon.selection = v_match_result THEN
            v_win_amount := floor(v_coupon.amount * v_coupon.locked_odds);
            UPDATE public.marino_sports_coupons SET status = 'won' WHERE id = v_coupon.id;

            UPDATE public.marino_players SET casino_chips = casino_chips + v_win_amount WHERE telegram_id = p_telegram_id;
            v_total_win := v_total_win + v_win_amount;
            v_win_count := v_win_count + 1;
        ELSE
            UPDATE public.marino_sports_coupons SET status = 'lost' WHERE id = v_coupon.id;
        END IF;
    END LOOP;

    RETURN jsonb_build_object('win_count', v_win_count, 'total_win_amount', v_total_win);
END;
$$;

-- FUNCTION: marino_claim_ad_reward(text, text)
CREATE FUNCTION public.marino_claim_ad_reward(p_telegram_id text, p_request_id text DEFAULT ''::text) RETURNS jsonb
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path = pg_catalog, public
    AS $$
DECLARE
  v_player marino_players%ROWTYPE;
BEGIN
  IF p_request_id != '' THEN
    INSERT INTO marino_processed_requests (request_id) VALUES (p_request_id)
    ON CONFLICT DO NOTHING;
    IF NOT FOUND THEN RAISE EXCEPTION 'Bu işlem zaten işlendi.'; END IF;
  END IF;

  SELECT * INTO v_player FROM marino_players WHERE telegram_id = p_telegram_id;
  IF NOT FOUND THEN RAISE EXCEPTION 'Oyuncu bulunamadı.'; END IF;

  UPDATE marino_players SET
    marino_coin = marino_coin + 250,
    reputation = reputation + 1,
    updated_at = NOW()
  WHERE id = v_player.id
  RETURNING * INTO v_player;

  RETURN jsonb_build_object(
    'state', jsonb_build_object(
      'marino_coin', v_player.marino_coin,
      'reward_token', v_player.reward_token,
      'energy', v_player.energy,
      'max_energy', v_player.max_energy,
      'tap_power', v_player.tap_power,
      'passive_income_per_hour', v_player.passive_income_per_hour,
      'casino_level', v_player.casino_level,
      'reputation', v_player.reputation,
      'claimable_coin', v_player.claimable_coin,
      'offline_capacity_hours', v_player.offline_capacity_hours,
      'prestige_points', v_player.prestige_points
    ),
    'message', 'Reklam ödülü: +250 coin eklendi.'
  );
END;
$$;

-- FUNCTION: marino_claim_cipher(text, text)
CREATE FUNCTION public.marino_claim_cipher(p_telegram_id text, p_word text) RETURNS jsonb
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path = pg_catalog, public
    AS $$
DECLARE
  v_row marino_daily_cipher;
  v_answer text;
  v_reward bigint := 1000000;
BEGIN
  v_answer := marino_get_today_cipher();
  INSERT INTO marino_daily_cipher(telegram_id, cipher_date)
  VALUES (p_telegram_id, CURRENT_DATE)
  ON CONFLICT (telegram_id, cipher_date) DO NOTHING;
  SELECT * INTO v_row FROM marino_daily_cipher
   WHERE telegram_id = p_telegram_id AND cipher_date = CURRENT_DATE FOR UPDATE;
  IF v_row.won THEN
    RETURN jsonb_build_object('ok',false,'error','already_won');
  END IF;
  IF upper(trim(p_word)) = v_answer THEN
    UPDATE marino_daily_cipher SET won=true, attempts=attempts+1, reward_claimed=v_reward, updated_at=NOW() WHERE id=v_row.id;
    UPDATE marino_players SET marino_coin = marino_coin + v_reward, updated_at=NOW()
      WHERE telegram_id = p_telegram_id;
    RETURN jsonb_build_object('ok',true,'won',true,'reward',v_reward);
  ELSE
    UPDATE marino_daily_cipher SET attempts=attempts+1, updated_at=NOW() WHERE id=v_row.id;
    RETURN jsonb_build_object('ok',true,'won',false,'reward',0,'attempts',v_row.attempts+1);
  END IF;
END$$;

-- FUNCTION: marino_claim_combo(text, text[])
CREATE FUNCTION public.marino_claim_combo(p_telegram_id text, p_picks text[]) RETURNS jsonb
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path = pg_catalog, public
    AS $$
DECLARE
  v_row marino_daily_combo;
  v_correct text[];
  v_picks_sorted text[];
  v_reward bigint := 5000000;
BEGIN
  IF array_length(p_picks,1) <> 3 THEN
    RETURN jsonb_build_object('ok',false,'error','3 cards required');
  END IF;
  v_picks_sorted := ARRAY(SELECT DISTINCT unnest(p_picks) ORDER BY 1);
  v_correct := marino_get_today_combo();
  INSERT INTO marino_daily_combo(telegram_id, combo_date)
  VALUES (p_telegram_id, CURRENT_DATE)
  ON CONFLICT (telegram_id, combo_date) DO NOTHING;
  SELECT * INTO v_row FROM marino_daily_combo
   WHERE telegram_id = p_telegram_id AND combo_date = CURRENT_DATE FOR UPDATE;
  IF v_row.won THEN
    RETURN jsonb_build_object('ok',false,'error','already_won','attempts_left',v_row.attempts_left);
  END IF;
  IF v_row.attempts_left <= 0 THEN
    RETURN jsonb_build_object('ok',false,'error','no_attempts','attempts_left',0);
  END IF;
  IF v_picks_sorted = v_correct THEN
    UPDATE marino_daily_combo
      SET won=true, picks=to_jsonb(p_picks), attempts_left=attempts_left-1,
          reward_claimed=v_reward, updated_at=NOW()
      WHERE id=v_row.id;
    UPDATE marino_players SET marino_coin = marino_coin + v_reward, updated_at=NOW()
      WHERE telegram_id = p_telegram_id;
    RETURN jsonb_build_object('ok',true,'won',true,'reward',v_reward,'attempts_left',v_row.attempts_left-1);
  ELSE
    UPDATE marino_daily_combo
      SET picks=to_jsonb(p_picks), attempts_left=attempts_left-1, updated_at=NOW()
      WHERE id=v_row.id;
    RETURN jsonb_build_object('ok',true,'won',false,'reward',0,'attempts_left',v_row.attempts_left-1);
  END IF;
END$$;

-- FUNCTION: marino_claim_daily_login(text, text)
CREATE FUNCTION public.marino_claim_daily_login(p_telegram_id text, p_request_id text DEFAULT ''::text) RETURNS jsonb
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path = pg_catalog, public
    AS $$
DECLARE
  v_player marino_players%ROWTYPE;
  v_daily marino_daily_login%ROWTYPE;
  v_streak INT;
  v_reward_coin BIGINT;
  v_reward_token INT := 0;
BEGIN
  IF p_request_id != '' THEN
    INSERT INTO marino_processed_requests (request_id) VALUES (p_request_id)
    ON CONFLICT DO NOTHING;
    IF NOT FOUND THEN RAISE EXCEPTION 'Bu işlem zaten işlendi.'; END IF;
  END IF;

  SELECT * INTO v_player FROM marino_players WHERE telegram_id = p_telegram_id;
  IF NOT FOUND THEN RAISE EXCEPTION 'Oyuncu bulunamadı.'; END IF;

  SELECT * INTO v_daily FROM marino_daily_login WHERE player_id = v_player.id;

  IF NOT FOUND THEN
    INSERT INTO marino_daily_login (player_id, current_streak, last_login_date, total_logins)
    VALUES (v_player.id, 0, NULL, 0)
    RETURNING * INTO v_daily;
  END IF;

  -- Bugün zaten aldı mı
  IF v_daily.last_login_date = CURRENT_DATE THEN
    RAISE EXCEPTION 'Bugünkü günlük ödülü zaten aldın.';
  END IF;

  -- Streak hesapla
  IF v_daily.last_login_date = CURRENT_DATE - 1 THEN
    v_streak := v_daily.current_streak + 1;
  ELSE
    v_streak := 1; -- Seri kırıldı
  END IF;

  -- Ödül hesapla (7 günlük döngü)
  CASE (v_streak - 1) % 7 + 1
    WHEN 1 THEN v_reward_coin := 100;
    WHEN 2 THEN v_reward_coin := 200;
    WHEN 3 THEN v_reward_coin := 300; v_reward_token := 5;
    WHEN 4 THEN v_reward_coin := 500;
    WHEN 5 THEN v_reward_coin := 750; v_reward_token := 10;
    WHEN 6 THEN v_reward_coin := 1000;
    WHEN 7 THEN v_reward_coin := 2000; v_reward_token := 25;
  END CASE;

  -- Güncelle
  UPDATE marino_daily_login SET
    current_streak = v_streak,
    longest_streak = GREATEST(longest_streak, v_streak),
    last_login_date = CURRENT_DATE,
    total_logins = total_logins + 1,
    last_claim_at = NOW()
  WHERE player_id = v_player.id;

  UPDATE marino_players SET
    marino_coin = marino_coin + v_reward_coin,
    reward_token = reward_token + v_reward_token,
    reputation = reputation + 5,
    updated_at = NOW()
  WHERE id = v_player.id
  RETURNING * INTO v_player;

  RETURN jsonb_build_object(
    'state', jsonb_build_object(
      'marino_coin', v_player.marino_coin,
      'reward_token', v_player.reward_token,
      'energy', v_player.energy,
      'max_energy', v_player.max_energy,
      'tap_power', v_player.tap_power,
      'passive_income_per_hour', v_player.passive_income_per_hour,
      'casino_level', v_player.casino_level,
      'reputation', v_player.reputation,
      'claimable_coin', v_player.claimable_coin,
      'offline_capacity_hours', v_player.offline_capacity_hours,
      'prestige_points', v_player.prestige_points
    ),
    'streak', v_streak,
    'reward_coin', v_reward_coin,
    'reward_token', v_reward_token,
    'message', 'Günlük ödül alındı! Seri: ' || v_streak || ' gün. +' || v_reward_coin || ' coin'
  );
END;
$$;

-- FUNCTION: marino_claim_referral(text, text, text)
CREATE FUNCTION public.marino_claim_referral(p_telegram_id text, p_referred_id text, p_request_id text DEFAULT ''::text) RETURNS jsonb
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path = pg_catalog, public
    AS $$
DECLARE
    v_my_bal record;
    v_tasks jsonb;
    v_target_lvl int;
    v_task_key text := 'ref_' || p_referred_id;
BEGIN
    SELECT casino_level INTO v_target_lvl FROM public.marino_players WHERE telegram_id = p_referred_id AND referred_by = p_telegram_id;

    IF NOT FOUND THEN
      RAISE EXCEPTION 'Bu kullanıcı sizin referansınız değil.';
    END IF;

    IF v_target_lvl < 5 THEN
      RAISE EXCEPTION 'Ödülü almak için arkadaşınızın en az 5. Seviyeye ulaşması gerekiyor (Şu an: %).', v_target_lvl;
    END IF;

    SELECT completed_tasks INTO v_tasks FROM public.marino_players WHERE telegram_id = p_telegram_id;
    IF v_tasks ? v_task_key THEN RAISE EXCEPTION 'Bu arkadaşınız için ödülü zaten aldınız.'; END IF;

    UPDATE public.marino_players
    SET marino_coin = marino_coin + 50000, reward_token = reward_token + 5, updated_at = now(),
        completed_tasks = COALESCE(completed_tasks, '[]'::jsonb) || jsonb_build_array(v_task_key)
    WHERE telegram_id = p_telegram_id
    RETURNING * INTO v_my_bal;

    RETURN jsonb_build_object(
        'message', '+50.000 Coin ve +5 Bilet kazandınız!',
        'state', row_to_json(v_my_bal)
    );
END;
$$;

-- FUNCTION: marino_claim_task(text, text, integer)
CREATE FUNCTION public.marino_claim_task(p_telegram_id text, p_task_id text, p_level_no integer DEFAULT 1) RETURNS jsonb
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path = pg_catalog, public
    AS $$
DECLARE
  v_player marino_players%ROWTYPE;
BEGIN
  SELECT * INTO v_player FROM marino_players WHERE telegram_id = p_telegram_id;
  IF v_player.completed_tasks ? p_task_id THEN RAISE EXCEPTION 'Görev zaten yapıldı'; END IF;

  UPDATE marino_players SET
    marino_coin = marino_coin + CASE
      WHEN p_task_id = 'soc_tg' THEN 5000
      WHEN p_task_id = 'soc_tw' THEN 2500
      ELSE 200 END,
    completed_tasks = COALESCE(completed_tasks, '[]'::jsonb) || jsonb_build_array(p_task_id)
  WHERE id = v_player.id RETURNING * INTO v_player;
  RETURN jsonb_build_object('message', 'Görev tamamlandı!', 'state', row_to_json(v_player));
END;
$$;

-- FUNCTION: marino_claim_task(text, text, integer, text)
CREATE FUNCTION public.marino_claim_task(p_telegram_id text, p_task_id text, p_level_no integer DEFAULT 1, p_request_id text DEFAULT ''::text) RETURNS jsonb
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path = pg_catalog, public
    AS $$
DECLARE
  v_player marino_players%ROWTYPE;
  v_task marino_tasks%ROWTYPE;
  v_reward BIGINT;
BEGIN
  IF p_request_id != '' THEN
    INSERT INTO marino_processed_requests (request_id) VALUES (p_request_id)
    ON CONFLICT DO NOTHING;
    IF NOT FOUND THEN RAISE EXCEPTION 'Bu işlem zaten işlendi.'; END IF;
  END IF;

  SELECT * INTO v_player FROM marino_players WHERE telegram_id = p_telegram_id;
  IF NOT FOUND THEN RAISE EXCEPTION 'Oyuncu bulunamadı.'; END IF;

  -- Görev var mı kontrol
  SELECT * INTO v_task FROM marino_tasks WHERE task_key = p_task_id AND is_active = TRUE;

  IF FOUND THEN
    -- Seviye kontrolü
    IF v_player.casino_level < v_task.required_level THEN
      RAISE EXCEPTION 'Bu görev için seviye % gerekli.', v_task.required_level;
    END IF;

    -- Zaten alınmış mı (seviye görevleri için)
    IF v_task.task_type = 'level' THEN
      IF EXISTS (SELECT 1 FROM marino_player_tasks WHERE player_id = v_player.id AND task_key = p_task_id) THEN
        RAISE EXCEPTION 'Bu görevi zaten tamamladın.';
      END IF;
    END IF;

    -- Günlük görevler için bugün alınmış mı
    IF v_task.task_type = 'daily' THEN
      IF EXISTS (SELECT 1 FROM marino_player_tasks WHERE player_id = v_player.id AND task_key = p_task_id AND claimed_at >= CURRENT_DATE) THEN
        RAISE EXCEPTION 'Bu günlük görevi bugün zaten tamamladın.';
      END IF;
      -- Eski kaydı sil (yeni gün için)
      DELETE FROM marino_player_tasks WHERE player_id = v_player.id AND task_key = p_task_id;
    END IF;

    v_reward := v_task.reward_coin;

    INSERT INTO marino_player_tasks (player_id, task_key) VALUES (v_player.id, p_task_id);

    UPDATE marino_players SET
      marino_coin = marino_coin + v_task.reward_coin,
      reward_token = reward_token + v_task.reward_token,
      reputation = reputation + v_task.reward_xp,
      updated_at = NOW()
    WHERE id = v_player.id
    RETURNING * INTO v_player;
  ELSE
    -- Dinamik görev (eski format uyumluluğu)
    v_reward := LEAST(2500, 120 + p_level_no * 20);

    IF v_player.casino_level < p_level_no THEN
      RAISE EXCEPTION 'Bu görev için seviye % gerekli.', p_level_no;
    END IF;

    IF EXISTS (SELECT 1 FROM marino_player_tasks WHERE player_id = v_player.id AND task_key = p_task_id) THEN
      RAISE EXCEPTION 'Bu görevi zaten tamamladın.';
    END IF;

    INSERT INTO marino_player_tasks (player_id, task_key) VALUES (v_player.id, p_task_id);

    UPDATE marino_players SET
      marino_coin = marino_coin + v_reward,
      reputation = reputation + GREATEST(5, p_level_no),
      updated_at = NOW()
    WHERE id = v_player.id
    RETURNING * INTO v_player;
  END IF;

  RETURN jsonb_build_object(
    'state', jsonb_build_object(
      'marino_coin', v_player.marino_coin,
      'reward_token', v_player.reward_token,
      'energy', v_player.energy,
      'max_energy', v_player.max_energy,
      'tap_power', v_player.tap_power,
      'passive_income_per_hour', v_player.passive_income_per_hour,
      'casino_level', v_player.casino_level,
      'reputation', v_player.reputation,
      'claimable_coin', v_player.claimable_coin,
      'offline_capacity_hours', v_player.offline_capacity_hours,
      'prestige_points', v_player.prestige_points
    ),
    'message', 'Görev ödülü alındı: +' || v_reward || ' coin'
  );
END;
$$;

-- FUNCTION: marino_connect_wallet(text, text)
CREATE FUNCTION public.marino_connect_wallet(p_telegram_id text, p_ton_address text) RETURNS jsonb
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path = pg_catalog, public
    AS $$
BEGIN
  INSERT INTO marino_wallets(telegram_id, ton_address)
  VALUES (p_telegram_id, COALESCE(p_ton_address, 'UQ' || substr(md5(p_telegram_id || NOW()::text), 1, 46)))
  ON CONFLICT (telegram_id) DO UPDATE SET ton_address = COALESCE(EXCLUDED.ton_address, marino_wallets.ton_address), updated_at = NOW();
  RETURN jsonb_build_object('ok',true,'ton_address',(SELECT ton_address FROM marino_wallets WHERE telegram_id=p_telegram_id));
END$$;

-- FUNCTION: marino_generate_matches(integer)
CREATE FUNCTION public.marino_generate_matches(p_match_count integer DEFAULT 20) RETURNS void
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path = pg_catalog, public
    AS $$
DECLARE
    v_home RECORD;
    v_away RECORD;
    v_goal_minute INT;
    v_scorer RECORD;
    v_events JSONB;
    v_home_goals INT;
    v_away_goals INT;
    i INT;
    g INT;
BEGIN
    -- 1. ÖNCELİKLİ ÇÖZÜM: Yabancı anahtar kilitlenmesini engellemek için,
    -- 48 saatten eski maçlara yapılmış kuponları önce siliyoruz.
    DELETE FROM public.marino_sports_coupons
    WHERE match_id IN (
        SELECT id FROM public.marino_sports_matches WHERE start_time < now() - interval '48 hours'
    );

    -- 2. Şimdi 48 saatten eski maçları güvenle silebiliriz.
    -- (2 saat yerine 48 saat yaptık ki oyuncu uyuyup uyandığında kuponunu ve kazancını alabilsin)
    DELETE FROM public.marino_sports_matches WHERE start_time < now() - interval '48 hours';

    FOR i IN 1..p_match_count LOOP
        SELECT * INTO v_home FROM public.marino_sports_teams ORDER BY random() LIMIT 1;
        SELECT * INTO v_away FROM public.marino_sports_teams WHERE id != v_home.id ORDER BY random() LIMIT 1;

        v_events := '[]'::jsonb;

        -- Ev sahibi golleri
        v_home_goals := floor(random() * (v_home.power_rating::numeric / 25.0));
        FOR g IN 1..v_home_goals LOOP
            v_goal_minute := floor(random() * 90) + 1;
            SELECT * INTO v_scorer FROM public.marino_sports_players WHERE team_id = v_home.id AND position != 'GK' ORDER BY random() LIMIT 1;
            v_events := v_events || jsonb_build_object('minute', v_goal_minute, 'type', 'goal', 'team_id', v_home.id, 'player_name', v_scorer.name);
        END LOOP;

        -- Deplasman golleri
        v_away_goals := floor(random() * (v_away.power_rating::numeric / 30.0));
        FOR g IN 1..v_away_goals LOOP
            v_goal_minute := floor(random() * 90) + 1;
            SELECT * INTO v_scorer FROM public.marino_sports_players WHERE team_id = v_away.id AND position != 'GK' ORDER BY random() LIMIT 1;
            v_events := v_events || jsonb_build_object('minute', v_goal_minute, 'type', 'goal', 'team_id', v_away.id, 'player_name', v_scorer.name);
        END LOOP;

        INSERT INTO public.marino_sports_matches (home_team_id, away_team_id, start_time, duration_secs, events)
        VALUES (v_home.id, v_away.id, now(), 300, v_events);
    END LOOP;
END;
$$;

-- FUNCTION: marino_get_boosts(text)
CREATE FUNCTION public.marino_get_boosts(p_telegram_id text) RETURNS jsonb
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path = pg_catalog, public
    AS $$
DECLARE r marino_player_boosts;
BEGIN
  PERFORM _marino_ensure_boost(p_telegram_id);
  SELECT * INTO r FROM marino_player_boosts WHERE telegram_id = p_telegram_id;
  RETURN jsonb_build_object(
    'multitap_lvl', r.multitap_lvl,
    'energy_lvl', r.energy_lvl,
    'full_energy_left', 3 - r.full_energy_used,
    'tap_boost_left', 3 - r.tap_boost_used,
    'auto_tap_until', r.auto_tap_until,
    'auto_tap_active', (r.auto_tap_until IS NOT NULL AND r.auto_tap_until > NOW())
  );
END$$;

-- FUNCTION: marino_get_leaderboard(text, text, integer, integer)
CREATE FUNCTION public.marino_get_leaderboard(p_scope text DEFAULT 'global'::text, p_country_code text DEFAULT 'TR'::text, p_min_lvl integer DEFAULT 0, p_max_lvl integer DEFAULT 999) RETURNS jsonb
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path = pg_catalog, public
    AS $$
DECLARE
  v_result JSONB;
BEGIN
  IF p_scope = 'league' THEN
    SELECT COALESCE(jsonb_agg(row_to_json(t)::jsonb), '[]'::jsonb) INTO v_result
    FROM (
      SELECT
        ROW_NUMBER() OVER (ORDER BY casino_level DESC, reputation DESC) AS rank_no,
        display_name, casino_level, reputation
      FROM public.marino_players
      WHERE casino_level >= p_min_lvl AND casino_level <= p_max_lvl
      ORDER BY casino_level DESC, reputation DESC
      LIMIT 100
    ) t;
  ELSE
    SELECT COALESCE(jsonb_agg(row_to_json(t)::jsonb), '[]'::jsonb) INTO v_result
    FROM (
      SELECT
        ROW_NUMBER() OVER (ORDER BY casino_level DESC, reputation DESC) AS rank_no,
        display_name, casino_level, reputation
      FROM public.marino_players
      ORDER BY casino_level DESC, reputation DESC
      LIMIT 100
    ) t;
  END IF;

  RETURN v_result;
END;
$$;

-- FUNCTION: marino_get_live_matches()
CREATE FUNCTION public.marino_get_live_matches() RETURNS jsonb
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path = pg_catalog, public
    AS $$
DECLARE
    v_match RECORD;
    v_res jsonb := '[]'::jsonb;
    v_elapsed_secs INT;
    v_game_minute INT;
    v_visible_events jsonb;
    v_event jsonb;
    v_home_score INT;
    v_away_score INT;
    v_active_count INT;
BEGIN
    -- Aktif maç var mı diye say
    SELECT count(*) INTO v_active_count
    FROM public.marino_sports_matches
    WHERE start_time >= now() - interval '1 hour';

    -- Eğer hiç aktif maç kalmadıysa (Lig kapalıysa) acilen yeni 5 maç üret!
    IF v_active_count = 0 THEN
        PERFORM public.marino_generate_matches(5);
    END IF;

    -- Şimdi maçları normal şekilde getir
    FOR v_match IN
        SELECT m.id, m.start_time, m.duration_secs, m.events,
               t1.name as home_name, t1.logo_url as home_logo,
               t2.name as away_name, t2.logo_url as away_logo,
               t1.id as home_id, t2.id as away_id
        FROM public.marino_sports_matches m
        JOIN public.marino_sports_teams t1 ON m.home_team_id = t1.id
        JOIN public.marino_sports_teams t2 ON m.away_team_id = t2.id
        WHERE m.start_time >= now() - interval '2 hours'
        ORDER BY m.start_time DESC
    LOOP
        v_elapsed_secs := EXTRACT(EPOCH FROM (now() - v_match.start_time));
        IF v_elapsed_secs < 0 THEN v_elapsed_secs := 0; END IF;

        v_game_minute := floor((v_elapsed_secs::numeric / v_match.duration_secs::numeric) * 90);
        IF v_game_minute > 90 THEN v_game_minute := 90; END IF;

        v_visible_events := '[]'::jsonb;
        v_home_score := 0;
        v_away_score := 0;

        FOR v_event IN SELECT * FROM jsonb_array_elements(v_match.events) LOOP
            IF (v_event->>'minute')::int <= v_game_minute THEN
                v_visible_events := v_visible_events || v_event;
                IF (v_event->>'team_id')::int = v_match.home_id THEN
                    v_home_score := v_home_score + 1;
                ELSE
                    v_away_score := v_away_score + 1;
                END IF;
            END IF;
        END LOOP;

        v_res := v_res || jsonb_build_object(
            'id', v_match.id,
            'home', v_match.home_name,
            'home_logo', v_match.home_logo,
            'away', v_match.away_name,
            'away_logo', v_match.away_logo,
            'minute', v_game_minute,
            'home_score', v_home_score,
            'away_score', v_away_score,
            'events', v_visible_events,
            'is_finished', v_game_minute >= 90
        );
    END LOOP;

    RETURN v_res;
END;
$$;

-- FUNCTION: marino_get_my_notifications(text)
CREATE FUNCTION public.marino_get_my_notifications(p_telegram_id text) RETURNS jsonb
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path = pg_catalog, public
    AS $$
DECLARE
    v_req record;
BEGIN
    SELECT * INTO v_req FROM public.marino_reward_requests
    WHERE telegram_id = p_telegram_id AND status IN ('approved', 'rejected') AND is_read = false
    ORDER BY reviewed_at DESC LIMIT 1;

    IF NOT FOUND THEN RETURN NULL; END IF;

    UPDATE public.marino_reward_requests SET is_read = true WHERE id = v_req.id;

    RETURN jsonb_build_object(
        'id', v_req.id,
        'status', v_req.status,
        'item_name', v_req.item_name,
        'note', v_req.admin_note,
        'date', v_req.reviewed_at
    );
END;
$$;

-- FUNCTION: marino_get_referrals(text)
CREATE FUNCTION public.marino_get_referrals(p_telegram_id text) RETURNS jsonb
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path = pg_catalog, public
    AS $$
DECLARE
    v_res jsonb;
    v_tasks jsonb;
BEGIN
    SELECT completed_tasks INTO v_tasks FROM public.marino_players WHERE telegram_id = p_telegram_id;
    IF v_tasks IS NULL THEN v_tasks := '[]'::jsonb; END IF;

    SELECT COALESCE(jsonb_agg(
        jsonb_build_object(
            'id', u.telegram_id,
            'name', u.display_name,
            'level', u.casino_level,
            'is_claimed', v_tasks ? ('ref_' || u.telegram_id)
        )
    ), '[]'::jsonb) INTO v_res
    FROM public.marino_players u
    WHERE u.referred_by = p_telegram_id;

    RETURN v_res;
END;
$$;

-- FUNCTION: marino_get_today_cipher()
CREATE FUNCTION public.marino_get_today_cipher() RETURNS text
    LANGUAGE plpgsql STABLE
    AS $$
BEGIN
  -- Buraya bugünün kelimesini manuel yazabilirsin
  RETURN 'MARINO';
END$$;

-- FUNCTION: marino_get_today_combo()
CREATE FUNCTION public.marino_get_today_combo() RETURNS text[]
    LANGUAGE plpgsql STABLE
    AS $$
DECLARE
  deck text[] := ARRAY['spade_a','heart_a','club_a','diamond_a','king','queen','jack','joker','chip','dice','wheel','slot']::text[];
  d text := to_char(CURRENT_DATE, 'YYYY-MM-DD');
  seed bigint;
  i int; j int; tmp text;
BEGIN
  seed := abs(hashtext('combo_' || d));
  FOR i IN REVERSE 12..2 LOOP
    seed := (seed * 9301 + 49297) % 233280;
    j := 1 + ((seed::numeric * i / 233280)::int);
    IF j > i THEN j := i; END IF;
    IF j < 1 THEN j := 1; END IF;
    tmp := deck[i]; deck[i] := deck[j]; deck[j] := tmp;
  END LOOP;
  RETURN ARRAY(SELECT x FROM unnest(deck[1:3]) x ORDER BY x);
END$$;

-- FUNCTION: marino_hk_state(text)
CREATE FUNCTION public.marino_hk_state(p_telegram_id text) RETURNS jsonb
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path = pg_catalog, public
    AS $$
DECLARE combo marino_daily_combo; cipher marino_daily_cipher;
BEGIN
  PERFORM _marino_ensure_boost(p_telegram_id);
  SELECT * INTO combo FROM marino_daily_combo WHERE telegram_id = p_telegram_id AND combo_date = CURRENT_DATE;
  SELECT * INTO cipher FROM marino_daily_cipher WHERE telegram_id = p_telegram_id AND cipher_date = CURRENT_DATE;
  RETURN jsonb_build_object(
    'combo', jsonb_build_object('attempts_left', COALESCE(combo.attempts_left, 6),'won', COALESCE(combo.won, false),'reward', COALESCE(combo.reward_claimed, 0)),
    'cipher', jsonb_build_object('won', COALESCE(cipher.won, false),'attempts', COALESCE(cipher.attempts, 0),'reward', COALESCE(cipher.reward_claimed, 0)),
    'boosts', marino_get_boosts(p_telegram_id),
    'airdrop', marino_airdrop_status(p_telegram_id)
  );
END$$;

-- FUNCTION: marino_level_from_rep(numeric)
CREATE FUNCTION public.marino_level_from_rep(p_rep numeric) RETURNS integer
    LANGUAGE sql IMMUTABLE
    AS $$
  select greatest(1, least(100, floor(sqrt(greatest(coalesce(p_rep,0),0) / 120))::int + 1));
$$;

-- FUNCTION: marino_place_sports_bet(text, uuid, text, bigint)
CREATE FUNCTION public.marino_place_sports_bet(p_telegram_id text, p_match_id uuid, p_selection text, p_amount bigint) RETURNS jsonb
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path = pg_catalog, public
    AS $$
DECLARE
    v_player record;
    v_match record;
    v_elapsed_secs INT;
    v_game_minute INT;
    v_base_odd numeric;
    v_final_odd numeric;
BEGIN
    SELECT * INTO v_player FROM public.marino_players WHERE telegram_id = p_telegram_id;
    IF COALESCE(v_player.casino_chips, 0) < p_amount THEN RAISE EXCEPTION 'Yetersiz Çip.'; END IF;

    SELECT * INTO v_match FROM public.marino_sports_matches WHERE id = p_match_id;
    IF NOT FOUND THEN RAISE EXCEPTION 'Maç bulunamadı.'; END IF;

    v_elapsed_secs := EXTRACT(EPOCH FROM (now() - v_match.start_time));
    v_game_minute := floor((v_elapsed_secs::numeric / v_match.duration_secs::numeric) * 90);

    IF v_game_minute >= 85 THEN
        RAISE EXCEPTION '85. dakikadan sonra bahis alınamaz.';
    END IF;

    -- Basit Oran Algoritması
    IF p_selection = '1' THEN v_base_odd := 2.20;
    ELSIF p_selection = '2' THEN v_base_odd := 2.60;
    ELSE v_base_odd := 3.20; END IF;

    -- Zaman daraldıkça oran düşer
    v_final_odd := v_base_odd - (v_base_odd * (v_game_minute / 200.0));
    IF v_final_odd < 1.01 THEN v_final_odd := 1.01; END IF;

    -- Bakiyeyi Düş
    UPDATE public.marino_players SET casino_chips = casino_chips - p_amount WHERE id = v_player.id;

    -- Kuponu Kaydet
    INSERT INTO public.marino_sports_coupons (telegram_id, match_id, selection, amount, locked_odds)
    VALUES (p_telegram_id, p_match_id, p_selection, p_amount, ROUND(v_final_odd, 2));

    RETURN jsonb_build_object('success', true, 'locked_odds', ROUND(v_final_odd, 2));
END;
$$;

-- FUNCTION: marino_play_horse_racing(text, integer, integer)
CREATE FUNCTION public.marino_play_horse_racing(p_telegram_id text, p_bet_amount integer, p_horse_id integer) RETURNS jsonb
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path = pg_catalog, public
    AS $$
DECLARE
    v_user record;
    v_winner INT;
    v_payout NUMERIC := 0;
    v_is_win BOOLEAN := false;
BEGIN
    SELECT * INTO v_user FROM public.marino_players WHERE telegram_id = p_telegram_id;
    IF v_user IS NULL THEN RAISE EXCEPTION 'Kullanıcı bulunamadı.'; END IF;
    IF p_bet_amount <= 0 THEN RAISE EXCEPTION 'Geçersiz bahis.'; END IF;
    IF v_user.casino_chips < p_bet_amount THEN RAISE EXCEPTION 'Yetersiz çip.'; END IF;

    UPDATE public.marino_players SET casino_chips = casino_chips - p_bet_amount WHERE telegram_id = p_telegram_id;

    -- Pick a winner (1 to 6)
    v_winner := floor(random() * 6) + 1;

    IF v_winner = p_horse_id THEN
        v_is_win := true;
        v_payout := p_bet_amount * 5.0; -- 5x multiplier for 1/6 odds
        UPDATE public.marino_players SET casino_chips = casino_chips + v_payout WHERE telegram_id = p_telegram_id;
    END IF;

    RETURN jsonb_build_object(
        'winner', v_winner,
        'is_win', v_is_win,
        'payout', v_payout,
        'new_balance', v_user.casino_chips - p_bet_amount + v_payout
    );
END;
$$;

-- FUNCTION: marino_play_mini_game(text, text, text)
CREATE FUNCTION public.marino_play_mini_game(p_telegram_id text, p_game_key text, p_request_id text DEFAULT ''::text) RETURNS jsonb
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path = pg_catalog, public
    AS $$
DECLARE
  v_player marino_players%ROWTYPE;
  v_daily_login marino_daily_login%ROWTYPE;
  v_ticket_cost INT;
  v_reward BIGINT;
  v_won BOOLEAN;
  v_roll NUMERIC;
  v_msg TEXT;
BEGIN
  IF p_request_id != '' THEN
    INSERT INTO marino_processed_requests (request_id) VALUES (p_request_id)
    ON CONFLICT DO NOTHING;
    IF NOT FOUND THEN RAISE EXCEPTION 'Bu işlem zaten işlendi.'; END IF;
  END IF;

  SELECT * INTO v_player FROM marino_players WHERE telegram_id = p_telegram_id;
  IF NOT FOUND THEN RAISE EXCEPTION 'Oyuncu bulunamadı.'; END IF;

  -- Günlük durumu al
  SELECT * INTO v_daily_login FROM marino_daily_login WHERE player_id = v_player.id;
  IF NOT FOUND THEN
    INSERT INTO marino_daily_login (player_id) VALUES (v_player.id) RETURNING * INTO v_daily_login;
  END IF;

  -- Gün geçtiyse sayacı sıfırla
  IF COALESCE(v_daily_login.last_login_date, '1970-01-01') < CURRENT_DATE THEN
    UPDATE marino_daily_login SET mini_games_played = 0 WHERE player_id = v_player.id
    RETURNING * INTO v_daily_login;
  END IF;

  IF v_daily_login.mini_games_played >= 6 THEN
    RAISE EXCEPTION 'Günlük mini oyun limitine ulaştınız. (Max 6)';
  END IF;

  -- Oyun türüne göre bilet maliyeti
  CASE p_game_key
    WHEN 'card' THEN v_ticket_cost := 25;
    WHEN 'wheel' THEN v_ticket_cost := 35;
    WHEN 'vault' THEN v_ticket_cost := 50;
    ELSE RAISE EXCEPTION 'Bilinmeyen mini oyun.';
  END CASE;

  IF v_player.reward_token < v_ticket_cost THEN
    RAISE EXCEPTION 'Yetersiz ödül bileti. Gerekli: %', v_ticket_cost;
  END IF;

  -- Şans hesaplama
  v_roll := random();

  CASE p_game_key
    WHEN 'card' THEN
      IF v_roll < 0.45 THEN v_won := TRUE; v_reward := 50 + FLOOR(random() * 200); v_msg := 'Kart çevir kazandın!';
      ELSE v_won := FALSE; v_reward := 0; v_msg := 'Kart çevir — kayıp.';
      END IF;
    WHEN 'wheel' THEN
      IF v_roll < 0.35 THEN v_won := TRUE; v_reward := 100 + FLOOR(random() * 500); v_msg := 'Şans çarkı kazandın!';
      ELSIF v_roll < 0.05 THEN v_won := TRUE; v_reward := 1000 + FLOOR(random() * 2000); v_msg := '🎉 JACKPOT!';
      ELSE v_won := FALSE; v_reward := 0; v_msg := 'Şans çarkı — kayıp.';
      END IF;
    WHEN 'vault' THEN
      IF v_roll < 0.30 THEN v_won := TRUE; v_reward := 250 + FLOOR(random() * 1000); v_msg := 'Kasa açıldı! Büyük ödül!';
      ELSE v_won := FALSE; v_reward := 0; v_msg := 'Kasa — kayıp.';
      END IF;
  END CASE;

  UPDATE marino_players SET
    reward_token = reward_token - v_ticket_cost,
    marino_coin = marino_coin + v_reward,
    reputation = reputation + 2,
    updated_at = NOW()
  WHERE id = v_player.id
  RETURNING * INTO v_player;

  UPDATE marino_daily_login SET
    mini_games_played = mini_games_played + 1
  WHERE player_id = v_player.id;

  RETURN jsonb_build_object(
    'state', jsonb_build_object(
      'marino_coin', v_player.marino_coin,
      'reward_token', v_player.reward_token,
      'energy', v_player.energy,
      'max_energy', v_player.max_energy,
      'tap_power', v_player.tap_power,
      'passive_income_per_hour', v_player.passive_income_per_hour,
      'casino_level', v_player.casino_level,
      'reputation', v_player.reputation,
      'claimable_coin', v_player.claimable_coin,
      'offline_capacity_hours', v_player.offline_capacity_hours,
      'prestige_points', v_player.prestige_points
    ),
    'won', v_won,
    'reward_coin', v_reward,
    'message', v_msg,
    'mini_games_played', COALESCE(v_daily_login.mini_games_played, 0) + 1
  );
END;
$$;

-- FUNCTION: marino_play_poker(text, integer)
CREATE FUNCTION public.marino_play_poker(p_telegram_id text, p_bet_amount integer) RETURNS jsonb
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path = pg_catalog, public
    AS $$
DECLARE
    v_user record;
    v_rnd INT;
    v_payout_mult INT;
    v_p_hand JSONB;
    v_d_hand JSONB;
    v_winner TEXT;
    v_desc TEXT;
    v_matrix RECORD;
BEGIN
    SELECT * INTO v_user FROM public.marino_players WHERE telegram_id = p_telegram_id;
    IF v_user IS NULL THEN RAISE EXCEPTION 'Kullanıcı bulunamadı.'; END IF;
    IF p_bet_amount <= 0 THEN RAISE EXCEPTION 'Geçersiz bahis.'; END IF;
    IF v_user.casino_chips < p_bet_amount THEN RAISE EXCEPTION 'Yetersiz çip.'; END IF;

    UPDATE public.marino_players SET casino_chips = casino_chips - p_bet_amount WHERE telegram_id = p_telegram_id;

    -- Temp table to hold matchups
    CREATE TEMP TABLE IF NOT EXISTS tmp_poker_matchups (
        id SERIAL, p_hand JSONB, d_hand JSONB, winner TEXT, payout INT, description TEXT
    ) ON COMMIT DROP;

    IF NOT EXISTS (SELECT 1 FROM tmp_poker_matchups) THEN
        INSERT INTO tmp_poker_matchups (p_hand, d_hand, winner, payout, description) VALUES
        ('["KC", "3H", "6S", "2H", "JD"]', '["10S", "7H", "JC", "4D", "KD"]', 'dealer', 0, 'Yüksek Kart (High Card) vs Yüksek Kart (High Card)'), ('["9D", "2H", "8H", "4H", "AD"]', '["4S", "2D", "10H", "7H", "5S"]', 'player', 2, 'Yüksek Kart (High Card) vs Yüksek Kart (High Card)'), ('["JH", "9C", "10H", "4S", "7H"]', '["7D", "7S", "QD", "3D", "7C"]', 'dealer', 0, 'Yüksek Kart (High Card) vs Üçlü (Three of a Kind)'), ('["2C", "10C", "5D", "9S", "7S"]', '["KS", "7H", "8D", "10H", "JH"]', 'dealer', 0, 'Yüksek Kart (High Card) vs Yüksek Kart (High Card)'), ('["5S", "AC", "5D", "10H", "10S"]', '["10D", "6H", "4D", "7S", "KS"]', 'player', 3, 'İki Döper (Two Pair) vs Yüksek Kart (High Card)'), ('["9C", "JC", "6C", "2S", "8D"]', '["5H", "3H", "KC", "AS", "7S"]', 'dealer', 0, 'Yüksek Kart (High Card) vs Yüksek Kart (High Card)'), ('["AD", "7S", "QD", "3S", "AS"]', '["QS", "9H", "KD", "10D", "4H"]', 'player', 2, 'Per (Pair) vs Yüksek Kart (High Card)'), ('["3D", "5S", "9D", "5D", "6H"]', '["8H", "8C", "JD", "5H", "JS"]', 'dealer', 0, 'Per (Pair) vs İki Döper (Two Pair)'), ('["QC", "9D", "3S", "AH", "KC"]', '["6S", "2H", "2C", "3H", "KH"]', 'dealer', 0, 'Yüksek Kart (High Card) vs Per (Pair)'), ('["QS", "AC", "KD", "2S", "10S"]', '["AH", "4D", "JH", "JC", "7D"]', 'dealer', 0, 'Yüksek Kart (High Card) vs Per (Pair)'), ('["QD", "5S", "10D", "6C", "JS"]', '["2H", "KS", "KH", "8S", "7S"]', 'dealer', 0, 'Yüksek Kart (High Card) vs Per (Pair)'), ('["5C", "8S", "QH", "9S", "KH"]', '["6D", "10C", "4C", "QD", "7D"]', 'player', 2, 'Yüksek Kart (High Card) vs Yüksek Kart (High Card)'), ('["AH", "10H", "5C", "7H", "JC"]', '["10C", "9S", "QC", "AS", "7D"]', 'dealer', 0, 'Yüksek Kart (High Card) vs Yüksek Kart (High Card)'), ('["QC", "6H", "10H", "9H", "5S"]', '["9D", "4S", "6S", "3C", "8D"]', 'player', 2, 'Yüksek Kart (High Card) vs Yüksek Kart (High Card)'), ('["9D", "QD", "JS", "5D", "AD"]', '["3C", "4D", "9S", "5H", "3H"]', 'dealer', 0, 'Yüksek Kart (High Card) vs Per (Pair)'), ('["KH", "6S", "JS", "6H", "3S"]', '["2S", "AS", "5C", "3C", "KC"]', 'player', 2, 'Per (Pair) vs Yüksek Kart (High Card)'), ('["5C", "7C", "6D", "7D", "8S"]', '["3C", "3D", "AS", "10H", "6H"]', 'dealer', 0, 'Per (Pair) vs Per (Pair)'), ('["JC", "6S", "7D", "8H", "2D"]', '["3S", "9C", "7S", "5S", "4H"]', 'player', 2, 'Yüksek Kart (High Card) vs Yüksek Kart (High Card)'), ('["3S", "KC", "6H", "7C", "5C"]', '["5D", "JH", "6S", "2D", "3D"]', 'player', 2, 'Yüksek Kart (High Card) vs Yüksek Kart (High Card)'), ('["KS", "8C", "3S", "2S", "JS"]', '["2C", "8S", "QH", "4C", "6H"]', 'player', 2, 'Yüksek Kart (High Card) vs Yüksek Kart (High Card)'), ('["9C", "4S", "7D", "4C", "KS"]', '["4H", "5S", "7H", "AD", "7S"]', 'dealer', 0, 'Per (Pair) vs Per (Pair)'), ('["9C", "2C", "8S", "10C", "6D"]', '["AD", "3C", "QS", "5D", "10H"]', 'dealer', 0, 'Yüksek Kart (High Card) vs Yüksek Kart (High Card)'), ('["8D", "KC", "4H", "3C", "2D"]', '["6C", "AH", "4D", "5D", "3H"]', 'dealer', 0, 'Yüksek Kart (High Card) vs Yüksek Kart (High Card)'), ('["QS", "JC", "3D", "AH", "KH"]', '["JH", "3H", "KC", "5S", "QC"]', 'player', 2, 'Yüksek Kart (High Card) vs Yüksek Kart (High Card)'), ('["5H", "7D", "9S", "9H", "JH"]', '["3C", "2D", "4S", "AD", "3H"]', 'dealer', 0, 'Per (Pair) vs Per (Pair)'), ('["8D", "2H", "JC", "4S", "KS"]', '["5H", "JH", "2C", "10D", "AC"]', 'dealer', 0, 'Yüksek Kart (High Card) vs Yüksek Kart (High Card)'), ('["10D", "QH", "9S", "AH", "5S"]', '["3S", "8H", "9C", "JS", "5D"]', 'player', 2, 'Yüksek Kart (High Card) vs Yüksek Kart (High Card)'), ('["10H", "KD", "3C", "9S", "QS"]', '["JS", "AH", "8D", "AS", "4S"]', 'dealer', 0, 'Yüksek Kart (High Card) vs Per (Pair)'), ('["KH", "2S", "4C", "7S", "8H"]', '["8D", "KD", "QD", "7D", "4S"]', 'dealer', 0, 'Yüksek Kart (High Card) vs Yüksek Kart (High Card)'), ('["10S", "AS", "5H", "8C", "AD"]', '["9S", "KC", "9D", "8S", "QC"]', 'player', 2, 'Per (Pair) vs Per (Pair)'), ('["10H", "8H", "10S", "5C", "JH"]', '["QC", "9D", "10C", "3H", "2D"]', 'player', 2, 'Per (Pair) vs Yüksek Kart (High Card)'), ('["JH", "KH", "KC", "7C", "2S"]', '["JD", "4S", "9H", "5H", "3S"]', 'player', 2, 'Per (Pair) vs Yüksek Kart (High Card)'), ('["4D", "2H", "KC", "7C", "JC"]', '["8H", "5H", "10C", "8D", "9H"]', 'dealer', 0, 'Yüksek Kart (High Card) vs Per (Pair)'), ('["5D", "9S", "JD", "5H", "2S"]', '["10C", "AS", "4S", "7C", "3D"]', 'player', 2, 'Per (Pair) vs Yüksek Kart (High Card)'), ('["3S", "10S", "2D", "3H", "5H"]', '["2C", "6S", "7S", "7D", "2H"]', 'dealer', 0, 'Per (Pair) vs İki Döper (Two Pair)'), ('["10H", "9H", "5S", "QD", "8S"]', '["KC", "9C", "9S", "4D", "7S"]', 'dealer', 0, 'Yüksek Kart (High Card) vs Per (Pair)'), ('["5H", "5D", "10C", "3D", "4C"]', '["8S", "8C", "KD", "10H", "6C"]', 'dealer', 0, 'Per (Pair) vs Per (Pair)'), ('["QC", "JC", "7C", "QH", "7D"]', '["7H", "AH", "5H", "2H", "9H"]', 'dealer', 0, 'İki Döper (Two Pair) vs Renk (Flush)'), ('["5D", "AD", "10S", "AS", "8S"]', '["9H", "KS", "10C", "3S", "5C"]', 'player', 2, 'Per (Pair) vs Yüksek Kart (High Card)'), ('["3S", "5H", "6C", "7C", "AH"]', '["4D", "KD", "KC", "10S", "2S"]', 'dealer', 0, 'Yüksek Kart (High Card) vs Per (Pair)'), ('["2H", "8C", "10S", "2S", "AH"]', '["9C", "KS", "5H", "2D", "9S"]', 'player', 2, 'Per (Pair) vs Per (Pair)'), ('["10D", "10C", "JC", "7D", "9H"]', '["2H", "5H", "8S", "2S", "9D"]', 'player', 2, 'Per (Pair) vs Per (Pair)'), ('["8C", "QD", "5S", "6S", "AS"]', '["4D", "2D", "5C", "QS", "JD"]', 'player', 2, 'Yüksek Kart (High Card) vs Yüksek Kart (High Card)'), ('["KC", "8H", "7S", "7C", "6H"]', '["7D", "JC", "4D", "9H", "8C"]', 'player', 2, 'Per (Pair) vs Yüksek Kart (High Card)'), ('["9D", "5H", "7C", "QH", "JS"]', '["JC", "KD", "QD", "9C", "2D"]', 'dealer', 0, 'Yüksek Kart (High Card) vs Yüksek Kart (High Card)'), ('["2S", "6C", "5C", "5S", "4H"]', '["10C", "AH", "QC", "AC", "10H"]', 'dealer', 0, 'Per (Pair) vs İki Döper (Two Pair)'), ('["KC", "AH", "KD", "10H", "4H"]', '["10S", "10C", "7H", "3S", "2H"]', 'player', 2, 'Per (Pair) vs Per (Pair)'), ('["JS", "4H", "3D", "10S", "AD"]', '["QH", "9D", "7S", "2S", "6H"]', 'player', 2, 'Yüksek Kart (High Card) vs Yüksek Kart (High Card)'), ('["4C", "KS", "2D", "5S", "10H"]', '["JH", "7C", "7S", "AD", "AH"]', 'dealer', 0, 'Yüksek Kart (High Card) vs İki Döper (Two Pair)'), ('["8H", "4H", "7H", "JH", "3C"]', '["JC", "2H", "QS", "2C", "9S"]', 'dealer', 0, 'Yüksek Kart (High Card) vs Per (Pair)'), ('["3C", "5D", "QS", "3D", "5S"]', '["JS", "10H", "2D", "KC", "9D"]', 'player', 3, 'İki Döper (Two Pair) vs Yüksek Kart (High Card)'), ('["10S", "5S", "AD", "KC", "AS"]', '["3H", "QH", "AC", "JC", "4H"]', 'player', 2, 'Per (Pair) vs Yüksek Kart (High Card)'), ('["4H", "10S", "JD", "3H", "QC"]', '["2D", "10H", "7S", "3C", "AC"]', 'dealer', 0, 'Yüksek Kart (High Card) vs Yüksek Kart (High Card)'), ('["6D", "QS", "AC", "10C", "8D"]', '["JH", "4H", "9H", "JS", "9S"]', 'dealer', 0, 'Yüksek Kart (High Card) vs İki Döper (Two Pair)'), ('["2S", "7H", "10S", "3C", "4C"]', '["10H", "KH", "9D", "3H", "JS"]', 'dealer', 0, 'Yüksek Kart (High Card) vs Yüksek Kart (High Card)'), ('["JH", "AC", "10C", "5C", "AS"]', '["4C", "9S", "8C", "6C", "9D"]', 'player', 2, 'Per (Pair) vs Per (Pair)'), ('["10H", "KD", "4C", "JC", "QC"]', '["KS", "5H", "10S", "10D", "KC"]', 'dealer', 0, 'Yüksek Kart (High Card) vs İki Döper (Two Pair)'), ('["6D", "AD", "6H", "9C", "7C"]', '["5S", "QC", "AC", "QS", "KC"]', 'dealer', 0, 'Per (Pair) vs Per (Pair)'), ('["4S", "KC", "QS", "3D", "6H"]', '["2C", "5D", "6D", "8H", "QH"]', 'player', 2, 'Yüksek Kart (High Card) vs Yüksek Kart (High Card)'), ('["7D", "KH", "3S", "5C", "AD"]', '["8H", "9C", "10C", "QH", "4D"]', 'player', 2, 'Yüksek Kart (High Card) vs Yüksek Kart (High Card)'), ('["AC", "JC", "9S", "8H", "5C"]', '["8C", "3C", "4H", "KS", "AH"]', 'dealer', 0, 'Yüksek Kart (High Card) vs Yüksek Kart (High Card)'), ('["6D", "3S", "QH", "10C", "AD"]', '["10D", "5C", "8C", "9H", "9D"]', 'dealer', 0, 'Yüksek Kart (High Card) vs Per (Pair)'), ('["9H", "KH", "3H", "3D", "6D"]', '["KC", "JC", "2H", "2D", "JH"]', 'dealer', 0, 'Per (Pair) vs İki Döper (Two Pair)'), ('["3C", "3S", "KH", "KC", "QS"]', '["3D", "5C", "5D", "9H", "10C"]', 'player', 3, 'İki Döper (Two Pair) vs Per (Pair)'), ('["4D", "KD", "7S", "8S", "4H"]', '["5H", "9D", "8D", "4C", "6H"]', 'player', 2, 'Per (Pair) vs Yüksek Kart (High Card)'), ('["9C", "2C", "QD", "10D", "4H"]', '["8H", "AS", "5S", "JC", "3C"]', 'dealer', 0, 'Yüksek Kart (High Card) vs Yüksek Kart (High Card)'), ('["6S", "7S", "KD", "QC", "8H"]', '["QS", "5H", "AS", "QH", "7D"]', 'dealer', 0, 'Yüksek Kart (High Card) vs Per (Pair)'), ('["7D", "5D", "9C", "4S", "5C"]', '["6C", "2H", "2C", "QD", "3S"]', 'dealer', 0, 'Per (Pair) vs Per (Pair)'), ('["10H", "QH", "6H", "JH", "10S"]', '["7H", "AS", "5H", "2S", "AD"]', 'dealer', 0, 'Per (Pair) vs Per (Pair)'), ('["7S", "6H", "10D", "7H", "5S"]', '["JD", "JH", "4C", "AD", "QD"]', 'dealer', 0, 'Per (Pair) vs Per (Pair)'), ('["8H", "KH", "2C", "5D", "10D"]', '["10C", "2D", "AH", "7S", "3S"]', 'dealer', 0, 'Yüksek Kart (High Card) vs Yüksek Kart (High Card)'), ('["KH", "7S", "QD", "JD", "2D"]', '["10H", "4H", "3S", "9H", "JH"]', 'player', 2, 'Yüksek Kart (High Card) vs Yüksek Kart (High Card)'), ('["7H", "10S", "QH", "3D", "JS"]', '["KH", "2C", "2S", "7S", "7C"]', 'dealer', 0, 'Yüksek Kart (High Card) vs İki Döper (Two Pair)'), ('["AC", "5C", "QH", "AH", "4S"]', '["8S", "7D", "QD", "JS", "8C"]', 'player', 2, 'Per (Pair) vs Per (Pair)'), ('["QH", "7D", "7H", "JH", "KC"]', '["AH", "9H", "8C", "JD", "7C"]', 'player', 2, 'Per (Pair) vs Yüksek Kart (High Card)'), ('["KS", "6H", "4D", "JH", "9H"]', '["AS", "3S", "8D", "AC", "5H"]', 'dealer', 0, 'Yüksek Kart (High Card) vs Per (Pair)'), ('["3S", "AH", "6S", "5C", "2C"]', '["8D", "KD", "QS", "6H", "7C"]', 'player', 2, 'Yüksek Kart (High Card) vs Yüksek Kart (High Card)'), ('["10D", "3S", "10C", "JS", "9H"]', '["AC", "4H", "QH", "9C", "5D"]', 'player', 2, 'Per (Pair) vs Yüksek Kart (High Card)'), ('["2H", "JS", "JD", "JH", "4H"]', '["5H", "9S", "7D", "8H", "9D"]', 'player', 3, 'Üçlü (Three of a Kind) vs Per (Pair)'), ('["9C", "10H", "2H", "7C", "8S"]', '["8D", "3D", "9D", "4S", "4C"]', 'dealer', 0, 'Yüksek Kart (High Card) vs Per (Pair)'), ('["AH", "AC", "8C", "9H", "7H"]', '["3S", "JD", "QD", "10C", "9C"]', 'player', 2, 'Per (Pair) vs Yüksek Kart (High Card)'), ('["6S", "2S", "3S", "KD", "5C"]', '["AD", "8C", "AS", "3H", "KS"]', 'dealer', 0, 'Yüksek Kart (High Card) vs Per (Pair)'), ('["AH", "9H", "8D", "10H", "JS"]', '["9C", "4S", "JC", "6D", "KS"]', 'player', 2, 'Yüksek Kart (High Card) vs Yüksek Kart (High Card)'), ('["6H", "4C", "8H", "AD", "3C"]', '["JD", "QH", "3H", "AC", "KD"]', 'dealer', 0, 'Yüksek Kart (High Card) vs Yüksek Kart (High Card)'), ('["3D", "4C", "AC", "6S", "5D"]', '["6D", "QS", "8D", "4H", "7D"]', 'player', 2, 'Yüksek Kart (High Card) vs Yüksek Kart (High Card)'), ('["4D", "5H", "10D", "6C", "8S"]', '["3S", "4C", "AS", "5C", "2C"]', 'dealer', 0, 'Yüksek Kart (High Card) vs Kent (Straight)'), ('["6S", "AS", "JC", "10S", "8D"]', '["JH", "5S", "6C", "5C", "AC"]', 'dealer', 0, 'Yüksek Kart (High Card) vs Per (Pair)'), ('["QH", "5S", "7S", "9S", "KC"]', '["9D", "4S", "8H", "2S", "6C"]', 'player', 2, 'Yüksek Kart (High Card) vs Yüksek Kart (High Card)'), ('["3D", "8S", "QS", "5S", "6H"]', '["2C", "2S", "JH", "KS", "8D"]', 'dealer', 0, 'Yüksek Kart (High Card) vs Per (Pair)'), ('["10D", "JS", "AC", "9D", "8D"]', '["QC", "KC", "AD", "6C", "7C"]', 'dealer', 0, 'Yüksek Kart (High Card) vs Yüksek Kart (High Card)'), ('["JS", "2C", "2S", "JH", "KC"]', '["QH", "4H", "AH", "6C", "9H"]', 'player', 3, 'İki Döper (Two Pair) vs Yüksek Kart (High Card)'), ('["9S", "KC", "7C", "JD", "9C"]', '["7D", "8S", "4C", "10D", "2D"]', 'player', 2, 'Per (Pair) vs Yüksek Kart (High Card)'), ('["7D", "6S", "10S", "5S", "3S"]', '["JC", "AC", "AS", "4S", "2C"]', 'dealer', 0, 'Yüksek Kart (High Card) vs Per (Pair)'), ('["10H", "KC", "KS", "8S", "8C"]', '["3C", "AD", "7D", "2S", "3H"]', 'player', 3, 'İki Döper (Two Pair) vs Per (Pair)'), ('["6H", "JS", "7C", "3C", "JD"]', '["KD", "6D", "AC", "9H", "3S"]', 'player', 2, 'Per (Pair) vs Yüksek Kart (High Card)'), ('["KC", "7D", "9C", "9D", "2D"]', '["9S", "6D", "KS", "QD", "3H"]', 'player', 2, 'Per (Pair) vs Yüksek Kart (High Card)'), ('["QD", "2D", "2C", "6S", "KH"]', '["6C", "JD", "9D", "AD", "8H"]', 'player', 2, 'Per (Pair) vs Yüksek Kart (High Card)'), ('["AD", "3C", "10S", "KS", "8S"]', '["6C", "5H", "JH", "AH", "6H"]', 'dealer', 0, 'Yüksek Kart (High Card) vs Per (Pair)'), ('["6S", "KD", "AS", "KC", "3D"]', '["QH", "KS", "JC", "4D", "9S"]', 'player', 2, 'Per (Pair) vs Yüksek Kart (High Card)'), ('["5S", "QD", "QS", "4H", "9S"]', '["6S", "8S", "7H", "AC", "4S"]', 'player', 2, 'Per (Pair) vs Yüksek Kart (High Card)'), ('["10H", "2H", "3H", "QS", "2C"]', '["10C", "8H", "8C", "JD", "6C"]', 'player', 2, 'Per (Pair) vs Per (Pair)'), ('["5H", "6H", "3D", "QH", "2C"]', '["2S", "KH", "QS", "AC", "2D"]', 'dealer', 0, 'Yüksek Kart (High Card) vs Per (Pair)'), ('["6S", "KS", "5S", "8D", "2D"]', '["QH", "JH", "3D", "9S", "KD"]', 'dealer', 0, 'Yüksek Kart (High Card) vs Yüksek Kart (High Card)'), ('["8D", "3S", "KH", "QH", "5S"]', '["6C", "JH", "4H", "9C", "3C"]', 'player', 2, 'Yüksek Kart (High Card) vs Yüksek Kart (High Card)'), ('["5D", "5S", "10S", "JC", "QD"]', '["KD", "AD", "AC", "7H", "10C"]', 'dealer', 0, 'Per (Pair) vs Per (Pair)'), ('["7S", "6C", "10D", "4H", "JS"]', '["3H", "9H", "7C", "QC", "5S"]', 'dealer', 0, 'Yüksek Kart (High Card) vs Yüksek Kart (High Card)'), ('["9H", "2S", "4C", "5H", "QC"]', '["KH", "7H", "9S", "JS", "JC"]', 'dealer', 0, 'Yüksek Kart (High Card) vs Per (Pair)'), ('["AS", "3D", "2D", "JC", "5D"]', '["3C", "2S", "8S", "6D", "QS"]', 'player', 2, 'Yüksek Kart (High Card) vs Yüksek Kart (High Card)'), ('["6S", "5S", "9H", "3D", "KH"]', '["9S", "10C", "AC", "QC", "6C"]', 'dealer', 0, 'Yüksek Kart (High Card) vs Yüksek Kart (High Card)'), ('["10S", "3D", "9H", "4S", "7S"]', '["5S", "AH", "6H", "8H", "JC"]', 'dealer', 0, 'Yüksek Kart (High Card) vs Yüksek Kart (High Card)'), ('["4H", "5S", "AS", "KH", "9S"]', '["2H", "JC", "6C", "3C", "KS"]', 'player', 2, 'Yüksek Kart (High Card) vs Yüksek Kart (High Card)'), ('["2C", "2H", "KC", "AH", "6H"]', '["7C", "QH", "6S", "AS", "JD"]', 'player', 2, 'Per (Pair) vs Yüksek Kart (High Card)'), ('["8H", "JS", "JH", "3S", "2H"]', '["3H", "AD", "10S", "KD", "9S"]', 'player', 2, 'Per (Pair) vs Yüksek Kart (High Card)'), ('["6C", "3S", "4D", "5D", "2D"]', '["KS", "10C", "8H", "5C", "8S"]', 'player', 5, 'Kent (Straight) vs Per (Pair)'), ('["4H", "7H", "4S", "8S", "2H"]', '["AS", "QH", "KC", "AC", "10D"]', 'dealer', 0, 'Per (Pair) vs Per (Pair)'), ('["5S", "4S", "KH", "2S", "JS"]', '["JC", "2D", "7H", "AC", "7C"]', 'dealer', 0, 'Yüksek Kart (High Card) vs Per (Pair)'), ('["JC", "JD", "KD", "6H", "10D"]', '["2D", "JS", "5H", "4H", "7S"]', 'player', 2, 'Per (Pair) vs Yüksek Kart (High Card)'), ('["2S", "8C", "4C", "7H", "8H"]', '["4H", "5H", "9S", "AS", "6S"]', 'player', 2, 'Per (Pair) vs Yüksek Kart (High Card)'), ('["QD", "9D", "9H", "9C", "6D"]', '["6S", "KH", "AC", "10C", "6H"]', 'player', 3, 'Üçlü (Three of a Kind) vs Per (Pair)'), ('["8S", "JD", "3H", "AC", "2S"]', '["3S", "JH", "JS", "8D", "JC"]', 'dealer', 0, 'Yüksek Kart (High Card) vs Üçlü (Three of a Kind)'), ('["9S", "3H", "QD", "5H", "10C"]', '["AD", "6S", "10D", "2S", "JH"]', 'dealer', 0, 'Yüksek Kart (High Card) vs Yüksek Kart (High Card)'), ('["4D", "JD", "8H", "9D", "4C"]', '["KD", "4H", "6H", "AD", "10C"]', 'player', 2, 'Per (Pair) vs Yüksek Kart (High Card)'), ('["4H", "3D", "3S", "10H", "2C"]', '["8H", "5C", "AC", "JH", "4S"]', 'player', 2, 'Per (Pair) vs Yüksek Kart (High Card)'), ('["2H", "10D", "7C", "8H", "6C"]', '["7S", "8C", "5S", "5D", "8D"]', 'dealer', 0, 'Yüksek Kart (High Card) vs İki Döper (Two Pair)'), ('["5D", "8C", "AH", "10H", "5C"]', '["QS", "10S", "8S", "KH", "9C"]', 'player', 2, 'Per (Pair) vs Yüksek Kart (High Card)'), ('["10D", "7D", "6H", "3C", "QH"]', '["KH", "6D", "6S", "3H", "KD"]', 'dealer', 0, 'Yüksek Kart (High Card) vs İki Döper (Two Pair)'), ('["QH", "8D", "7C", "JS", "3H"]', '["8C", "6H", "4S", "2H", "6C"]', 'dealer', 0, 'Yüksek Kart (High Card) vs Per (Pair)'), ('["4C", "JC", "8C", "10D", "10H"]', '["10C", "6H", "KS", "KH", "4H"]', 'dealer', 0, 'Per (Pair) vs Per (Pair)'), ('["5C", "QD", "9C", "2C", "2S"]', '["7H", "8S", "4C", "10S", "JS"]', 'player', 2, 'Per (Pair) vs Yüksek Kart (High Card)'), ('["QC", "2D", "AH", "JS", "KD"]', '["4H", "10D", "5D", "5H", "3D"]', 'dealer', 0, 'Yüksek Kart (High Card) vs Per (Pair)'), ('["10S", "3S", "AS", "6S", "2H"]', '["5D", "AD", "KD", "4D", "KC"]', 'dealer', 0, 'Yüksek Kart (High Card) vs Per (Pair)'), ('["4D", "7H", "2S", "10C", "8D"]', '["2C", "5D", "AH", "5C", "KS"]', 'dealer', 0, 'Yüksek Kart (High Card) vs Per (Pair)'), ('["2S", "5H", "JD", "3D", "QS"]', '["AC", "KS", "10C", "JC", "QH"]', 'dealer', 0, 'Yüksek Kart (High Card) vs Kent (Straight)'), ('["6C", "4H", "AC", "10H", "3S"]', '["3D", "2C", "QC", "8D", "10D"]', 'player', 2, 'Yüksek Kart (High Card) vs Yüksek Kart (High Card)'), ('["3C", "3D", "8D", "8C", "5S"]', '["3H", "AD", "QD", "QH", "4C"]', 'player', 3, 'İki Döper (Two Pair) vs Per (Pair)'), ('["4D", "4S", "3D", "7D", "3H"]', '["2D", "2H", "KD", "9D", "10H"]', 'player', 3, 'İki Döper (Two Pair) vs Per (Pair)'), ('["QD", "AC", "3C", "5S", "JD"]', '["2D", "6C", "5C", "4H", "9H"]', 'player', 2, 'Yüksek Kart (High Card) vs Yüksek Kart (High Card)'), ('["KD", "5D", "3D", "KS", "6C"]', '["7H", "2D", "AD", "JH", "3S"]', 'player', 2, 'Per (Pair) vs Yüksek Kart (High Card)'), ('["AD", "4S", "9H", "9D", "AC"]', '["4H", "10C", "8S", "4D", "9S"]', 'player', 3, 'İki Döper (Two Pair) vs Per (Pair)'), ('["QC", "3S", "8H", "4H", "KH"]', '["KD", "6S", "10D", "7C", "JH"]', 'player', 2, 'Yüksek Kart (High Card) vs Yüksek Kart (High Card)'), ('["5S", "JD", "4C", "6H", "2C"]', '["2D", "10S", "4H", "QS", "4S"]', 'dealer', 0, 'Yüksek Kart (High Card) vs Per (Pair)'), ('["4S", "AH", "10C", "6D", "4D"]', '["10H", "3H", "KD", "9S", "4H"]', 'player', 2, 'Per (Pair) vs Yüksek Kart (High Card)'), ('["KS", "6H", "10S", "10H", "3D"]', '["9C", "4C", "AS", "AC", "QC"]', 'dealer', 0, 'Per (Pair) vs Per (Pair)'), ('["5H", "AS", "2C", "9D", "5D"]', '["AC", "5C", "8H", "2D", "6S"]', 'player', 2, 'Per (Pair) vs Yüksek Kart (High Card)'), ('["AS", "4S", "JD", "3C", "7S"]', '["QS", "2C", "JS", "8C", "8S"]', 'dealer', 0, 'Yüksek Kart (High Card) vs Per (Pair)'), ('["KC", "2S", "7H", "KS", "8D"]', '["9C", "KD", "AD", "3S", "2H"]', 'player', 2, 'Per (Pair) vs Yüksek Kart (High Card)'), ('["7C", "9H", "10D", "2C", "4C"]', '["6C", "JC", "JD", "5D", "AS"]', 'dealer', 0, 'Yüksek Kart (High Card) vs Per (Pair)'), ('["7C", "10D", "3D", "4H", "3S"]', '["KC", "KD", "9H", "6C", "JH"]', 'dealer', 0, 'Per (Pair) vs Per (Pair)'), ('["6C", "10D", "7H", "2H", "8H"]', '["8S", "3D", "JH", "4H", "7D"]', 'dealer', 0, 'Yüksek Kart (High Card) vs Yüksek Kart (High Card)'), ('["7H", "KC", "QC", "AS", "3H"]', '["KD", "8D", "3S", "QS", "7D"]', 'player', 2, 'Yüksek Kart (High Card) vs Yüksek Kart (High Card)'), ('["7H", "5D", "6D", "AC", "7S"]', '["9C", "8D", "AH", "8C", "7D"]', 'dealer', 0, 'Per (Pair) vs Per (Pair)'), ('["QH", "KD", "10S", "9C", "5S"]', '["9S", "4H", "9H", "8D", "8S"]', 'dealer', 0, 'Yüksek Kart (High Card) vs İki Döper (Two Pair)'), ('["3C", "3S", "AS", "3H", "7H"]', '["7C", "KS", "AD", "10D", "QS"]', 'player', 3, 'Üçlü (Three of a Kind) vs Yüksek Kart (High Card)'), ('["JC", "AC", "8S", "9D", "4C"]', '["9C", "AD", "8D", "6H", "5D"]', 'player', 2, 'Yüksek Kart (High Card) vs Yüksek Kart (High Card)'), ('["10C", "8C", "10H", "KS", "6S"]', '["3C", "5C", "4H", "JC", "AD"]', 'player', 2, 'Per (Pair) vs Yüksek Kart (High Card)'), ('["2C", "3S", "8S", "9C", "5C"]', '["10H", "QS", "7H", "3C", "8C"]', 'dealer', 0, 'Yüksek Kart (High Card) vs Yüksek Kart (High Card)'), ('["3D", "6H", "10H", "10D", "8S"]', '["JH", "7S", "7H", "AH", "2D"]', 'dealer', 0, 'Per (Pair) vs Per (Pair)'), ('["AD", "6H", "JD", "8D", "6D"]', '["10D", "AS", "2D", "7S", "8C"]', 'player', 2, 'Per (Pair) vs Yüksek Kart (High Card)'), ('["7S", "5C", "8D", "5D", "3S"]', '["6H", "9S", "4H", "JH", "KD"]', 'player', 2, 'Per (Pair) vs Yüksek Kart (High Card)'), ('["QD", "KH", "10C", "QS", "2H"]', '["9S", "QH", "5S", "AH", "KS"]', 'player', 2, 'Per (Pair) vs Yüksek Kart (High Card)'), ('["2H", "9S", "8C", "5S", "AH"]', '["AC", "JS", "8H", "10S", "10D"]', 'dealer', 0, 'Yüksek Kart (High Card) vs Per (Pair)'), ('["QD", "2H", "5S", "KC", "AS"]', '["9S", "10D", "AD", "7H", "4C"]', 'player', 2, 'Yüksek Kart (High Card) vs Yüksek Kart (High Card)'), ('["4S", "KH", "KD", "AS", "5H"]', '["5S", "7C", "10H", "JC", "4D"]', 'player', 2, 'Per (Pair) vs Yüksek Kart (High Card)'), ('["3S", "8S", "JS", "7D", "6S"]', '["QS", "9D", "JC", "AD", "QD"]', 'dealer', 0, 'Yüksek Kart (High Card) vs Per (Pair)'), ('["10S", "4H", "6D", "3C", "2S"]', '["5S", "7C", "JC", "6H", "QC"]', 'dealer', 0, 'Yüksek Kart (High Card) vs Yüksek Kart (High Card)'), ('["10C", "JS", "5S", "JH", "3D"]', '["5H", "9C", "QH", "2D", "QD"]', 'dealer', 0, 'Per (Pair) vs Per (Pair)'), ('["8S", "QC", "6S", "AC", "JH"]', '["5C", "4C", "2D", "AS", "7H"]', 'player', 2, 'Yüksek Kart (High Card) vs Yüksek Kart (High Card)'), ('["9H", "6S", "QC", "AS", "AD"]', '["4D", "JH", "AH", "9D", "JC"]', 'player', 2, 'Per (Pair) vs Per (Pair)'), ('["QD", "2D", "QS", "9D", "6S"]', '["4H", "7H", "8H", "KC", "9C"]', 'player', 2, 'Per (Pair) vs Yüksek Kart (High Card)'), ('["8H", "10D", "9C", "KH", "JD"]', '["QS", "10S", "QD", "3H", "9S"]', 'dealer', 0, 'Yüksek Kart (High Card) vs Per (Pair)'), ('["8S", "JD", "3D", "KH", "10S"]', '["QD", "9C", "10D", "8D", "8C"]', 'dealer', 0, 'Yüksek Kart (High Card) vs Per (Pair)'), ('["3H", "JS", "4H", "AH", "10D"]', '["6H", "QH", "5H", "5C", "QD"]', 'dealer', 0, 'Yüksek Kart (High Card) vs İki Döper (Two Pair)'), ('["9C", "5H", "AH", "3H", "7S"]', '["3S", "8D", "JH", "AD", "AS"]', 'dealer', 0, 'Yüksek Kart (High Card) vs Per (Pair)'), ('["4C", "KS", "8C", "JS", "7H"]', '["2C", "8D", "6C", "9D", "6H"]', 'dealer', 0, 'Yüksek Kart (High Card) vs Per (Pair)'), ('["AS", "JC", "8C", "2H", "6S"]', '["3C", "QH", "4H", "7D", "9S"]', 'player', 2, 'Yüksek Kart (High Card) vs Yüksek Kart (High Card)'), ('["3S", "8C", "5S", "2D", "3H"]', '["6D", "4H", "KC", "KD", "2S"]', 'dealer', 0, 'Per (Pair) vs Per (Pair)'), ('["2C", "JH", "10H", "JC", "8S"]', '["4D", "2S", "6H", "3S", "7D"]', 'player', 2, 'Per (Pair) vs Yüksek Kart (High Card)'), ('["9H", "6S", "4H", "10C", "5D"]', '["9S", "8C", "7C", "10D", "KH"]', 'dealer', 0, 'Yüksek Kart (High Card) vs Yüksek Kart (High Card)'), ('["2S", "9H", "2D", "10D", "KD"]', '["4D", "KS", "3S", "AC", "8H"]', 'player', 2, 'Per (Pair) vs Yüksek Kart (High Card)'), ('["2D", "AD", "4D", "3H", "4S"]', '["8C", "2S", "QS", "7D", "JC"]', 'player', 2, 'Per (Pair) vs Yüksek Kart (High Card)'), ('["3H", "JD", "3S", "7S", "AD"]', '["10S", "8S", "7D", "5S", "KD"]', 'player', 2, 'Per (Pair) vs Yüksek Kart (High Card)'), ('["9D", "5D", "QD", "4C", "JD"]', '["JC", "3D", "QC", "KC", "9S"]', 'dealer', 0, 'Yüksek Kart (High Card) vs Yüksek Kart (High Card)'), ('["8S", "2S", "2C", "2H", "3D"]', '["10H", "JD", "QS", "6S", "5H"]', 'player', 3, 'Üçlü (Three of a Kind) vs Yüksek Kart (High Card)'), ('["9H", "8H", "5S", "KC", "5H"]', '["4C", "5C", "4D", "QD", "2S"]', 'player', 2, 'Per (Pair) vs Per (Pair)'), ('["6D", "4S", "7S", "5S", "4D"]', '["8C", "3C", "9C", "QD", "4H"]', 'player', 2, 'Per (Pair) vs Yüksek Kart (High Card)'), ('["10C", "7S", "5S", "5D", "6C"]', '["9D", "QC", "9C", "4S", "4C"]', 'dealer', 0, 'Per (Pair) vs İki Döper (Two Pair)'), ('["6C", "4H", "10C", "6D", "KH"]', '["10H", "2S", "KS", "JD", "JS"]', 'dealer', 0, 'Per (Pair) vs Per (Pair)'), ('["8H", "9D", "JC", "6D", "5D"]', '["2H", "9C", "5H", "KC", "7C"]', 'dealer', 0, 'Yüksek Kart (High Card) vs Yüksek Kart (High Card)'), ('["8S", "3H", "QC", "10S", "4D"]', '["6S", "QD", "3S", "2C", "2D"]', 'dealer', 0, 'Yüksek Kart (High Card) vs Per (Pair)'), ('["QC", "8D", "5C", "2S", "KC"]', '["JS", "8H", "5S", "4S", "8S"]', 'dealer', 0, 'Yüksek Kart (High Card) vs Per (Pair)'), ('["3D", "AC", "AD", "6D", "KH"]', '["10D", "9D", "KS", "JH", "JC"]', 'player', 2, 'Per (Pair) vs Per (Pair)'), ('["AS", "5D", "6C", "10S", "9H"]', '["8S", "7D", "8D", "AC", "KD"]', 'dealer', 0, 'Yüksek Kart (High Card) vs Per (Pair)'), ('["KH", "4C", "2S", "9H", "KC"]', '["AC", "QH", "5C", "KD", "10D"]', 'player', 2, 'Per (Pair) vs Yüksek Kart (High Card)'), ('["2S", "4D", "KC", "7C", "8C"]', '["10H", "KH", "AC", "KS", "AD"]', 'dealer', 0, 'Yüksek Kart (High Card) vs İki Döper (Two Pair)'), ('["7D", "8H", "KC", "3D", "7C"]', '["10D", "8S", "7H", "AS", "10S"]', 'dealer', 0, 'Per (Pair) vs Per (Pair)'), ('["JH", "2H", "7S", "2C", "10C"]', '["8D", "8H", "7C", "3S", "QD"]', 'dealer', 0, 'Per (Pair) vs Per (Pair)'), ('["2H", "8C", "7D", "6H", "8H"]', '["7H", "10C", "9H", "6S", "QS"]', 'player', 2, 'Per (Pair) vs Yüksek Kart (High Card)'), ('["9C", "2S", "8H", "QC", "5S"]', '["9H", "KH", "JS", "QS", "4H"]', 'dealer', 0, 'Yüksek Kart (High Card) vs Yüksek Kart (High Card)'), ('["AC", "4S", "4D", "3S", "JS"]', '["JC", "AS", "6S", "QC", "7H"]', 'player', 2, 'Per (Pair) vs Yüksek Kart (High Card)'), ('["5S", "9H", "6S", "10D", "9S"]', '["2H", "5D", "10C", "4S", "KD"]', 'player', 2, 'Per (Pair) vs Yüksek Kart (High Card)'), ('["QS", "10C", "7H", "2C", "4S"]', '["8C", "6D", "5C", "AD", "JC"]', 'dealer', 0, 'Yüksek Kart (High Card) vs Yüksek Kart (High Card)'), ('["5S", "10S", "JD", "KH", "AD"]', '["3H", "AS", "AC", "6H", "4C"]', 'dealer', 0, 'Yüksek Kart (High Card) vs Per (Pair)'), ('["3D", "AH", "10S", "3S", "8H"]', '["5H", "5C", "2C", "4H", "5D"]', 'dealer', 0, 'Per (Pair) vs Üçlü (Three of a Kind)'), ('["7H", "8D", "2C", "4D", "10C"]', '["KC", "KS", "6S", "5D", "QH"]', 'dealer', 0, 'Yüksek Kart (High Card) vs Per (Pair)'), ('["6S", "10H", "7C", "JD", "2D"]', '["5C", "9D", "AC", "10D", "7D"]', 'dealer', 0, 'Yüksek Kart (High Card) vs Yüksek Kart (High Card)'), ('["5D", "4S", "3S", "8H", "5S"]', '["10C", "6D", "AH", "8S", "AC"]', 'dealer', 0, 'Per (Pair) vs Per (Pair)'), ('["9C", "AD", "KS", "QD", "QC"]', '["3D", "JS", "AS", "QH", "2C"]', 'player', 2, 'Per (Pair) vs Yüksek Kart (High Card)'), ('["9S", "AH", "QD", "4D", "7C"]', '["5H", "6S", "3H", "8D", "AS"]', 'player', 2, 'Yüksek Kart (High Card) vs Yüksek Kart (High Card)'), ('["6S", "KH", "KC", "3H", "3C"]', '["8D", "5H", "AS", "2D", "2H"]', 'player', 3, 'İki Döper (Two Pair) vs Per (Pair)'), ('["AH", "JD", "4C", "3H", "7S"]', '["QS", "3C", "4D", "5H", "3S"]', 'dealer', 0, 'Yüksek Kart (High Card) vs Per (Pair)'), ('["6H", "10S", "QS", "AC", "10C"]', '["QC", "6S", "JH", "3D", "AS"]', 'player', 2, 'Per (Pair) vs Yüksek Kart (High Card)'), ('["9H", "5H", "JS", "4S", "10S"]', '["9D", "6D", "JH", "KH", "4H"]', 'dealer', 0, 'Yüksek Kart (High Card) vs Yüksek Kart (High Card)'), ('["AC", "JC", "KC", "2H", "JD"]', '["7S", "9D", "6D", "6S", "3S"]', 'player', 2, 'Per (Pair) vs Per (Pair)'), ('["QC", "4S", "5D", "9C", "7C"]', '["7D", "AH", "7H", "6S", "9H"]', 'dealer', 0, 'Yüksek Kart (High Card) vs Per (Pair)'), ('["2H", "7S", "4D", "QC", "7D"]', '["KC", "5H", "AC", "9S", "2S"]', 'player', 2, 'Per (Pair) vs Yüksek Kart (High Card)'), ('["4D", "QS", "5H", "4H", "4S"]', '["KH", "7D", "8H", "AS", "6C"]', 'player', 3, 'Üçlü (Three of a Kind) vs Yüksek Kart (High Card)'), ('["7H", "2C", "9C", "QS", "6C"]', '["6D", "5D", "10D", "JC", "10C"]', 'dealer', 0, 'Yüksek Kart (High Card) vs Per (Pair)'), ('["10H", "10S", "5S", "9D", "5H"]', '["QC", "4S", "6D", "AC", "2S"]', 'player', 3, 'İki Döper (Two Pair) vs Yüksek Kart (High Card)'), ('["8S", "AC", "9D", "6D", "QC"]', '["QH", "8C", "4D", "JD", "10C"]', 'player', 2, 'Yüksek Kart (High Card) vs Yüksek Kart (High Card)'), ('["5C", "10D", "6S", "10S", "8D"]', '["10H", "3S", "7C", "8C", "9D"]', 'player', 2, 'Per (Pair) vs Yüksek Kart (High Card)'), ('["10D", "5D", "KD", "9D", "4D"]', '["7H", "4S", "8D", "3C", "4C"]', 'player', 5, 'Renk (Flush) vs Per (Pair)'), ('["KH", "3S", "AD", "5C", "9H"]', '["6D", "JH", "KD", "9S", "JD"]', 'dealer', 0, 'Yüksek Kart (High Card) vs Per (Pair)'), ('["4S", "3S", "KS", "JC", "10S"]', '["3H", "3D", "2S", "8C", "10D"]', 'dealer', 0, 'Yüksek Kart (High Card) vs Per (Pair)'), ('["10D", "7H", "3H", "JH", "6S"]', '["2D", "JS", "9D", "QC", "6H"]', 'dealer', 0, 'Yüksek Kart (High Card) vs Yüksek Kart (High Card)'), ('["QH", "7C", "10C", "7D", "4H"]', '["2C", "6D", "JC", "2D", "KH"]', 'dealer', 0, 'Per (Pair) vs Per (Pair)'), ('["JH", "5C", "7H", "2H", "AC"]', '["KH", "6C", "8C", "KS", "6H"]', 'dealer', 0, 'Yüksek Kart (High Card) vs İki Döper (Two Pair)'), ('["8C", "6C", "AD", "4H", "3C"]', '["5S", "9C", "JD", "KS", "QS"]', 'player', 2, 'Yüksek Kart (High Card) vs Yüksek Kart (High Card)'), ('["3C", "9D", "KH", "8H", "10H"]', '["5S", "6H", "4S", "3S", "3D"]', 'dealer', 0, 'Yüksek Kart (High Card) vs Per (Pair)'), ('["JS", "6D", "2C", "QH", "KS"]', '["8D", "2D", "QC", "9S", "AS"]', 'dealer', 0, 'Yüksek Kart (High Card) vs Yüksek Kart (High Card)'), ('["7S", "9S", "8H", "6S", "4D"]', '["3S", "KH", "6H", "JC", "7H"]', 'dealer', 0, 'Yüksek Kart (High Card) vs Yüksek Kart (High Card)'), ('["KD", "9H", "KH", "4S", "AC"]', '["10S", "4C", "8H", "10H", "QH"]', 'player', 2, 'Per (Pair) vs Per (Pair)'), ('["3S", "AH", "7S", "AD", "2S"]', '["QD", "JH", "2D", "QC", "KC"]', 'player', 2, 'Per (Pair) vs Per (Pair)'), ('["2C", "7S", "2D", "9C", "5S"]', '["5C", "2H", "JD", "7H", "2S"]', 'dealer', 0, 'Per (Pair) vs Per (Pair)'), ('["6D", "3S", "AH", "QS", "JD"]', '["KS", "9C", "9H", "QD", "4D"]', 'dealer', 0, 'Yüksek Kart (High Card) vs Per (Pair)'), ('["AH", "5D", "7H", "9D", "7C"]', '["9C", "KC", "3D", "5H", "AS"]', 'player', 2, 'Per (Pair) vs Yüksek Kart (High Card)'), ('["6H", "JD", "KC", "10C", "2S"]', '["7S", "2C", "AS", "KH", "4H"]', 'dealer', 0, 'Yüksek Kart (High Card) vs Yüksek Kart (High Card)'), ('["7C", "7D", "6H", "3D", "JS"]', '["3S", "6S", "9D", "10D", "8D"]', 'player', 2, 'Per (Pair) vs Yüksek Kart (High Card)'), ('["QH", "3H", "4H", "8S", "2H"]', '["7S", "KD", "QC", "7D", "7C"]', 'dealer', 0, 'Yüksek Kart (High Card) vs Üçlü (Three of a Kind)'), ('["8C", "7D", "2H", "10D", "3H"]', '["KD", "6S", "4C", "3D", "AH"]', 'dealer', 0, 'Yüksek Kart (High Card) vs Yüksek Kart (High Card)'), ('["8C", "2S", "QH", "QC", "9C"]', '["6S", "8S", "JC", "AH", "7H"]', 'player', 2, 'Per (Pair) vs Yüksek Kart (High Card)'), ('["8C", "9C", "KS", "7H", "6C"]', '["AH", "10S", "7C", "4D", "KH"]', 'dealer', 0, 'Yüksek Kart (High Card) vs Yüksek Kart (High Card)'), ('["10H", "JS", "4S", "3D", "9H"]', '["5C", "QH", "3S", "10C", "6D"]', 'dealer', 0, 'Yüksek Kart (High Card) vs Yüksek Kart (High Card)'), ('["4C", "4H", "AS", "7D", "9S"]', '["10S", "2D", "3H", "6H", "8C"]', 'player', 2, 'Per (Pair) vs Yüksek Kart (High Card)'), ('["KS", "7S", "4S", "6S", "6D"]', '["QD", "QS", "8S", "JC", "9C"]', 'player', 2, 'Per (Pair) vs Per (Pair)'), ('["KC", "7H", "10C", "KH", "3S"]', '["2C", "QD", "3H", "6D", "3C"]', 'player', 2, 'Per (Pair) vs Per (Pair)'), ('["3D", "QC", "QS", "6D", "2H"]', '["JC", "7S", "AC", "2S", "KC"]', 'player', 2, 'Per (Pair) vs Yüksek Kart (High Card)'), ('["7C", "8C", "KH", "4D", "6D"]', '["2D", "KS", "8D", "7D", "4S"]', 'player', 2, 'Yüksek Kart (High Card) vs Yüksek Kart (High Card)'), ('["8H", "9S", "9H", "QD", "KS"]', '["8S", "7D", "7C", "4S", "5C"]', 'player', 2, 'Per (Pair) vs Per (Pair)'), ('["KC", "9D", "3C", "6D", "QC"]', '["7D", "4C", "JC", "JD", "2S"]', 'dealer', 0, 'Yüksek Kart (High Card) vs Per (Pair)'), ('["6D", "JS", "10H", "7H", "3D"]', '["QS", "QD", "QC", "7S", "AH"]', 'dealer', 0, 'Yüksek Kart (High Card) vs Üçlü (Three of a Kind)'), ('["2C", "4S", "7S", "QH", "8C"]', '["5S", "8D", "7H", "AD", "6H"]', 'dealer', 0, 'Yüksek Kart (High Card) vs Yüksek Kart (High Card)'), ('["9H", "10C", "8C", "10S", "2C"]', '["2S", "2H", "QS", "QC", "7S"]', 'dealer', 0, 'Per (Pair) vs İki Döper (Two Pair)'), ('["JD", "10S", "KS", "AS", "2S"]', '["6S", "10D", "2D", "7C", "10C"]', 'dealer', 0, 'Yüksek Kart (High Card) vs Per (Pair)'), ('["4H", "4D", "AH", "10C", "5H"]', '["8D", "AC", "5C", "7C", "KC"]', 'player', 2, 'Per (Pair) vs Yüksek Kart (High Card)'), ('["7H", "4D", "10D", "AH", "KC"]', '["9C", "JD", "9D", "10S", "KH"]', 'dealer', 0, 'Yüksek Kart (High Card) vs Per (Pair)'), ('["KD", "3H", "9S", "10S", "AD"]', '["KH", "9C", "3D", "7H", "6S"]', 'player', 2, 'Yüksek Kart (High Card) vs Yüksek Kart (High Card)'), ('["5C", "AH", "JS", "9H", "JC"]', '["8S", "10H", "2H", "6D", "6H"]', 'player', 2, 'Per (Pair) vs Per (Pair)'), ('["QC", "7H", "9S", "4D", "9H"]', '["6C", "KS", "7C", "5C", "3D"]', 'player', 2, 'Per (Pair) vs Yüksek Kart (High Card)'), ('["2C", "9D", "KH", "9C", "JS"]', '["6H", "7H", "3C", "KC", "QD"]', 'player', 2, 'Per (Pair) vs Yüksek Kart (High Card)'), ('["AC", "2C", "7S", "8C", "4D"]', '["4C", "9S", "KH", "10H", "6D"]', 'player', 2, 'Yüksek Kart (High Card) vs Yüksek Kart (High Card)'), ('["7H", "AD", "JD", "10H", "QD"]', '["10D", "2C", "JC", "5S", "JH"]', 'dealer', 0, 'Yüksek Kart (High Card) vs Per (Pair)'), ('["QS", "4S", "8H", "10C", "6H"]', '["KD", "KS", "JD", "9H", "7D"]', 'dealer', 0, 'Yüksek Kart (High Card) vs Per (Pair)'), ('["3S", "5C", "5D", "3H", "9H"]', '["4H", "9S", "AD", "3C", "9C"]', 'player', 3, 'İki Döper (Two Pair) vs Per (Pair)'), ('["3H", "2H", "KH", "7C", "5D"]', '["2S", "8S", "7D", "AD", "KC"]', 'dealer', 0, 'Yüksek Kart (High Card) vs Yüksek Kart (High Card)'), ('["9S", "8C", "3H", "6D", "KD"]', '["3S", "4C", "QC", "KC", "JC"]', 'dealer', 0, 'Yüksek Kart (High Card) vs Yüksek Kart (High Card)'), ('["KD", "JD", "5H", "2C", "8D"]', '["KH", "QS", "7H", "4D", "5D"]', 'dealer', 0, 'Yüksek Kart (High Card) vs Yüksek Kart (High Card)'), ('["6D", "4S", "JS", "6H", "JH"]', '["AC", "9C", "10H", "AD", "9D"]', 'dealer', 0, 'İki Döper (Two Pair) vs İki Döper (Two Pair)'), ('["2H", "10C", "4S", "KC", "10H"]', '["7D", "3D", "7H", "JD", "6C"]', 'player', 2, 'Per (Pair) vs Per (Pair)'), ('["2C", "10C", "10D", "5S", "10S"]', '["6S", "8D", "2D", "JC", "9C"]', 'player', 3, 'Üçlü (Three of a Kind) vs Yüksek Kart (High Card)'), ('["10D", "10H", "AD", "3D", "2H"]', '["KC", "6D", "8D", "10S", "3C"]', 'player', 2, 'Per (Pair) vs Yüksek Kart (High Card)'), ('["9H", "KS", "5S", "JH", "5C"]', '["2C", "3D", "7C", "QD", "JD"]', 'player', 2, 'Per (Pair) vs Yüksek Kart (High Card)'), ('["KD", "3H", "JH", "AH", "9H"]', '["KC", "2H", "8D", "4C", "4D"]', 'dealer', 0, 'Yüksek Kart (High Card) vs Per (Pair)'), ('["AH", "5D", "7D", "7S", "KC"]', '["9S", "JD", "7H", "10D", "KD"]', 'player', 2, 'Per (Pair) vs Yüksek Kart (High Card)'), ('["9S", "3D", "5D", "AS", "2C"]', '["JD", "4H", "AC", "7C", "4S"]', 'dealer', 0, 'Yüksek Kart (High Card) vs Per (Pair)'), ('["2H", "7C", "8C", "6D", "3H"]', '["3D", "9C", "6H", "6S", "5H"]', 'dealer', 0, 'Yüksek Kart (High Card) vs Per (Pair)'), ('["6C", "AH", "6D", "3H", "6S"]', '["9H", "AS", "JC", "3D", "9C"]', 'player', 3, 'Üçlü (Three of a Kind) vs Per (Pair)'), ('["5H", "10C", "3C", "KS", "3H"]', '["4D", "6H", "8S", "QD", "9H"]', 'player', 2, 'Per (Pair) vs Yüksek Kart (High Card)'), ('["8C", "3S", "8D", "9H", "7H"]', '["AS", "JS", "10D", "9D", "7S"]', 'player', 2, 'Per (Pair) vs Yüksek Kart (High Card)'), ('["QH", "9D", "8H", "5H", "AH"]', '["6S", "7C", "10C", "5D", "7H"]', 'dealer', 0, 'Yüksek Kart (High Card) vs Per (Pair)'), ('["3S", "10S", "4C", "7H", "QH"]', '["JS", "5S", "AH", "QC", "8D"]', 'dealer', 0, 'Yüksek Kart (High Card) vs Yüksek Kart (High Card)'), ('["8D", "KD", "4D", "QH", "3D"]', '["8H", "5C", "10D", "6S", "2S"]', 'player', 2, 'Yüksek Kart (High Card) vs Yüksek Kart (High Card)'), ('["KH", "5D", "QS", "3C", "AH"]', '["10C", "4S", "4D", "JD", "5C"]', 'dealer', 0, 'Yüksek Kart (High Card) vs Per (Pair)'), ('["8D", "9H", "AS", "5S", "JC"]', '["9D", "8H", "6H", "3H", "4D"]', 'player', 2, 'Yüksek Kart (High Card) vs Yüksek Kart (High Card)'), ('["QD", "5H", "10S", "QS", "3D"]', '["10C", "AD", "8D", "KH", "AC"]', 'dealer', 0, 'Per (Pair) vs Per (Pair)'), ('["QC", "KC", "7C", "QS", "AH"]', '["8S", "10C", "2H", "AC", "3D"]', 'player', 2, 'Per (Pair) vs Yüksek Kart (High Card)'), ('["QH", "4S", "KC", "7H", "6S"]', '["3H", "4D", "JH", "JD", "JC"]', 'dealer', 0, 'Yüksek Kart (High Card) vs Üçlü (Three of a Kind)'), ('["5S", "9D", "8S", "AD", "JH"]', '["8D", "KC", "AC", "3H", "9H"]', 'dealer', 0, 'Yüksek Kart (High Card) vs Yüksek Kart (High Card)'), ('["3H", "QC", "10H", "JH", "QD"]', '["6C", "10C", "5C", "KH", "9H"]', 'player', 2, 'Per (Pair) vs Yüksek Kart (High Card)'), ('["9D", "KS", "5D", "8C", "3H"]', '["6C", "7S", "4C", "7D", "9C"]', 'dealer', 0, 'Yüksek Kart (High Card) vs Per (Pair)'), ('["QH", "JS", "2S", "8H", "3C"]', '["JC", "8C", "2C", "9H", "6H"]', 'player', 2, 'Yüksek Kart (High Card) vs Yüksek Kart (High Card)'), ('["QC", "7C", "3S", "8H", "AS"]', '["4H", "KC", "6D", "7S", "QH"]', 'player', 2, 'Yüksek Kart (High Card) vs Yüksek Kart (High Card)'), ('["6D", "4H", "QS", "7S", "5S"]', '["JD", "AH", "7C", "QH", "5D"]', 'dealer', 0, 'Yüksek Kart (High Card) vs Yüksek Kart (High Card)'), ('["4S", "8D", "7H", "QC", "6S"]', '["AC", "AD", "10C", "9C", "4D"]', 'dealer', 0, 'Yüksek Kart (High Card) vs Per (Pair)'), ('["8D", "4C", "7S", "6D", "10S"]', '["KS", "2H", "7H", "5C", "8H"]', 'dealer', 0, 'Yüksek Kart (High Card) vs Yüksek Kart (High Card)'), ('["8S", "9S", "QS", "2H", "9C"]', '["10D", "QD", "6S", "JC", "6H"]', 'dealer', 0, 'Per (Pair) vs Per (Pair)'), ('["10H", "9D", "AC", "QS", "3H"]', '["QD", "AS", "6H", "AD", "JS"]', 'dealer', 0, 'Yüksek Kart (High Card) vs Per (Pair)'), ('["KS", "8H", "5D", "4D", "7S"]', '["10C", "8C", "5H", "9S", "AC"]', 'dealer', 0, 'Yüksek Kart (High Card) vs Yüksek Kart (High Card)'), ('["6C", "9C", "QH", "9S", "AS"]', '["5C", "10D", "JS", "KS", "4S"]', 'player', 2, 'Per (Pair) vs Yüksek Kart (High Card)'), ('["5S", "5C", "AH", "3C", "KS"]', '["10C", "KC", "QC", "3D", "AD"]', 'player', 2, 'Per (Pair) vs Yüksek Kart (High Card)'), ('["5C", "10H", "9C", "4H", "5S"]', '["KC", "9S", "3S", "AC", "QD"]', 'player', 2, 'Per (Pair) vs Yüksek Kart (High Card)'), ('["KD", "8C", "3D", "AC", "JD"]', '["JS", "3C", "3S", "2D", "9S"]', 'dealer', 0, 'Yüksek Kart (High Card) vs Per (Pair)'), ('["10C", "5H", "KC", "6H", "8H"]', '["10D", "KD", "AC", "6C", "KH"]', 'dealer', 0, 'Yüksek Kart (High Card) vs Per (Pair)'), ('["7C", "7D", "KC", "10C", "5C"]', '["2H", "10H", "AC", "7S", "QS"]', 'player', 2, 'Per (Pair) vs Yüksek Kart (High Card)'), ('["3D", "10H", "10S", "7C", "5D"]', '["7D", "8S", "JD", "KH", "10D"]', 'player', 2, 'Per (Pair) vs Yüksek Kart (High Card)'), ('["3C", "10C", "2C", "8D", "4C"]', '["QH", "JH", "5S", "8H", "5C"]', 'dealer', 0, 'Yüksek Kart (High Card) vs Per (Pair)'), ('["7S", "2C", "5C", "QC", "KC"]', '["9H", "AC", "8H", "10C", "6D"]', 'dealer', 0, 'Yüksek Kart (High Card) vs Yüksek Kart (High Card)'), ('["JC", "9D", "10D", "KS", "3C"]', '["3H", "2H", "5H", "6H", "4D"]', 'dealer', 0, 'Yüksek Kart (High Card) vs Kent (Straight)'), ('["QH", "5H", "KD", "10H", "JD"]', '["7C", "AC", "2S", "9S", "9C"]', 'dealer', 0, 'Yüksek Kart (High Card) vs Per (Pair)'), ('["5H", "9C", "5C", "6H", "4H"]', '["4D", "JH", "10H", "AH", "7H"]', 'player', 2, 'Per (Pair) vs Yüksek Kart (High Card)'), ('["10D", "3S", "6H", "AH", "KC"]', '["KS", "9S", "QD", "2D", "9H"]', 'dealer', 0, 'Yüksek Kart (High Card) vs Per (Pair)'), ('["JS", "6D", "3H", "3D", "JC"]', '["5S", "4D", "4S", "AC", "3S"]', 'player', 3, 'İki Döper (Two Pair) vs Per (Pair)'), ('["3H", "QS", "5S", "3S", "9S"]', '["4S", "6C", "AC", "JD", "7C"]', 'player', 2, 'Per (Pair) vs Yüksek Kart (High Card)'), ('["5C", "5S", "10H", "8S", "6D"]', '["JC", "8C", "9S", "4H", "7C"]', 'player', 2, 'Per (Pair) vs Yüksek Kart (High Card)'), ('["6H", "JC", "7S", "JD", "2C"]', '["2S", "QH", "8H", "JH", "10D"]', 'player', 2, 'Per (Pair) vs Yüksek Kart (High Card)'), ('["2D", "JH", "KH", "4S", "KS"]', '["JC", "4H", "KD", "JS", "6S"]', 'player', 2, 'Per (Pair) vs Per (Pair)'), ('["4D", "2S", "8D", "5D", "AC"]', '["5S", "10C", "2C", "8C", "4S"]', 'player', 2, 'Yüksek Kart (High Card) vs Yüksek Kart (High Card)'), ('["9D", "4C", "QD", "5H", "4S"]', '["10D", "7C", "3H", "KS", "2C"]', 'player', 2, 'Per (Pair) vs Yüksek Kart (High Card)'), ('["2H", "JC", "10D", "6D", "7D"]', '["KH", "8D", "7H", "6H", "6S"]', 'dealer', 0, 'Yüksek Kart (High Card) vs Per (Pair)'), ('["2D", "4S", "AS", "8S", "2H"]', '["4H", "7H", "6C", "AH", "JC"]', 'player', 2, 'Per (Pair) vs Yüksek Kart (High Card)'), ('["9C", "KC", "QH", "5H", "8H"]', '["8C", "6C", "JS", "KH", "3S"]', 'player', 2, 'Yüksek Kart (High Card) vs Yüksek Kart (High Card)'), ('["4D", "AS", "AH", "6D", "QH"]', '["10C", "QD", "3S", "9H", "9D"]', 'player', 2, 'Per (Pair) vs Per (Pair)'), ('["AC", "4S", "10H", "7D", "6S"]', '["4H", "2S", "JS", "6C", "4C"]', 'dealer', 0, 'Yüksek Kart (High Card) vs Per (Pair)'), ('["10S", "7S", "5C", "QC", "10D"]', '["QS", "JC", "3D", "7D", "8H"]', 'player', 2, 'Per (Pair) vs Yüksek Kart (High Card)'), ('["KC", "4S", "2D", "3C", "3S"]', '["QS", "5D", "QH", "7S", "10D"]', 'player', 2, 'Per (Pair) vs Per (Pair)'), ('["7S", "8C", "3C", "AC", "3S"]', '["KD", "5H", "8D", "QH", "AD"]', 'player', 2, 'Per (Pair) vs Yüksek Kart (High Card)'), ('["3D", "6D", "6C", "5C", "7H"]', '["KH", "6S", "10H", "QS", "8H"]', 'player', 2, 'Per (Pair) vs Yüksek Kart (High Card)'), ('["8C", "2H", "5C", "QS", "AC"]', '["QH", "10D", "3D", "9D", "5H"]', 'player', 2, 'Yüksek Kart (High Card) vs Yüksek Kart (High Card)'), ('["JD", "8H", "2C", "8D", "10S"]', '["10C", "3H", "3D", "3S", "4D"]', 'dealer', 0, 'Per (Pair) vs Üçlü (Three of a Kind)'), ('["JS", "10S", "KS", "8H", "AS"]', '["3S", "QD", "KC", "AC", "5H"]', 'dealer', 0, 'Yüksek Kart (High Card) vs Yüksek Kart (High Card)'), ('["JH", "2C", "4D", "AS", "AC"]', '["5H", "6D", "6S", "10D", "3C"]', 'player', 2, 'Per (Pair) vs Per (Pair)'), ('["AS", "10C", "8S", "4H", "2S"]', '["9S", "AC", "10S", "3S", "6S"]', 'dealer', 0, 'Yüksek Kart (High Card) vs Yüksek Kart (High Card)'), ('["QD", "KD", "2S", "JS", "6D"]', '["10D", "9D", "9C", "QH", "JH"]', 'dealer', 0, 'Yüksek Kart (High Card) vs Per (Pair)'), ('["3H", "QC", "3S", "QS", "7H"]', '["10C", "7D", "4D", "AD", "KD"]', 'player', 3, 'İki Döper (Two Pair) vs Yüksek Kart (High Card)'), ('["9C", "7D", "5H", "2S", "QS"]', '["7C", "4C", "JH", "AS", "6C"]', 'dealer', 0, 'Yüksek Kart (High Card) vs Yüksek Kart (High Card)'), ('["6C", "7D", "JD", "3H", "5C"]', '["6D", "QS", "QD", "6S", "4D"]', 'dealer', 0, 'Yüksek Kart (High Card) vs İki Döper (Two Pair)'), ('["5S", "9D", "KH", "8C", "10D"]', '["JH", "AD", "6C", "JD", "QS"]', 'dealer', 0, 'Yüksek Kart (High Card) vs Per (Pair)'), ('["AH", "9D", "AC", "9H", "10D"]', '["QD", "2D", "2S", "8D", "QS"]', 'player', 3, 'İki Döper (Two Pair) vs İki Döper (Two Pair)'), ('["3C", "QS", "AS", "3D", "5C"]', '["10S", "10C", "KS", "9D", "6H"]', 'player', 2, 'Per (Pair) vs Per (Pair)'), ('["5H", "KH", "10H", "10D", "3C"]', '["4D", "AS", "4C", "9C", "QC"]', 'dealer', 0, 'Per (Pair) vs Per (Pair)'), ('["10S", "7D", "5S", "9S", "AD"]', '["6S", "4C", "QS", "4H", "2H"]', 'dealer', 0, 'Yüksek Kart (High Card) vs Per (Pair)'), ('["6H", "6D", "9D", "AC", "5H"]', '["4D", "KC", "9H", "2S", "4H"]', 'player', 2, 'Per (Pair) vs Per (Pair)'), ('["KH", "3D", "7C", "3C", "9H"]', '["KS", "2S", "3S", "8H", "QC"]', 'player', 2, 'Per (Pair) vs Yüksek Kart (High Card)'), ('["KH", "QS", "QD", "AS", "4C"]', '["8D", "AD", "3H", "10S", "5H"]', 'player', 2, 'Per (Pair) vs Yüksek Kart (High Card)'), ('["3D", "6D", "10S", "2C", "AD"]', '["QC", "AS", "9C", "KH", "QD"]', 'dealer', 0, 'Yüksek Kart (High Card) vs Per (Pair)'), ('["2S", "10C", "6C", "QD", "6H"]', '["4H", "4D", "2H", "5S", "AD"]', 'dealer', 0, 'Per (Pair) vs Per (Pair)'), ('["AH", "5H", "9C", "QH", "AD"]', '["KS", "KD", "7H", "2H", "KH"]', 'dealer', 0, 'Per (Pair) vs Üçlü (Three of a Kind)'), ('["JS", "4C", "4H", "4D", "8D"]', '["3H", "3C", "2S", "6D", "9H"]', 'player', 3, 'Üçlü (Three of a Kind) vs Per (Pair)'), ('["JC", "QS", "6H", "AH", "2H"]', '["AS", "5D", "KD", "10D", "8H"]', 'dealer', 0, 'Yüksek Kart (High Card) vs Yüksek Kart (High Card)'), ('["10C", "6H", "AD", "6S", "7H"]', '["2C", "3S", "7D", "2D", "QS"]', 'player', 2, 'Per (Pair) vs Per (Pair)'), ('["10C", "7H", "2D", "5H", "9C"]', '["JC", "8C", "KD", "QC", "AC"]', 'dealer', 0, 'Yüksek Kart (High Card) vs Yüksek Kart (High Card)'), ('["QS", "2S", "10S", "8D", "4C"]', '["6C", "7S", "9H", "2C", "5H"]', 'player', 2, 'Yüksek Kart (High Card) vs Yüksek Kart (High Card)'), ('["10H", "4D", "KH", "AD", "AS"]', '["JD", "9S", "10D", "6S", "AC"]', 'player', 2, 'Per (Pair) vs Yüksek Kart (High Card)'), ('["7H", "7C", "KD", "10H", "QC"]', '["3H", "8S", "9S", "3D", "3S"]', 'dealer', 0, 'Per (Pair) vs Üçlü (Three of a Kind)'), ('["4C", "QS", "5S", "10H", "8S"]', '["4D", "10C", "JC", "9D", "8C"]', 'player', 2, 'Yüksek Kart (High Card) vs Yüksek Kart (High Card)'), ('["10C", "2S", "6D", "2D", "10H"]', '["QH", "AC", "4D", "7D", "9D"]', 'player', 3, 'İki Döper (Two Pair) vs Yüksek Kart (High Card)'), ('["QH", "5C", "5D", "AD", "3H"]', '["KS", "4D", "4C", "3D", "7D"]', 'player', 2, 'Per (Pair) vs Per (Pair)'), ('["JD", "JC", "QS", "9D", "3D"]', '["AS", "JS", "7D", "3S", "AH"]', 'dealer', 0, 'Per (Pair) vs Per (Pair)'), ('["QC", "QS", "9D", "9C", "2S"]', '["KC", "6H", "9H", "KS", "3H"]', 'player', 3, 'İki Döper (Two Pair) vs Per (Pair)'), ('["6H", "JD", "5H", "3S", "9D"]', '["4C", "AS", "10S", "KS", "2S"]', 'dealer', 0, 'Yüksek Kart (High Card) vs Yüksek Kart (High Card)'), ('["5C", "4D", "QS", "2D", "2S"]', '["5H", "QC", "JD", "6D", "9C"]', 'player', 2, 'Per (Pair) vs Yüksek Kart (High Card)'), ('["KH", "AD", "10D", "5S", "AC"]', '["7S", "5H", "9S", "7C", "6S"]', 'player', 2, 'Per (Pair) vs Per (Pair)'), ('["QS", "10H", "6H", "4H", "2C"]', '["AS", "JD", "JH", "2D", "9D"]', 'dealer', 0, 'Yüksek Kart (High Card) vs Per (Pair)'), ('["KH", "10H", "4H", "5D", "6S"]', '["9H", "9C", "10D", "4S", "AH"]', 'dealer', 0, 'Yüksek Kart (High Card) vs Per (Pair)'), ('["KH", "JH", "10C", "8H", "4H"]', '["9D", "2D", "QD", "2H", "5C"]', 'dealer', 0, 'Yüksek Kart (High Card) vs Per (Pair)'), ('["7H", "QS", "2D", "9D", "9H"]', '["6C", "QC", "KH", "7D", "2H"]', 'player', 2, 'Per (Pair) vs Yüksek Kart (High Card)'), ('["7C", "8C", "10H", "4C", "6C"]', '["JH", "6H", "9S", "QH", "JD"]', 'dealer', 0, 'Yüksek Kart (High Card) vs Per (Pair)'), ('["9S", "4H", "QC", "QS", "6C"]', '["4S", "10C", "5H", "7D", "6S"]', 'player', 2, 'Per (Pair) vs Yüksek Kart (High Card)'), ('["QH", "9S", "2D", "4S", "QS"]', '["10H", "7C", "JD", "3D", "3S"]', 'player', 2, 'Per (Pair) vs Per (Pair)'), ('["8D", "3D", "5H", "KD", "3S"]', '["7D", "5C", "2D", "JH", "KS"]', 'player', 2, 'Per (Pair) vs Yüksek Kart (High Card)'), ('["JH", "2D", "JD", "6S", "7H"]', '["2C", "5S", "2S", "3C", "7D"]', 'player', 2, 'Per (Pair) vs Per (Pair)'), ('["JC", "9C", "KD", "6H", "8H"]', '["AC", "QS", "5D", "7S", "KH"]', 'dealer', 0, 'Yüksek Kart (High Card) vs Yüksek Kart (High Card)'), ('["10D", "10C", "2S", "5D", "JD"]', '["6D", "3S", "7D", "QD", "9C"]', 'player', 2, 'Per (Pair) vs Yüksek Kart (High Card)'), ('["AS", "2S", "QC", "3D", "JS"]', '["KD", "8C", "2H", "JC", "3S"]', 'player', 2, 'Yüksek Kart (High Card) vs Yüksek Kart (High Card)'), ('["4D", "JD", "6D", "4H", "AS"]', '["10S", "7H", "KC", "KS", "AD"]', 'dealer', 0, 'Per (Pair) vs Per (Pair)'), ('["6C", "9S", "3D", "KS", "3H"]', '["7D", "10D", "2C", "9D", "7S"]', 'player', 2, 'Per (Pair) vs Per (Pair)'), ('["4H", "QC", "4C", "3C", "4D"]', '["KS", "QH", "2D", "3H", "JC"]', 'player', 3, 'Üçlü (Three of a Kind) vs Yüksek Kart (High Card)'), ('["QD", "7C", "7D", "AH", "5H"]', '["JH", "10S", "2C", "6D", "KS"]', 'player', 2, 'Per (Pair) vs Yüksek Kart (High Card)'), ('["5D", "6H", "JS", "10D", "5S"]', '["QC", "5C", "10S", "10C", "4C"]', 'dealer', 0, 'Per (Pair) vs Per (Pair)'), ('["2D", "4S", "QH", "4H", "7D"]', '["2C", "10D", "KD", "5S", "3S"]', 'player', 2, 'Per (Pair) vs Yüksek Kart (High Card)'), ('["QD", "4H", "5D", "KS", "2D"]', '["3H", "8H", "AD", "6H", "JH"]', 'dealer', 0, 'Yüksek Kart (High Card) vs Yüksek Kart (High Card)'), ('["3C", "10H", "8D", "2D", "9S"]', '["6C", "5H", "10C", "8H", "2S"]', 'player', 2, 'Yüksek Kart (High Card) vs Yüksek Kart (High Card)'), ('["QC", "6H", "3C", "7S", "8C"]', '["2H", "6C", "4C", "3H", "8D"]', 'player', 2, 'Yüksek Kart (High Card) vs Yüksek Kart (High Card)'), ('["6D", "4D", "QS", "AC", "5D"]', '["9C", "3H", "9S", "KD", "7C"]', 'dealer', 0, 'Yüksek Kart (High Card) vs Per (Pair)'), ('["6D", "5S", "7C", "10H", "10D"]', '["2C", "5H", "7S", "7D", "5C"]', 'dealer', 0, 'Per (Pair) vs İki Döper (Two Pair)'), ('["AS", "QC", "2H", "3C", "7H"]', '["5H", "2D", "KH", "9S", "10S"]', 'player', 2, 'Yüksek Kart (High Card) vs Yüksek Kart (High Card)'), ('["7D", "5C", "3S", "5D", "JS"]', '["KD", "4H", "7H", "8C", "KS"]', 'dealer', 0, 'Per (Pair) vs Per (Pair)'), ('["8H", "10D", "QS", "3C", "JD"]', '["6H", "6C", "7C", "6S", "AD"]', 'dealer', 0, 'Yüksek Kart (High Card) vs Üçlü (Three of a Kind)'), ('["10D", "10C", "AD", "2D", "2H"]', '["2S", "8S", "5C", "7C", "KD"]', 'player', 3, 'İki Döper (Two Pair) vs Yüksek Kart (High Card)'), ('["8H", "AC", "4S", "3C", "3S"]', '["AH", "5C", "8S", "10H", "JS"]', 'player', 2, 'Per (Pair) vs Yüksek Kart (High Card)'), ('["10D", "6H", "6S", "9C", "3S"]', '["2C", "4S", "QD", "4H", "9H"]', 'dealer', 0, 'Per (Pair) vs Per (Pair)'), ('["KC", "4D", "AD", "KH", "4C"]', '["10C", "2D", "AH", "9C", "JS"]', 'player', 3, 'İki Döper (Two Pair) vs Yüksek Kart (High Card)'), ('["4S", "9H", "6C", "5H", "5D"]', '["3D", "7D", "7S", "JD", "7C"]', 'dealer', 0, 'Per (Pair) vs Üçlü (Three of a Kind)'), ('["5S", "AD", "6S", "10C", "3C"]', '["KH", "QH", "6D", "4D", "8S"]', 'player', 2, 'Yüksek Kart (High Card) vs Yüksek Kart (High Card)'), ('["3D", "6D", "QC", "8C", "5S"]', '["5H", "JC", "4S", "3C", "3H"]', 'dealer', 0, 'Yüksek Kart (High Card) vs Per (Pair)'), ('["2S", "QH", "KS", "6D", "AD"]', '["3H", "4H", "2C", "KD", "JC"]', 'player', 2, 'Yüksek Kart (High Card) vs Yüksek Kart (High Card)'), ('["KH", "8H", "QD", "9H", "6C"]', '["KS", "2S", "QS", "5S", "QH"]', 'dealer', 0, 'Yüksek Kart (High Card) vs Per (Pair)'), ('["JD", "2C", "4D", "9D", "4S"]', '["KH", "2H", "10D", "9S", "9C"]', 'dealer', 0, 'Per (Pair) vs Per (Pair)'), ('["3D", "10C", "9S", "AD", "8C"]', '["QH", "10H", "3S", "7C", "KD"]', 'player', 2, 'Yüksek Kart (High Card) vs Yüksek Kart (High Card)'), ('["QD", "AH", "3H", "JH", "2C"]', '["QS", "AD", "8H", "6D", "QH"]', 'dealer', 0, 'Yüksek Kart (High Card) vs Per (Pair)'), ('["AC", "3C", "8H", "QC", "KC"]', '["2D", "5S", "4C", "7H", "6D"]', 'player', 2, 'Yüksek Kart (High Card) vs Yüksek Kart (High Card)'), ('["AC", "2C", "5C", "JS", "8C"]', '["6C", "KS", "10H", "QH", "3D"]', 'player', 2, 'Yüksek Kart (High Card) vs Yüksek Kart (High Card)'), ('["5S", "KC", "QD", "10C", "3S"]', '["6H", "8C", "5D", "2C", "10D"]', 'player', 2, 'Yüksek Kart (High Card) vs Yüksek Kart (High Card)'), ('["KC", "4D", "10D", "3D", "JS"]', '["9D", "2D", "KS", "5C", "AD"]', 'dealer', 0, 'Yüksek Kart (High Card) vs Yüksek Kart (High Card)'), ('["AC", "KC", "8H", "3S", "3H"]', '["AS", "4H", "4C", "QC", "2C"]', 'player', 2, 'Per (Pair) vs Per (Pair)'), ('["KD", "6H", "8H", "2H", "5C"]', '["JC", "KS", "3C", "KC", "QC"]', 'dealer', 0, 'Yüksek Kart (High Card) vs Per (Pair)'), ('["7H", "5S", "AC", "3S", "JD"]', '["2C", "9H", "4C", "5C", "8C"]', 'player', 2, 'Yüksek Kart (High Card) vs Yüksek Kart (High Card)'), ('["8D", "QS", "8S", "AH", "9D"]', '["7C", "10D", "10C", "3S", "6C"]', 'player', 2, 'Per (Pair) vs Per (Pair)'), ('["JC", "7S", "9C", "KS", "5C"]', '["AC", "9S", "AD", "JH", "JD"]', 'dealer', 0, 'Yüksek Kart (High Card) vs İki Döper (Two Pair)'), ('["7D", "7H", "KS", "KC", "4S"]', '["2C", "AH", "QH", "KH", "3S"]', 'player', 3, 'İki Döper (Two Pair) vs Yüksek Kart (High Card)'), ('["KS", "6D", "2H", "JD", "QH"]', '["AD", "KC", "JH", "5S", "10S"]', 'dealer', 0, 'Yüksek Kart (High Card) vs Yüksek Kart (High Card)'), ('["5H", "9C", "5D", "9S", "5C"]', '["4S", "8C", "3D", "10D", "2D"]', 'player', 10, 'Full House vs Yüksek Kart (High Card)'), ('["9C", "QS", "6S", "8D", "AD"]', '["AH", "5H", "5D", "JD", "10D"]', 'dealer', 0, 'Yüksek Kart (High Card) vs Per (Pair)'), ('["4C", "QD", "3H", "3S", "8D"]', '["6C", "9C", "KS", "KH", "5H"]', 'dealer', 0, 'Per (Pair) vs Per (Pair)'), ('["10S", "QD", "6D", "5H", "4S"]', '["3H", "2H", "9D", "3C", "5S"]', 'dealer', 0, 'Yüksek Kart (High Card) vs Per (Pair)'), ('["2D", "7D", "6S", "KD", "4H"]', '["5S", "3D", "8S", "5D", "KC"]', 'dealer', 0, 'Yüksek Kart (High Card) vs Per (Pair)'), ('["JS", "2C", "JD", "8S", "7S"]', '["6H", "3S", "10H", "9C", "6S"]', 'player', 2, 'Per (Pair) vs Per (Pair)'), ('["10H", "5D", "9S", "AD", "KH"]', '["5S", "2C", "9D", "10C", "2D"]', 'dealer', 0, 'Yüksek Kart (High Card) vs Per (Pair)'), ('["3H", "8H", "4H", "7S", "AD"]', '["5C", "AC", "2H", "5D", "QD"]', 'dealer', 0, 'Yüksek Kart (High Card) vs Per (Pair)'), ('["5H", "3C", "7C", "2S", "4C"]', '["4D", "10C", "KH", "3H", "9C"]', 'dealer', 0, 'Yüksek Kart (High Card) vs Yüksek Kart (High Card)'), ('["3S", "AS", "4D", "QC", "JH"]', '["5H", "9C", "9H", "9S", "KH"]', 'dealer', 0, 'Yüksek Kart (High Card) vs Üçlü (Three of a Kind)'), ('["10D", "5D", "QH", "4H", "AS"]', '["9S", "6S", "7H", "QD", "10H"]', 'player', 2, 'Yüksek Kart (High Card) vs Yüksek Kart (High Card)'), ('["3C", "4S", "3D", "9C", "3H"]', '["KD", "QD", "7D", "JD", "5S"]', 'player', 3, 'Üçlü (Three of a Kind) vs Yüksek Kart (High Card)'), ('["8D", "4S", "KC", "8C", "3S"]', '["AS", "8S", "5S", "QD", "AD"]', 'dealer', 0, 'Per (Pair) vs Per (Pair)'), ('["10H", "4D", "JC", "5C", "5D"]', '["QH", "4S", "AS", "2D", "AD"]', 'dealer', 0, 'Per (Pair) vs Per (Pair)'), ('["8S", "10D", "8C", "KS", "7H"]', '["KH", "6S", "4H", "2H", "KC"]', 'dealer', 0, 'Per (Pair) vs Per (Pair)'), ('["QC", "QD", "10H", "10S", "3S"]', '["6S", "8D", "JD", "3C", "6D"]', 'player', 3, 'İki Döper (Two Pair) vs Per (Pair)'), ('["10C", "7S", "6H", "3H", "7H"]', '["AS", "QC", "8H", "9H", "4H"]', 'player', 2, 'Per (Pair) vs Yüksek Kart (High Card)'), ('["QH", "9C", "2H", "8C", "3C"]', '["10H", "KS", "9H", "2S", "9D"]', 'dealer', 0, 'Yüksek Kart (High Card) vs Per (Pair)'), ('["KH", "10D", "2D", "3C", "5S"]', '["4D", "9H", "5H", "7S", "KD"]', 'player', 2, 'Yüksek Kart (High Card) vs Yüksek Kart (High Card)'), ('["KH", "8S", "7H", "6D", "KD"]', '["4H", "AD", "2H", "3H", "JS"]', 'player', 2, 'Per (Pair) vs Yüksek Kart (High Card)'), ('["AD", "4C", "4D", "3D", "9S"]', '["KH", "3S", "JC", "6H", "2D"]', 'player', 2, 'Per (Pair) vs Yüksek Kart (High Card)'), ('["6H", "10S", "9D", "6D", "KC"]', '["AH", "8S", "3C", "JC", "QD"]', 'player', 2, 'Per (Pair) vs Yüksek Kart (High Card)'), ('["9C", "5H", "8H", "3S", "6D"]', '["4C", "10S", "QC", "3C", "7C"]', 'dealer', 0, 'Yüksek Kart (High Card) vs Yüksek Kart (High Card)'), ('["AD", "7D", "4S", "7H", "QS"]', '["AH", "4H", "JS", "6D", "9S"]', 'player', 2, 'Per (Pair) vs Yüksek Kart (High Card)'), ('["4H", "2C", "JD", "3H", "6H"]', '["3D", "7D", "7S", "6C", "4S"]', 'dealer', 0, 'Yüksek Kart (High Card) vs Per (Pair)'), ('["QD", "8S", "9D", "2H", "10H"]', '["8D", "4D", "7S", "QS", "4H"]', 'dealer', 0, 'Yüksek Kart (High Card) vs Per (Pair)'), ('["4C", "2S", "AC", "10H", "8D"]', '["7S", "JS", "7C", "4S", "QH"]', 'dealer', 0, 'Yüksek Kart (High Card) vs Per (Pair)'), ('["QD", "AD", "JD", "2H", "QC"]', '["6H", "3H", "10D", "7H", "9S"]', 'player', 2, 'Per (Pair) vs Yüksek Kart (High Card)'), ('["6H", "7H", "6S", "8C", "KH"]', '["10D", "10S", "4D", "2C", "4C"]', 'dealer', 0, 'Per (Pair) vs İki Döper (Two Pair)'), ('["4S", "2H", "7C", "2S", "JC"]', '["10S", "5C", "AC", "KC", "9C"]', 'player', 2, 'Per (Pair) vs Yüksek Kart (High Card)'), ('["8D", "KC", "QC", "5S", "4S"]', '["KS", "AS", "QD", "6S", "JD"]', 'dealer', 0, 'Yüksek Kart (High Card) vs Yüksek Kart (High Card)'), ('["QC", "7H", "7S", "2D", "KC"]', '["3D", "7D", "QS", "6S", "2C"]', 'player', 2, 'Per (Pair) vs Yüksek Kart (High Card)'), ('["5S", "3C", "10H", "4S", "6H"]', '["7D", "3D", "KH", "3S", "KC"]', 'dealer', 0, 'Yüksek Kart (High Card) vs İki Döper (Two Pair)'), ('["5S", "AS", "KD", "2S", "KS"]', '["3H", "7S", "7H", "8S", "9H"]', 'player', 2, 'Per (Pair) vs Per (Pair)'), ('["AH", "KS", "QH", "5C", "8S"]', '["7S", "JS", "3H", "4S", "3D"]', 'dealer', 0, 'Yüksek Kart (High Card) vs Per (Pair)'), ('["6S", "7H", "3S", "9D", "AH"]', '["9C", "5D", "10H", "AC", "5S"]', 'dealer', 0, 'Yüksek Kart (High Card) vs Per (Pair)'), ('["7H", "JS", "9C", "QC", "3C"]', '["10D", "3S", "5C", "4D", "10C"]', 'dealer', 0, 'Yüksek Kart (High Card) vs Per (Pair)'), ('["JS", "10C", "KH", "10D", "5D"]', '["3S", "10S", "AH", "3C", "JD"]', 'dealer', 0, 'Per (Pair) vs Per (Pair)'), ('["7S", "JC", "10D", "6C", "QH"]', '["JD", "JH", "KH", "4S", "6H"]', 'dealer', 0, 'Yüksek Kart (High Card) vs Per (Pair)'), ('["3D", "AD", "10S", "8S", "5S"]', '["9C", "5D", "3H", "QC", "7C"]', 'player', 2, 'Yüksek Kart (High Card) vs Yüksek Kart (High Card)'), ('["6C", "KH", "7S", "QD", "6H"]', '["9S", "AD", "5S", "QC", "9C"]', 'dealer', 0, 'Per (Pair) vs Per (Pair)'), ('["3C", "QD", "JD", "AH", "9D"]', '["7D", "JS", "5D", "8S", "6D"]', 'player', 2, 'Yüksek Kart (High Card) vs Yüksek Kart (High Card)'), ('["QD", "JH", "9H", "6S", "5H"]', '["9S", "2D", "4C", "3C", "7H"]', 'player', 2, 'Yüksek Kart (High Card) vs Yüksek Kart (High Card)'), ('["4S", "3C", "QH", "2D", "5D"]', '["5C", "10S", "2H", "3H", "5H"]', 'dealer', 0, 'Yüksek Kart (High Card) vs Per (Pair)'), ('["6S", "2H", "9D", "4S", "7C"]', '["6H", "AD", "KD", "2D", "7D"]', 'dealer', 0, 'Yüksek Kart (High Card) vs Yüksek Kart (High Card)'), ('["KC", "8S", "5D", "3C", "KS"]', '["7S", "6C", "4H", "4D", "3D"]', 'player', 2, 'Per (Pair) vs Per (Pair)'), ('["3H", "5D", "6H", "AH", "JD"]', '["5S", "6S", "AC", "9D", "AD"]', 'dealer', 0, 'Yüksek Kart (High Card) vs Per (Pair)'), ('["6S", "3H", "AH", "2H", "6D"]', '["8C", "2S", "10S", "QH", "7C"]', 'player', 2, 'Per (Pair) vs Yüksek Kart (High Card)'), ('["2H", "10D", "QC", "AC", "2D"]', '["10S", "JD", "AS", "7C", "4C"]', 'player', 2, 'Per (Pair) vs Yüksek Kart (High Card)'), ('["8D", "JC", "10D", "KS", "2H"]', '["KC", "9D", "QH", "AC", "AH"]', 'dealer', 0, 'Yüksek Kart (High Card) vs Per (Pair)'), ('["2C", "7C", "10S", "KH", "7D"]', '["6S", "JH", "QC", "AH", "9D"]', 'player', 2, 'Per (Pair) vs Yüksek Kart (High Card)'), ('["KC", "3D", "9H", "JH", "4C"]', '["10S", "2C", "8S", "KH", "9D"]', 'player', 2, 'Yüksek Kart (High Card) vs Yüksek Kart (High Card)'), ('["JC", "6C", "5H", "3S", "10D"]', '["6D", "KC", "9C", "2C", "KS"]', 'dealer', 0, 'Yüksek Kart (High Card) vs Per (Pair)'), ('["AC", "4S", "10C", "2C", "6H"]', '["5S", "JC", "3H", "6C", "3C"]', 'dealer', 0, 'Yüksek Kart (High Card) vs Per (Pair)'), ('["6D", "9C", "QD", "2H", "10S"]', '["6S", "QC", "KD", "4C", "AC"]', 'dealer', 0, 'Yüksek Kart (High Card) vs Yüksek Kart (High Card)'), ('["2C", "2D", "9S", "QC", "5D"]', '["AS", "JD", "JH", "3C", "KC"]', 'dealer', 0, 'Per (Pair) vs Per (Pair)'), ('["8D", "4D", "9S", "7H", "8H"]', '["7C", "AH", "3C", "4S", "AD"]', 'dealer', 0, 'Per (Pair) vs Per (Pair)'), ('["2H", "QH", "9C", "AS", "3C"]', '["5H", "8S", "6D", "KD", "4C"]', 'player', 2, 'Yüksek Kart (High Card) vs Yüksek Kart (High Card)'), ('["3H", "QC", "KC", "JD", "9C"]', '["AS", "9D", "2C", "JS", "2S"]', 'dealer', 0, 'Yüksek Kart (High Card) vs Per (Pair)'), ('["5D", "JS", "AH", "AC", "QS"]', '["JC", "7H", "10C", "3D", "9H"]', 'player', 2, 'Per (Pair) vs Yüksek Kart (High Card)'), ('["7D", "4H", "7H", "2D", "QC"]', '["5D", "3S", "6S", "8C", "QD"]', 'player', 2, 'Per (Pair) vs Yüksek Kart (High Card)'), ('["AS", "8H", "AC", "5S", "KD"]', '["KS", "5D", "10D", "10S", "2S"]', 'player', 2, 'Per (Pair) vs Per (Pair)'), ('["JS", "8C", "8H", "6D", "3S"]', '["QH", "10H", "AD", "5C", "10S"]', 'dealer', 0, 'Per (Pair) vs Per (Pair)'), ('["6H", "3D", "AD", "4H", "10D"]', '["JS", "6C", "2H", "5C", "JC"]', 'dealer', 0, 'Yüksek Kart (High Card) vs Per (Pair)'), ('["JH", "7H", "5D", "6S", "4D"]', '["9H", "6C", "4C", "3H", "8D"]', 'player', 2, 'Yüksek Kart (High Card) vs Yüksek Kart (High Card)'), ('["3C", "10S", "KC", "8S", "KH"]', '["2H", "QS", "7D", "4C", "2C"]', 'player', 2, 'Per (Pair) vs Per (Pair)'), ('["6C", "AS", "KH", "5D", "QH"]', '["4D", "8S", "3C", "7S", "9C"]', 'player', 2, 'Yüksek Kart (High Card) vs Yüksek Kart (High Card)'), ('["3D", "4S", "2C", "QD", "3H"]', '["5H", "5S", "6S", "QS", "9C"]', 'dealer', 0, 'Per (Pair) vs Per (Pair)'), ('["8S", "7C", "AH", "AC", "7S"]', '["6C", "AS", "8C", "8H", "5H"]', 'player', 3, 'İki Döper (Two Pair) vs Per (Pair)'), ('["3C", "3D", "KC", "8S", "QC"]', '["AD", "KH", "5D", "9D", "9S"]', 'dealer', 0, 'Per (Pair) vs Per (Pair)'), ('["10C", "6D", "KS", "QC", "9H"]', '["8D", "3D", "JD", "7S", "6S"]', 'player', 2, 'Yüksek Kart (High Card) vs Yüksek Kart (High Card)'), ('["6C", "2D", "9D", "7C", "9S"]', '["5D", "7S", "3C", "KD", "JC"]', 'player', 2, 'Per (Pair) vs Yüksek Kart (High Card)'), ('["4D", "JH", "QS", "QH", "JC"]', '["3D", "QC", "8H", "KC", "9H"]', 'player', 3, 'İki Döper (Two Pair) vs Yüksek Kart (High Card)'), ('["5S", "4H", "QC", "AH", "2H"]', '["7C", "5D", "8C", "9S", "3H"]', 'player', 2, 'Yüksek Kart (High Card) vs Yüksek Kart (High Card)'), ('["10H", "6H", "10S", "QD", "JS"]', '["JC", "8D", "5D", "2C", "4H"]', 'player', 2, 'Per (Pair) vs Yüksek Kart (High Card)'), ('["5C", "6S", "8C", "4C", "AS"]', '["7H", "7D", "6C", "4S", "KC"]', 'dealer', 0, 'Yüksek Kart (High Card) vs Per (Pair)'), ('["9S", "KD", "QH", "JD", "3S"]', '["4H", "KH", "8D", "7D", "9C"]', 'player', 2, 'Yüksek Kart (High Card) vs Yüksek Kart (High Card)'), ('["6C", "KS", "KH", "5H", "4H"]', '["9C", "JD", "2C", "3H", "QS"]', 'player', 2, 'Per (Pair) vs Yüksek Kart (High Card)'), ('["KC", "8H", "KD", "6H", "4S"]', '["4H", "7D", "KS", "6S", "KH"]', 'player', 2, 'Per (Pair) vs Per (Pair)'), ('["AD", "KH", "3D", "JC", "3C"]', '["6C", "9D", "5D", "QD", "2H"]', 'player', 2, 'Per (Pair) vs Yüksek Kart (High Card)'), ('["JC", "2D", "QD", "10S", "10C"]', '["6D", "7C", "4C", "AC", "3S"]', 'player', 2, 'Per (Pair) vs Yüksek Kart (High Card)'), ('["JD", "4S", "5D", "AD", "6D"]', '["9C", "QD", "KS", "KH", "9S"]', 'dealer', 0, 'Yüksek Kart (High Card) vs İki Döper (Two Pair)'), ('["2H", "QC", "9C", "AS", "10D"]', '["8D", "QH", "10H", "4D", "3D"]', 'player', 2, 'Yüksek Kart (High Card) vs Yüksek Kart (High Card)'), ('["KS", "2C", "4S", "QH", "9H"]', '["3D", "JS", "KC", "6S", "JC"]', 'dealer', 0, 'Yüksek Kart (High Card) vs Per (Pair)'), ('["4S", "JH", "10C", "7S", "8H"]', '["QH", "9H", "3H", "6D", "AD"]', 'dealer', 0, 'Yüksek Kart (High Card) vs Yüksek Kart (High Card)'), ('["10S", "3S", "JC", "AC", "10H"]', '["2C", "QS", "6S", "7S", "AS"]', 'player', 2, 'Per (Pair) vs Yüksek Kart (High Card)'), ('["3S", "QD", "5D", "QC", "2H"]', '["4D", "8C", "9H", "9D", "KC"]', 'dealer', 0, 'Per (Pair) vs Per (Pair)'), ('["9D", "AC", "5D", "9S", "4S"]', '["2H", "6D", "7C", "3D", "JD"]', 'player', 2, 'Per (Pair) vs Yüksek Kart (High Card)'), ('["3H", "JH", "2S", "2D", "4D"]', '["9D", "QC", "QS", "KD", "7S"]', 'dealer', 0, 'Per (Pair) vs Per (Pair)'), ('["2D", "4C", "10D", "9S", "4S"]', '["2S", "JS", "2C", "10H", "10C"]', 'dealer', 0, 'Per (Pair) vs İki Döper (Two Pair)');
    END IF;

    v_rnd := floor(random() * 500) + 1;
    SELECT * INTO v_matrix FROM tmp_poker_matchups WHERE id = v_rnd;

    IF v_matrix.winner = 'player' OR v_matrix.winner = 'draw' THEN
        UPDATE public.marino_players SET casino_chips = casino_chips + (p_bet_amount * v_matrix.payout) WHERE telegram_id = p_telegram_id;
    END IF;

    RETURN jsonb_build_object(
        'player_hand', v_matrix.p_hand,
        'dealer_hand', v_matrix.d_hand,
        'winner', v_matrix.winner,
        'payout_mult', v_matrix.payout,
        'payoutAmount', p_bet_amount * v_matrix.payout,
        'desc', v_matrix.description,
        'new_balance', v_user.casino_chips - p_bet_amount + (p_bet_amount * v_matrix.payout)
    );
END;
$$;

-- FUNCTION: marino_play_roulette(text, bigint, text, text)
CREATE FUNCTION public.marino_play_roulette(p_telegram_id text, p_bet_amount bigint, p_bet_type text, p_request_id text DEFAULT ''::text) RETURNS jsonb
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path = pg_catalog, public
    AS $$
DECLARE
    v_player record;
    v_b_level int;
    v_roll int;
    v_color text;
    v_win_amount bigint := 0;
BEGIN
    IF p_request_id != '' THEN
        IF EXISTS (SELECT 1 FROM public.marino_processed_requests WHERE request_id = p_request_id) THEN RAISE EXCEPTION 'İşlenmiş istek.'; END IF;
        INSERT INTO public.marino_processed_requests (request_id, created_at) VALUES (p_request_id, now());
    END IF;

    SELECT * INTO v_player FROM public.marino_players WHERE telegram_id = p_telegram_id;
    IF NOT FOUND THEN RAISE EXCEPTION 'Oyuncu bulunamadı.'; END IF;
    IF v_player.is_banned THEN RAISE EXCEPTION 'Hesabınız yasaklı.'; END IF;
    IF v_player.marino_coin < p_bet_amount THEN RAISE EXCEPTION 'Yetersiz bakiye.'; END IF;

    -- Rulet için VIP Casino seviye 5 şartı
    SELECT level INTO v_b_level FROM public.marino_player_buildings WHERE player_id = v_player.id AND building_key = 'vip_casino';
    IF COALESCE(v_b_level, 0) < 5 THEN
        RAISE EXCEPTION 'Rulet masasına oturmak için VIP Casino binasını 5. Seviyeye yükseltmelisin.';
    END IF;

    IF p_bet_type NOT IN ('red', 'black', 'green') THEN RAISE EXCEPTION 'Geçersiz bahis.'; END IF;

    -- European Roulette RNG (0 - 36)
    v_roll := floor(random() * 37)::int;

    IF v_roll = 0 THEN
        v_color := 'green';
    ELSIF v_roll IN (1,3,5,7,9,12,14,16,18,19,21,23,25,27,30,32,34,36) THEN
        v_color := 'red';
    ELSE
        v_color := 'black';
    END IF;

    IF p_bet_type = v_color THEN
        IF v_color = 'green' THEN v_win_amount := p_bet_amount * 36;
        ELSE v_win_amount := p_bet_amount * 2; END IF;
    END IF;

    UPDATE public.marino_players
    SET marino_coin = marino_coin - p_bet_amount + v_win_amount, updated_at = now()
    WHERE telegram_id = p_telegram_id
    RETURNING * INTO v_player;

    RETURN jsonb_build_object(
        'roll', v_roll,
        'color', v_color,
        'win_amount', v_win_amount,
        'state', row_to_json(v_player)
    );
END;
$$;

-- FUNCTION: marino_play_roulette_v2(text, jsonb, text)
CREATE FUNCTION public.marino_play_roulette_v2(p_telegram_id text, p_bets jsonb, p_request_id text DEFAULT ''::text) RETURNS jsonb
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path = pg_catalog, public
    AS $_$
DECLARE
    v_player record;
    v_b_level int;
    v_roll int;
    v_color text;
    v_total_bet bigint := 0;
    v_win_amount bigint := 0;
    v_bet record;
    v_key text;
    v_amt bigint;
BEGIN
    IF p_request_id != '' THEN
        IF EXISTS (SELECT 1 FROM public.marino_processed_requests WHERE request_id = p_request_id) THEN RAISE EXCEPTION 'İşlenmiş istek.'; END IF;
        INSERT INTO public.marino_processed_requests (request_id, created_at) VALUES (p_request_id, now());
    END IF;

    SELECT * INTO v_player FROM public.marino_players WHERE telegram_id = p_telegram_id;
    IF NOT FOUND THEN RAISE EXCEPTION 'Oyuncu bulunamadı.'; END IF;

    -- Toplam bahis (Çip) miktarını hesapla
    FOR v_bet IN SELECT * FROM jsonb_each_text(p_bets) LOOP
        v_total_bet := v_total_bet + v_bet.value::bigint;
    END LOOP;

    IF v_total_bet <= 0 THEN RAISE EXCEPTION 'Bahis yapılmadı.'; END IF;
    IF COALESCE(v_player.casino_chips, 0) < v_total_bet THEN RAISE EXCEPTION 'Yetersiz Çip bakiye.'; END IF;

    -- Gerçek RNG Motoru (0 - 36)
    v_roll := floor(random() * 37)::int;

    IF v_roll = 0 THEN v_color := 'green';
    ELSIF v_roll IN (1,3,5,7,9,12,14,16,18,19,21,23,25,27,30,32,34,36) THEN v_color := 'red';
    ELSE v_color := 'black'; END IF;

    -- Tüm bahis kollarını değerlendir
    FOR v_bet IN SELECT * FROM jsonb_each_text(p_bets) LOOP
       v_key := v_bet.key;
       v_amt := v_bet.value::bigint;

       IF v_key ~ '^[0-9]+$' AND v_key::int = v_roll THEN v_win_amount := v_win_amount + (v_amt * 36);
       ELSIF v_key = 'red' AND v_color = 'red' THEN v_win_amount := v_win_amount + (v_amt * 2);
       ELSIF v_key = 'black' AND v_color = 'black' THEN v_win_amount := v_win_amount + (v_amt * 2);
       ELSIF v_key = 'even' AND v_roll != 0 AND v_roll % 2 = 0 THEN v_win_amount := v_win_amount + (v_amt * 2);
       ELSIF v_key = 'odd'  AND v_roll != 0 AND v_roll % 2 = 1 THEN v_win_amount := v_win_amount + (v_amt * 2);
       ELSIF v_key = 'low' AND v_roll BETWEEN 1 AND 18 THEN v_win_amount := v_win_amount + (v_amt * 2);
       ELSIF v_key = 'high' AND v_roll BETWEEN 19 AND 36 THEN v_win_amount := v_win_amount + (v_amt * 2);
       ELSIF v_key = '1st12' AND v_roll BETWEEN 1 AND 12 THEN v_win_amount := v_win_amount + (v_amt * 3);
       ELSIF v_key = '2nd12' AND v_roll BETWEEN 13 AND 24 THEN v_win_amount := v_win_amount + (v_amt * 3);
       ELSIF v_key = '3rd12' AND v_roll BETWEEN 25 AND 36 THEN v_win_amount := v_win_amount + (v_amt * 3);
       ELSIF v_key = 'col1' AND v_roll != 0 AND v_roll % 3 = 1 THEN v_win_amount := v_win_amount + (v_amt * 3);
       ELSIF v_key = 'col2' AND v_roll != 0 AND v_roll % 3 = 2 THEN v_win_amount := v_win_amount + (v_amt * 3);
       ELSIF v_key = 'col3' AND v_roll != 0 AND v_roll % 3 = 0 THEN v_win_amount := v_win_amount + (v_amt * 3);
       END IF;
    END LOOP;

    -- Bakiyeyi güncelle (Çipleri kes, yatır)
    UPDATE public.marino_players
    SET casino_chips = casino_chips - v_total_bet + v_win_amount, updated_at = now()
    WHERE telegram_id = p_telegram_id
    RETURNING * INTO v_player;

    RETURN jsonb_build_object(
        'roll', v_roll,
        'color', v_color,
        'win_amount', v_win_amount,
        'bets', p_bets,
        'state', row_to_json(v_player)
    );
END;
$_$;

-- FUNCTION: marino_play_slot(text, bigint, text)
CREATE FUNCTION public.marino_play_slot(p_telegram_id text, p_bet_amount bigint, p_request_id text DEFAULT ''::text) RETURNS jsonb
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path = pg_catalog, public
    AS $$
DECLARE
    v_player record;
    v_b_level int;
    v_outcome int;
    v_roll int;
    v_win_amount bigint := 0;
    v_symbols text[];
    v_sym_list text[] := ARRAY['🍒', '🥑', '🔔', '💎', '👑', '7️⃣'];
BEGIN
    -- Request ID koruması
    IF p_request_id != '' THEN
        IF EXISTS (SELECT 1 FROM public.marino_processed_requests WHERE request_id = p_request_id) THEN
            RAISE EXCEPTION 'Bu slot dönüşü zaten işlendi.';
        END IF;
        INSERT INTO public.marino_processed_requests (request_id, created_at) VALUES (p_request_id, now());
    END IF;

    -- Oyuncu kontrolü
    SELECT * INTO v_player FROM public.marino_players WHERE telegram_id = p_telegram_id;
    IF NOT FOUND THEN RAISE EXCEPTION 'Oyuncu bulunamadı.'; END IF;
    IF v_player.is_banned THEN RAISE EXCEPTION 'Hesabınız yasaklı.'; END IF;
    IF v_player.marino_coin < p_bet_amount THEN RAISE EXCEPTION 'Yetersiz bakiye.'; END IF;

    -- Bina kilit kontrolü (Slot Alanı seviye 10 gerekli)
    SELECT level INTO v_b_level FROM public.marino_player_buildings WHERE player_id = v_player.id AND building_key = 'slot_area';
    IF COALESCE(v_b_level, 0) < 10 THEN
        RAISE EXCEPTION 'Slot oyunlarını açmak için Slot Alanı binasını 10. Seviyeye yükseltmelisin.';
    END IF;

    -- RNG (1 - 1000)
    v_roll := floor(random() * 1000 + 1)::int;

    -- Ödeme Tablosu ve Sembol Seçimi
    IF v_roll <= 450 THEN
        -- %45 İhtimal (Kaybetti, 0x)
        v_win_amount := 0;
        v_symbols := ARRAY[ v_sym_list[floor(random()*6+1)::int], v_sym_list[floor(random()*6+1)::int], v_sym_list[floor(random()*6+1)::int] ];
        -- 3'lü aynısını denk getirmemek için ufak müdahale
        IF v_symbols[1] = v_symbols[2] AND v_symbols[2] = v_symbols[3] THEN v_symbols[3] := v_sym_list[1]; END IF;

    ELSIF v_roll <= 700 THEN
        -- %25 İhtimal (Teselli, 0.5x - 2'li eşleşme)
        v_win_amount := floor(p_bet_amount * 0.5);
        v_symbols := ARRAY['🍒', '🍒', '🥑'];

    ELSIF v_roll <= 900 THEN
        -- %20 İhtimal (Ufak Kazanç, 1.5x)
        v_win_amount := floor(p_bet_amount * 1.5);
        v_symbols := ARRAY['🥑', '🥑', '🥑'];

    ELSIF v_roll <= 950 THEN
        -- %5 İhtimal (İyi Kazanç, 3x)
        v_win_amount := floor(p_bet_amount * 3);
        v_symbols := ARRAY['🔔', '🔔', '🔔'];

    ELSIF v_roll <= 995 THEN
        -- %4.5 İhtimal (Büyük Kazanç, 5x)
        v_win_amount := floor(p_bet_amount * 5);
        v_symbols := ARRAY['👑', '👑', '👑'];

    ELSE
        -- %0.5 İhtimal (Jackpot, 20x)
        v_win_amount := floor(p_bet_amount * 20);
        v_symbols := ARRAY['7️⃣', '7️⃣', '7️⃣'];
    END IF;

    -- Bakiyeyi güncelle (Bahisi kes, kazancı ekle)
    UPDATE public.marino_players
    SET marino_coin = marino_coin - p_bet_amount + v_win_amount, updated_at = now()
    WHERE telegram_id = p_telegram_id
    RETURNING * INTO v_player;

    RETURN jsonb_build_object(
        'symbols', v_symbols,
        'win_amount', v_win_amount,
        'bet_amount', p_bet_amount,
        'state', row_to_json(v_player)
    );
END;
$$;

-- FUNCTION: marino_play_virtual_sports(text, text, bigint, text)
CREATE FUNCTION public.marino_play_virtual_sports(p_telegram_id text, p_bet_choice text, p_bet_amount bigint, p_request_id text DEFAULT ''::text) RETURNS jsonb
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path = pg_catalog, public
    AS $$
DECLARE
    v_player record;
    v_cost bigint;
    v_win_amount bigint := 0;
    v_result text;
    v_odds numeric;
    v_rand int;
BEGIN
    IF p_request_id != '' THEN
        IF EXISTS (SELECT 1 FROM public.marino_processed_requests WHERE request_id = p_request_id) THEN RAISE EXCEPTION 'İşlenmiş istek.'; END IF;
        INSERT INTO public.marino_processed_requests (request_id, created_at) VALUES (p_request_id, now());
    END IF;

    v_cost := p_bet_amount * 1000; -- Sanal Sporlar Marino Coin ile oynansın! (Veya çiple, opsiyonel)
    -- Edit: Kullanıcı Çip aldığını düşününce sporları da çip ile yapalım daha iyi durur.
    SELECT * INTO v_player FROM public.marino_players WHERE telegram_id = p_telegram_id;
    IF NOT FOUND THEN RAISE EXCEPTION 'Oyuncu bulunamadı.'; END IF;

    IF COALESCE(v_player.casino_chips, 0) < p_bet_amount THEN RAISE EXCEPTION 'Spor bahisleri için yetersiz Çip.'; END IF;

    -- Sabit Oranlar: Ev(1)=2.10, X=3.00, Dep(2)=2.50
    -- Ev Sahibi (40%), X (30%), Deplasman (30%)
    v_rand := floor(random() * 100);
    IF v_rand < 40 THEN v_result := '1';
    ELSIF v_rand < 70 THEN v_result := 'X';
    ELSE v_result := '2'; END IF;

    IF p_bet_choice = v_result THEN
        IF p_bet_choice = '1' THEN v_odds := 2.10;
        ELSIF p_bet_choice = 'X' THEN v_odds := 3.00;
        ELSE v_odds := 2.50; END IF;
        v_win_amount := floor(p_bet_amount * v_odds);
    END IF;

    -- Bakiyeyi güncelle
    UPDATE public.marino_players
    SET casino_chips = casino_chips - p_bet_amount + v_win_amount, updated_at = now()
    WHERE id = v_player.id
    RETURNING * INTO v_player;

    RETURN jsonb_build_object(
        'match_result', v_result,
        'your_choice', p_bet_choice,
        'win_amount', v_win_amount,
        'state', row_to_json(v_player)
    );
END;
$$;

-- FUNCTION: marino_prestige(text, text)
CREATE FUNCTION public.marino_prestige(p_telegram_id text, p_request_id text DEFAULT ''::text) RETURNS jsonb
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path = pg_catalog, public
    AS $$
DECLARE
  v_player marino_players%ROWTYPE;
  v_upgrades JSONB;
BEGIN
  IF p_request_id != '' THEN
    INSERT INTO marino_processed_requests (request_id) VALUES (p_request_id)
    ON CONFLICT DO NOTHING;
    IF NOT FOUND THEN RAISE EXCEPTION 'Bu işlem zaten işlendi.'; END IF;
  END IF;

  SELECT * INTO v_player FROM marino_players WHERE telegram_id = p_telegram_id;
  IF NOT FOUND THEN RAISE EXCEPTION 'Oyuncu bulunamadı.'; END IF;

  IF v_player.casino_level < 50 AND v_player.reputation < 50000 THEN
    RAISE EXCEPTION 'Prestij için seviye 50 veya 50.000 XP gerekli.';
  END IF;

  -- Sıfırla
  UPDATE marino_players SET
    marino_coin = 0,
    energy = 500,
    max_energy = 500,
    tap_power = 1,
    passive_income_per_hour = 0,
    claimable_coin = 0,
    casino_level = 1,
    reputation = 0,
    prestige_points = prestige_points + 1,
    offline_capacity_hours = 8,
    updated_at = NOW()
  WHERE id = v_player.id
  RETURNING * INTO v_player;

  -- Binaları sıfırla
  UPDATE marino_player_buildings SET level = 0 WHERE player_id = v_player.id;

  -- Güncel binalar
  SELECT COALESCE(jsonb_agg(row_to_json(t)::jsonb ORDER BY t.sort_order), '[]'::jsonb)
  INTO v_upgrades
  FROM (
    SELECT b.building_key, b.building_name, pb.level,
      FLOOR(b.base_income * POWER(1.12, pb.level) * (1 + v_player.prestige_points * 0.03)) AS current_income_per_hour,
      FLOOR(b.base_cost * POWER(b.cost_multiplier, pb.level) * (1 + v_player.prestige_points * 0.02)) AS next_cost_coin,
      b.unlock_level, b.sort_order
    FROM marino_buildings b
    JOIN marino_player_buildings pb ON pb.building_key = b.building_key AND pb.player_id = v_player.id
  ) t;

  RETURN jsonb_build_object(
    'state', jsonb_build_object(
      'marino_coin', v_player.marino_coin,
      'reward_token', v_player.reward_token,
      'energy', v_player.energy,
      'max_energy', v_player.max_energy,
      'tap_power', v_player.tap_power,
      'passive_income_per_hour', v_player.passive_income_per_hour,
      'casino_level', v_player.casino_level,
      'reputation', v_player.reputation,
      'claimable_coin', v_player.claimable_coin,
      'offline_capacity_hours', v_player.offline_capacity_hours,
      'prestige_points', v_player.prestige_points
    ),
    'upgrades', v_upgrades,
    'message', 'Prestij tamamlandı! Kalıcı +%' || (v_player.prestige_points * 5)::text || ' güç kazandın.'
  );
END;
$$;

-- FUNCTION: marino_random_card()
CREATE FUNCTION public.marino_random_card() RETURNS text
    LANGUAGE plpgsql
    AS $$
DECLARE
    suits text[] := ARRAY['S', 'C', 'H', 'D'];
    values text[] := ARRAY['2','3','4','5','6','7','8','9','0','J','Q','K','A'];
    s text;
    v text;
BEGIN
    s := suits[floor(random() * 4 + 1)::int];
    v := values[floor(random() * 13 + 1)::int];
    RETURN v || s;
END;
$$;

-- FUNCTION: marino_recalculate_income(text)
CREATE FUNCTION public.marino_recalculate_income(p_telegram_id text) RETURNS numeric
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path = pg_catalog, public
    AS $$
declare v_income numeric;
begin
  select coalesce(sum(marino_building_income(ub.level, bt.base_income_per_hour, bt.income_multiplier)),0)
    into v_income
  from marino_user_buildings ub
  join marino_building_types bt on bt.building_key = ub.building_key
  where ub.telegram_id = p_telegram_id and bt.is_active = true;

  update marino_game_state
     set passive_income_per_hour = v_income,
         updated_at = now()
   where telegram_id = p_telegram_id;

  return v_income;
end;
$$;

-- FUNCTION: marino_reward_status(text)
CREATE FUNCTION public.marino_reward_status(p_telegram_id text) RETURNS jsonb
    LANGUAGE sql STABLE
    AS $$
  with s as (
    select
      (select count(*) from public.marino_reward_requests r
       where r.telegram_id = p_telegram_id and r.status = 'pending') as pending_count,
      (select count(*) from public.marino_reward_requests r
       where r.telegram_id = p_telegram_id and r.created_at >= date_trunc('day', now())) as daily_used
  )
  select jsonb_build_object(
    'pending_count', pending_count,
    'daily_used', daily_used,
    'daily_limit', 1,
    'can_request', (pending_count = 0 and daily_used < 1)
  )
  from s;
$$;

-- FUNCTION: marino_save_settings(text, text, text, boolean, boolean, text)
CREATE FUNCTION public.marino_save_settings(p_telegram_id text, p_country_code text DEFAULT 'TR'::text, p_country_name text DEFAULT 'Türkiye'::text, p_sound_enabled boolean DEFAULT true, p_music_enabled boolean DEFAULT false, p_music_path text DEFAULT 'public/assets/audio/fon.mp3'::text) RETURNS jsonb
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path = pg_catalog, public
    AS $$
BEGIN
  UPDATE marino_players SET
    country_code = p_country_code,
    country_name = p_country_name,
    sound_enabled = p_sound_enabled,
    music_enabled = p_music_enabled,
    music_path = p_music_path,
    updated_at = NOW()
  WHERE telegram_id = p_telegram_id;

  RETURN jsonb_build_object('ok', TRUE);
END;
$$;

-- FUNCTION: marino_store_json()
CREATE FUNCTION public.marino_store_json() RETURNS jsonb
    LANGUAGE sql SECURITY DEFINER
    SET search_path = pg_catalog, public
    AS $$
  select coalesce(jsonb_agg(to_jsonb(x) order by x.sort_order), '[]'::jsonb)
  from (
    select item_code,item_name,description,cost_coin,cost_token,reward_type,reward_value,sort_order
    from marino_store_items
    where is_active = true
  ) x;
$$;

-- FUNCTION: marino_touch_state(text)
CREATE FUNCTION public.marino_touch_state(p_telegram_id text) RETURNS jsonb
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path = pg_catalog, public
    AS $$
declare s marino_game_state%rowtype;
declare v_now timestamptz := now();
declare v_energy numeric;
declare v_claim numeric;
begin
  select * into s from marino_game_state where telegram_id = p_telegram_id for update;
  if not found then
    raise exception 'Oyun kaydı bulunamadı.';
  end if;

  v_energy := least(s.max_energy, s.energy + greatest(0, extract(epoch from (v_now - coalesce(s.last_energy_at, v_now)))) * 0.20);
  v_claim := s.claimable_coin + greatest(0, extract(epoch from (v_now - coalesce(s.last_income_at, v_now)))) * (s.passive_income_per_hour / 3600.0);

  update marino_game_state
     set energy = round(v_energy,0),
         claimable_coin = round(v_claim,0),
         last_energy_at = v_now,
         last_income_at = v_now,
         casino_level = marino_level_from_rep(reputation),
         updated_at = v_now
   where telegram_id = p_telegram_id
   returning * into s;

  return to_jsonb(s);
end;
$$;

-- FUNCTION: marino_upgrade_capacity(text, text)
CREATE FUNCTION public.marino_upgrade_capacity(p_telegram_id text, p_request_id text DEFAULT ''::text) RETURNS jsonb
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path = pg_catalog, public
    AS $$
DECLARE
  v_player marino_players%ROWTYPE;
  v_cost BIGINT;
BEGIN
  IF p_request_id != '' THEN
    INSERT INTO marino_processed_requests (request_id) VALUES (p_request_id)
    ON CONFLICT DO NOTHING;
    IF NOT FOUND THEN RAISE EXCEPTION 'Bu işlem zaten işlendi.'; END IF;
  END IF;

  SELECT * INTO v_player FROM marino_players WHERE telegram_id = p_telegram_id;
  IF NOT FOUND THEN RAISE EXCEPTION 'Oyuncu bulunamadı.'; END IF;

  IF v_player.offline_capacity_hours >= 24 THEN
    RAISE EXCEPTION 'Kasa kapasitesi zaten maksimum (24 saat).';
  END IF;

  v_cost := FLOOR(2500 + POWER(GREATEST(1, v_player.offline_capacity_hours - 7), 2) * 900);

  IF v_player.marino_coin < v_cost THEN
    RAISE EXCEPTION 'Yetersiz coin. Gerekli: %', v_cost;
  END IF;

  UPDATE marino_players SET
    marino_coin = marino_coin - v_cost,
    offline_capacity_hours = offline_capacity_hours + 1,
    reputation = reputation + 2,
    updated_at = NOW()
  WHERE id = v_player.id
  RETURNING * INTO v_player;

  RETURN jsonb_build_object(
    'state', jsonb_build_object(
      'marino_coin', v_player.marino_coin,
      'reward_token', v_player.reward_token,
      'energy', v_player.energy,
      'max_energy', v_player.max_energy,
      'tap_power', v_player.tap_power,
      'passive_income_per_hour', v_player.passive_income_per_hour,
      'casino_level', v_player.casino_level,
      'reputation', v_player.reputation,
      'claimable_coin', v_player.claimable_coin,
      'offline_capacity_hours', v_player.offline_capacity_hours,
      'prestige_points', v_player.prestige_points
    )
  );
END;
$$;

-- FUNCTION: marino_upgrade_energy_limit(text)
CREATE FUNCTION public.marino_upgrade_energy_limit(p_telegram_id text) RETURNS jsonb
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path = pg_catalog, public
    AS $$
DECLARE r marino_player_boosts; p marino_players; cost bigint;
BEGIN
  PERFORM _marino_ensure_boost(p_telegram_id);
  SELECT * INTO r FROM marino_player_boosts WHERE telegram_id = p_telegram_id FOR UPDATE;
  SELECT * INTO p FROM marino_players WHERE telegram_id = p_telegram_id FOR UPDATE;
  cost := 1000 * (2 ^ r.energy_lvl)::bigint;
  IF p.marino_coin < cost THEN RETURN jsonb_build_object('ok',false,'error','insufficient_coin','cost',cost); END IF;
  UPDATE marino_players SET marino_coin = marino_coin - cost, max_energy = max_energy + 500, energy = max_energy + 500, updated_at = NOW() WHERE telegram_id = p_telegram_id;
  UPDATE marino_player_boosts SET energy_lvl = energy_lvl + 1, updated_at = NOW() WHERE telegram_id = p_telegram_id;
  RETURN jsonb_build_object('ok',true,'new_level',r.energy_lvl+1,'new_max_energy',p.max_energy+500,'cost',cost);
END$$;

-- FUNCTION: marino_upgrade_multitap(text)
CREATE FUNCTION public.marino_upgrade_multitap(p_telegram_id text) RETURNS jsonb
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path = pg_catalog, public
    AS $$
DECLARE r marino_player_boosts; p marino_players; cost bigint;
BEGIN
  PERFORM _marino_ensure_boost(p_telegram_id);
  SELECT * INTO r FROM marino_player_boosts WHERE telegram_id = p_telegram_id FOR UPDATE;
  SELECT * INTO p FROM marino_players WHERE telegram_id = p_telegram_id FOR UPDATE;
  cost := 1000 * (2 ^ r.multitap_lvl)::bigint;
  IF p.marino_coin < cost THEN RETURN jsonb_build_object('ok',false,'error','insufficient_coin','cost',cost); END IF;
  UPDATE marino_players SET marino_coin = marino_coin - cost, tap_power = tap_power + 1, updated_at = NOW() WHERE telegram_id = p_telegram_id;
  UPDATE marino_player_boosts SET multitap_lvl = multitap_lvl + 1, updated_at = NOW() WHERE telegram_id = p_telegram_id;
  RETURN jsonb_build_object('ok',true,'new_level',r.multitap_lvl+1,'new_tap_power',p.tap_power+1,'cost',cost);
END$$;

-- FUNCTION: marino_upgrade_tap(text, text)
CREATE FUNCTION public.marino_upgrade_tap(p_telegram_id text, p_request_id text DEFAULT ''::text) RETURNS jsonb
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path = pg_catalog, public
    AS $$
DECLARE
  v_player marino_players%ROWTYPE;
  v_cost BIGINT;
BEGIN
  IF p_request_id != '' THEN
    INSERT INTO marino_processed_requests (request_id) VALUES (p_request_id)
    ON CONFLICT DO NOTHING;
    IF NOT FOUND THEN RAISE EXCEPTION 'Bu işlem zaten işlendi.'; END IF;
  END IF;

  SELECT * INTO v_player FROM marino_players WHERE telegram_id = p_telegram_id;
  IF NOT FOUND THEN RAISE EXCEPTION 'Oyuncu bulunamadı.'; END IF;

  -- Maliyet = 500 × (1.18 ^ seviye) × (1 + prestige × 0.04)
  v_cost := FLOOR(500 * POWER(1.18, v_player.tap_power) * (1 + v_player.prestige_points * 0.04));

  IF v_player.marino_coin < v_cost THEN
    RAISE EXCEPTION 'Yetersiz coin. Gerekli: %', v_cost;
  END IF;

  UPDATE marino_players SET
    marino_coin = marino_coin - v_cost,
    tap_power = tap_power + 1,
    max_energy = max_energy + 10,
    reputation = reputation + 3,
    updated_at = NOW()
  WHERE id = v_player.id
  RETURNING * INTO v_player;

  RETURN jsonb_build_object(
    'state', jsonb_build_object(
      'marino_coin', v_player.marino_coin,
      'reward_token', v_player.reward_token,
      'energy', v_player.energy,
      'max_energy', v_player.max_energy,
      'tap_power', v_player.tap_power,
      'passive_income_per_hour', v_player.passive_income_per_hour,
      'casino_level', v_player.casino_level,
      'reputation', v_player.reputation,
      'claimable_coin', v_player.claimable_coin,
      'offline_capacity_hours', v_player.offline_capacity_hours,
      'prestige_points', v_player.prestige_points
    )
  );
END;
$$;

-- FUNCTION: marino_upgrades_json(text)
CREATE FUNCTION public.marino_upgrades_json(p_telegram_id text) RETURNS jsonb
    LANGUAGE sql SECURITY DEFINER
    SET search_path = pg_catalog, public
    AS $$
  select coalesce(jsonb_agg(jsonb_build_object(
    'building_key', bt.building_key,
    'building_name', bt.building_name,
    'level', coalesce(ub.level,0),
    'current_income_per_hour', marino_building_income(coalesce(ub.level,0), bt.base_income_per_hour, bt.income_multiplier),
    'next_cost_coin', round((bt.base_cost_coin * power(bt.cost_multiplier, coalesce(ub.level,0)))::numeric,0),
    'sort_order', bt.sort_order
  ) order by bt.sort_order), '[]'::jsonb)
  from marino_building_types bt
  left join marino_user_buildings ub on ub.building_key = bt.building_key and ub.telegram_id = p_telegram_id
  where bt.is_active = true;
$$;

-- FUNCTION: marino_use_full_energy(text)
CREATE FUNCTION public.marino_use_full_energy(p_telegram_id text) RETURNS jsonb
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path = pg_catalog, public
    AS $$
DECLARE r marino_player_boosts; p marino_players;
BEGIN
  PERFORM _marino_ensure_boost(p_telegram_id);
  SELECT * INTO r FROM marino_player_boosts WHERE telegram_id = p_telegram_id FOR UPDATE;
  IF r.full_energy_used >= 3 THEN RETURN jsonb_build_object('ok',false,'error','no_uses_left'); END IF;
  UPDATE marino_player_boosts SET full_energy_used = full_energy_used+1, updated_at=NOW() WHERE telegram_id = p_telegram_id;
  UPDATE marino_players SET energy = max_energy, last_energy_update = NOW(), updated_at = NOW()
    WHERE telegram_id = p_telegram_id RETURNING * INTO p;
  RETURN jsonb_build_object('ok',true,'energy',p.energy,'max_energy',p.max_energy,'left',2-r.full_energy_used);
END$$;

-- FUNCTION: marino_use_tap_boost(text)
CREATE FUNCTION public.marino_use_tap_boost(p_telegram_id text) RETURNS jsonb
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path = pg_catalog, public
    AS $$
DECLARE r marino_player_boosts;
BEGIN
  PERFORM _marino_ensure_boost(p_telegram_id);
  SELECT * INTO r FROM marino_player_boosts WHERE telegram_id = p_telegram_id FOR UPDATE;
  IF r.tap_boost_used >= 3 THEN RETURN jsonb_build_object('ok',false,'error','no_uses_left'); END IF;
  UPDATE marino_player_boosts SET tap_boost_used = tap_boost_used+1, updated_at=NOW() WHERE telegram_id = p_telegram_id;
  RETURN jsonb_build_object('ok',true,'multiplier',5,'duration_sec',20,'left',2-r.tap_boost_used);
END$$;

-- FUNCTION: register_player(text, text, text, text, text, text)
CREATE FUNCTION public.register_player(p_telegram_id text, p_site_username text, p_telegram_username text, p_first_name text, p_last_name text, p_language_code text) RETURNS jsonb
    LANGUAGE sql SECURITY DEFINER
    SET search_path = pg_catalog, public
    AS $$
  select public.start_game(
    p_telegram_id,
    p_site_username,
    p_telegram_username,
    p_first_name,
    p_last_name,
    p_language_code,
    ''
  );
$$;

-- FUNCTION: register_player(text, text, text, text, text, text, text)
CREATE FUNCTION public.register_player(p_telegram_id text, p_site_username text, p_telegram_username text, p_first_name text, p_last_name text, p_language_code text, p_referred_by text) RETURNS jsonb
    LANGUAGE sql SECURITY DEFINER
    SET search_path = pg_catalog, public
    AS $$
  select public.start_game(
    p_telegram_id,
    p_site_username,
    p_telegram_username,
    p_first_name,
    p_last_name,
    p_language_code,
    p_referred_by
  );
$$;

-- FUNCTION: request_reward(text, text, text)
CREATE FUNCTION public.request_reward(p_telegram_id text, p_item_code text, p_request_id text DEFAULT ''::text) RETURNS jsonb
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path = pg_catalog, public
    AS $$
DECLARE
  v_player marino_players%ROWTYPE;
  v_item marino_store_items%ROWTYPE;
  v_pending INT;
  v_daily_used INT;
  v_weekly_used INT;
BEGIN
  IF p_request_id != '' THEN
    INSERT INTO marino_processed_requests (request_id) VALUES (p_request_id)
    ON CONFLICT DO NOTHING;
    IF NOT FOUND THEN RAISE EXCEPTION 'Bu işlem zaten işlendi.'; END IF;
  END IF;

  SELECT * INTO v_player FROM marino_players WHERE telegram_id = p_telegram_id;
  IF NOT FOUND THEN RAISE EXCEPTION 'Oyuncu bulunamadı.'; END IF;

  SELECT * INTO v_item FROM marino_store_items WHERE item_code = p_item_code AND is_active = TRUE;
  IF NOT FOUND THEN RAISE EXCEPTION 'Ürün bulunamadı.'; END IF;

  -- Seviye kontrolü
  IF v_player.casino_level < v_item.min_level THEN
    RAISE EXCEPTION 'Bu ödül için minimum seviye: %', v_item.min_level;
  END IF;

  -- Bekleyen talep kontrolü
  SELECT COUNT(*) INTO v_pending FROM marino_reward_requests
  WHERE player_id = v_player.id AND status = 'pending';
  IF v_pending >= 1 THEN
    RAISE EXCEPTION 'Zaten bekleyen bir talebiniz var. Onay/red bekleyin.';
  END IF;

  -- Günlük limit kontrolü (Günde max 1)
  SELECT COUNT(*) INTO v_daily_used FROM marino_reward_requests
  WHERE player_id = v_player.id AND created_at >= CURRENT_DATE AND status != 'rejected';
  IF v_daily_used >= 1 THEN
    RAISE EXCEPTION 'Günlük ödül talep limitine ulaştınız. (Max 1)';
  END IF;

  -- Haftalık limit kontrolü (Haftada max 3)
  SELECT COUNT(*) INTO v_weekly_used FROM marino_reward_requests
  WHERE player_id = v_player.id AND created_at >= date_trunc('week', CURRENT_DATE) AND status != 'rejected';
  IF v_weekly_used >= 3 THEN
    RAISE EXCEPTION 'Haftalık ödül talep limitine ulaştınız. (Max 3)';
  END IF;

  -- Cooldown kontrolü
  IF EXISTS (
    SELECT 1 FROM marino_reward_requests
    WHERE player_id = v_player.id AND item_code = p_item_code
    AND created_at >= NOW() - (v_item.cooldown_hours || ' hours')::INTERVAL
    AND status != 'rejected'
  ) THEN
    RAISE EXCEPTION 'Bu ödül için cooldown süresi dolmadı (% saat).', v_item.cooldown_hours;
  END IF;

  -- Coin & token kontrolü
  IF v_player.marino_coin < v_item.cost_coin THEN
    RAISE EXCEPTION 'Yetersiz coin. Gerekli: %', v_item.cost_coin;
  END IF;
  IF v_player.reward_token < v_item.cost_token THEN
    RAISE EXCEPTION 'Yetersiz ödül bileti. Gerekli: %', v_item.cost_token;
  END IF;

  -- Coin & token düş, talep oluştur
  UPDATE marino_players SET
    marino_coin = marino_coin - v_item.cost_coin,
    reward_token = reward_token - v_item.cost_token,
    updated_at = NOW()
  WHERE id = v_player.id
  RETURNING * INTO v_player;

  INSERT INTO marino_reward_requests (player_id, telegram_id, item_code, item_name, site_username, display_name, request_id)
  VALUES (v_player.id, p_telegram_id, p_item_code, v_item.item_name, v_player.site_username, v_player.display_name, p_request_id);

  RETURN jsonb_build_object(
    'state', jsonb_build_object(
      'marino_coin', v_player.marino_coin,
      'reward_token', v_player.reward_token,
      'energy', v_player.energy,
      'max_energy', v_player.max_energy,
      'tap_power', v_player.tap_power,
      'passive_income_per_hour', v_player.passive_income_per_hour,
      'casino_level', v_player.casino_level,
      'reputation', v_player.reputation,
      'claimable_coin', v_player.claimable_coin,
      'offline_capacity_hours', v_player.offline_capacity_hours,
      'prestige_points', v_player.prestige_points
    ),
    'reward_status', jsonb_build_object(
      'pending_count', 1,
      'daily_used', v_daily_used + 1,
      'daily_limit', 1,
      'weekly_used', v_weekly_used + 1,
      'weekly_limit', 3,
      'can_request', FALSE
    ),
    'message', v_item.item_name || ' talebi admin paneline gönderildi.'
  );
END;
$$;

-- FUNCTION: start_game(text, text, text, text, text, text)
CREATE FUNCTION public.start_game(p_telegram_id text, p_site_username text DEFAULT ''::text, p_display_name text DEFAULT 'Oyuncu'::text, p_country_code text DEFAULT 'TR'::text, p_country_name text DEFAULT 'Türkiye'::text, p_referred_by text DEFAULT ''::text) RETURNS jsonb
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path = pg_catalog, public
    AS $$
DECLARE
  v_player marino_players%ROWTYPE;
  v_upgrades JSONB;
  v_store JSONB;
  v_reward_status JSONB;
  v_daily JSONB;
BEGIN
  SELECT * INTO v_player FROM marino_players WHERE telegram_id = p_telegram_id;

  IF NOT FOUND THEN
    INSERT INTO marino_players (telegram_id, site_username, display_name, first_name, country_code, country_name, referred_by)
    VALUES (p_telegram_id, p_site_username, p_display_name, p_display_name, p_country_code, p_country_name, p_referred_by)
    RETURNING * INTO v_player;

    INSERT INTO marino_player_buildings (player_id, building_key, level)
    SELECT v_player.id, b.building_key, 0 FROM marino_buildings b ON CONFLICT DO NOTHING;

    INSERT INTO marino_daily_login (player_id, current_streak, last_login_date, total_logins)
    VALUES (v_player.id, 1, CURRENT_DATE, 1);
  ELSE
    UPDATE marino_players SET
      site_username = COALESCE(NULLIF(p_site_username, ''), site_username),
      display_name = COALESCE(NULLIF(p_display_name, ''), display_name),
      updated_at = NOW()
    WHERE id = v_player.id
    RETURNING * INTO v_player;
  END IF;

  IF v_player.is_banned THEN RAISE EXCEPTION 'Hesabınız yasaklanmıştır.'; END IF;

  -- Çevrimdışı ve enerji
  UPDATE marino_players SET
    claimable_coin = LEAST(claimable_coin + FLOOR(passive_income_per_hour * LEAST(offline_capacity_hours, EXTRACT(EPOCH FROM (NOW() - last_income_collect)) / 3600.0)), passive_income_per_hour * offline_capacity_hours),
    energy = LEAST(max_energy, energy + LEAST(FLOOR(EXTRACT(EPOCH FROM (NOW() - last_energy_update)) / 60.0)::INT, max_energy - energy)),
    last_energy_update = CASE WHEN FLOOR(EXTRACT(EPOCH FROM (NOW() - last_energy_update)) / 60.0) > 0 THEN NOW() ELSE last_energy_update END
  WHERE id = v_player.id AND (EXTRACT(EPOCH FROM (NOW() - last_income_collect)) / 3600.0 > 0.016 OR FLOOR(EXTRACT(EPOCH FROM (NOW() - last_energy_update)) / 60.0) > 0)
  RETURNING * INTO v_player;

  SELECT COALESCE(jsonb_agg(row_to_json(t)::jsonb ORDER BY t.sort_order), '[]'::jsonb) INTO v_upgrades
  FROM (SELECT b.building_key, b.building_name, pb.level, FLOOR(b.base_income * POWER(1.12, pb.level) * (1 + v_player.prestige_points * 0.03)) AS current_income_per_hour, FLOOR(b.base_cost * POWER(b.cost_multiplier, pb.level) * (1 + v_player.prestige_points * 0.02)) AS next_cost_coin, b.unlock_level, b.sort_order FROM marino_buildings b JOIN marino_player_buildings pb ON pb.building_key = b.building_key AND pb.player_id = v_player.id) t;

  SELECT COALESCE(jsonb_agg(row_to_json(s)::jsonb ORDER BY s.sort_order), '[]'::jsonb) INTO v_store FROM marino_store_items s WHERE s.is_active = TRUE;

  SELECT jsonb_build_object('pending_count', COALESCE((SELECT COUNT(*) FROM marino_reward_requests WHERE player_id = v_player.id AND status = 'pending'), 0), 'daily_used', COALESCE((SELECT COUNT(*) FROM marino_reward_requests WHERE player_id = v_player.id AND created_at >= CURRENT_DATE AND status != 'rejected'), 0), 'daily_limit', 1, 'can_request', (SELECT COUNT(*) FROM marino_reward_requests WHERE player_id = v_player.id AND status = 'pending') < 1) INTO v_reward_status;
  SELECT COALESCE(row_to_json(dl)::jsonb, '{}'::jsonb) INTO v_daily FROM marino_daily_login dl WHERE dl.player_id = v_player.id;

  RETURN jsonb_build_object('user', jsonb_build_object('telegram_id', v_player.telegram_id, 'display_name', v_player.display_name), 'state', row_to_json(v_player), 'completed_tasks', v_player.completed_tasks, 'upgrades', v_upgrades, 'store', v_store, 'reward_status', v_reward_status, 'daily_login', v_daily);
END;
$$;

-- FUNCTION: tap_coin(text, integer)
CREATE FUNCTION public.tap_coin(p_telegram_id text, p_taps integer DEFAULT 1) RETURNS jsonb
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path = pg_catalog, public
    AS $$
DECLARE
  v_player marino_players%ROWTYPE;
  v_actual_taps INT;
  v_coin_gain BIGINT;
  v_xp_gain BIGINT;
  v_new_level INT;
BEGIN
  SELECT * INTO v_player FROM marino_players WHERE telegram_id = p_telegram_id;
  IF NOT FOUND THEN RAISE EXCEPTION 'Oyuncu bulunamadı.'; END IF;

  -- Enerji rejenerasyonu kontrol
  DECLARE
    v_elapsed_min INT;
    v_regen INT;
  BEGIN
    v_elapsed_min := FLOOR(EXTRACT(EPOCH FROM (NOW() - v_player.last_energy_update)) / 60.0);
    IF v_elapsed_min > 0 AND v_player.energy < v_player.max_energy THEN
      v_regen := LEAST(v_elapsed_min, v_player.max_energy - v_player.energy);
      v_player.energy := LEAST(v_player.max_energy, v_player.energy + v_regen);
    END IF;
  END;

  IF v_player.energy <= 0 THEN
    RAISE EXCEPTION 'Enerji bitti. Biraz bekle.';
  END IF;

  -- Maksimum tap sayısı = enerji
  v_actual_taps := LEAST(GREATEST(p_taps, 1), v_player.energy, 10);

  -- Coin kazancı (prestij bonusu dahil, yüksek seviye yavaşlatma)
  v_coin_gain := v_player.tap_power * v_actual_taps * (1 + v_player.prestige_points * 0.05);
  IF v_player.casino_level > 50 THEN
    v_coin_gain := FLOOR(v_coin_gain * GREATEST(0.5, 1.0 - (v_player.casino_level - 50) * 0.005));
  END IF;

  -- XP kazancı
  v_xp_gain := v_actual_taps * GREATEST(1, v_player.tap_power / 2);

  -- Seviye hesapla (her 100 XP = 1 seviye, üst seviyede yavaşlar)
  v_new_level := GREATEST(1, FLOOR(POWER((v_player.reputation + v_xp_gain) / 50.0, 0.7))::INT);
  v_new_level := GREATEST(v_player.casino_level, v_new_level); -- Seviye düşemez

  UPDATE marino_players SET
    marino_coin = marino_coin + v_coin_gain,
    energy = LEAST(max_energy, v_player.energy - v_actual_taps),
    reputation = reputation + v_xp_gain,
    casino_level = v_new_level,
    last_energy_update = NOW(),
    updated_at = NOW()
  WHERE id = v_player.id
  RETURNING * INTO v_player;

  RETURN jsonb_build_object(
    'state', jsonb_build_object(
      'marino_coin', v_player.marino_coin,
      'reward_token', v_player.reward_token,
      'energy', v_player.energy,
      'max_energy', v_player.max_energy,
      'tap_power', v_player.tap_power,
      'passive_income_per_hour', v_player.passive_income_per_hour,
      'casino_level', v_player.casino_level,
      'reputation', v_player.reputation,
      'claimable_coin', v_player.claimable_coin,
      'offline_capacity_hours', v_player.offline_capacity_hours,
      'prestige_points', v_player.prestige_points
    ),
    'coin_gained', v_coin_gain,
    'xp_gained', v_xp_gain
  );
END;
$$;

-- FUNCTION: upgrade_building(text, text, text)
CREATE FUNCTION public.upgrade_building(p_telegram_id text, p_building_key text, p_request_id text DEFAULT ''::text) RETURNS jsonb
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path = pg_catalog, public
    AS $$
DECLARE
  v_player marino_players%ROWTYPE;
  v_building marino_buildings%ROWTYPE;
  v_pb marino_player_buildings%ROWTYPE;
  v_cost BIGINT;
  v_new_income BIGINT;
  v_total_income BIGINT;
  v_upgrades JSONB;
BEGIN
  -- Çift tıklama koruması
  IF p_request_id != '' THEN
    INSERT INTO marino_processed_requests (request_id) VALUES (p_request_id)
    ON CONFLICT DO NOTHING;
    IF NOT FOUND THEN RAISE EXCEPTION 'Bu işlem zaten işlendi.'; END IF;
  END IF;

  SELECT * INTO v_player FROM marino_players WHERE telegram_id = p_telegram_id;
  IF NOT FOUND THEN RAISE EXCEPTION 'Oyuncu bulunamadı.'; END IF;

  SELECT * INTO v_building FROM marino_buildings WHERE building_key = p_building_key;
  IF NOT FOUND THEN RAISE EXCEPTION 'Bina bulunamadı.'; END IF;

  IF v_player.casino_level < v_building.unlock_level THEN
    RAISE EXCEPTION 'Bu bina için seviye % gerekli.', v_building.unlock_level;
  END IF;

  SELECT * INTO v_pb FROM marino_player_buildings
  WHERE player_id = v_player.id AND building_key = p_building_key;

  v_cost := FLOOR(v_building.base_cost * POWER(v_building.cost_multiplier, v_pb.level) * (1 + v_player.prestige_points * 0.02));

  IF v_player.marino_coin < v_cost THEN
    RAISE EXCEPTION 'Yetersiz coin. Gerekli: %, Mevcut: %', v_cost, v_player.marino_coin;
  END IF;

  -- Bina yükselt
  UPDATE marino_player_buildings SET level = level + 1
  WHERE player_id = v_player.id AND building_key = p_building_key
  RETURNING * INTO v_pb;

  -- Toplam pasif geliri yeniden hesapla
  SELECT COALESCE(SUM(FLOOR(b.base_income * POWER(1.12, pb.level) * (1 + v_player.prestige_points * 0.03))), 0)
  INTO v_total_income
  FROM marino_player_buildings pb
  JOIN marino_buildings b ON b.building_key = pb.building_key
  WHERE pb.player_id = v_player.id AND pb.level > 0;

  -- Oyuncuyu güncelle
  UPDATE marino_players SET
    marino_coin = marino_coin - v_cost,
    passive_income_per_hour = v_total_income,
    reputation = reputation + 5,
    updated_at = NOW()
  WHERE id = v_player.id
  RETURNING * INTO v_player;

  -- Güncel binalar
  SELECT COALESCE(jsonb_agg(row_to_json(t)::jsonb ORDER BY t.sort_order), '[]'::jsonb)
  INTO v_upgrades
  FROM (
    SELECT b.building_key, b.building_name, pb.level,
      FLOOR(b.base_income * POWER(1.12, pb.level) * (1 + v_player.prestige_points * 0.03)) AS current_income_per_hour,
      FLOOR(b.base_cost * POWER(b.cost_multiplier, pb.level) * (1 + v_player.prestige_points * 0.02)) AS next_cost_coin,
      b.unlock_level, b.sort_order
    FROM marino_buildings b
    JOIN marino_player_buildings pb ON pb.building_key = b.building_key AND pb.player_id = v_player.id
  ) t;

  RETURN jsonb_build_object(
    'state', jsonb_build_object(
      'marino_coin', v_player.marino_coin,
      'reward_token', v_player.reward_token,
      'energy', v_player.energy,
      'max_energy', v_player.max_energy,
      'tap_power', v_player.tap_power,
      'passive_income_per_hour', v_player.passive_income_per_hour,
      'casino_level', v_player.casino_level,
      'reputation', v_player.reputation,
      'claimable_coin', v_player.claimable_coin,
      'offline_capacity_hours', v_player.offline_capacity_hours,
      'prestige_points', v_player.prestige_points
    ),
    'upgrades', v_upgrades
  );
END;
$$;


SET default_tablespace = '';

SET default_table_access_method = heap;



-- Baseline objects are server-internal. P0 gateways grant reviewed entry points later.

revoke all on table public.marino_achievements,
  public.marino_ad_reward_logs,
  public.marino_buildings,
  public.marino_daily_cipher,
  public.marino_daily_combo,
  public.marino_daily_login,
  public.marino_player_achievements,
  public.marino_player_boosts,
  public.marino_player_buildings,
  public.marino_player_seasons,
  public.marino_player_tasks,
  public.marino_players,
  public.marino_processed_requests,
  public.marino_reward_requests,
  public.marino_seasons,
  public.marino_sink_purchases,
  public.marino_sports_coupons,
  public.marino_sports_matches,
  public.marino_sports_players,
  public.marino_sports_teams,
  public.marino_store_items,
  public.marino_task_claims,
  public.marino_tasks,
  public.marino_wallets from public, anon, authenticated;

revoke all on sequence public.marino_achievements_id_seq,
  public.marino_buildings_id_seq,
  public.marino_daily_cipher_id_seq,
  public.marino_daily_combo_id_seq,
  public.marino_daily_login_id_seq,
  public.marino_player_achievements_id_seq,
  public.marino_player_buildings_id_seq,
  public.marino_player_seasons_id_seq,
  public.marino_player_tasks_id_seq,
  public.marino_players_id_seq,
  public.marino_reward_requests_id_seq,
  public.marino_seasons_id_seq,
  public.marino_sink_purchases_id_seq,
  public.marino_sports_players_id_seq,
  public.marino_sports_teams_id_seq,
  public.marino_store_items_id_seq,
  public.marino_tasks_id_seq from public, anon, authenticated;

revoke all on function public._marino_ensure_boost(text) from public, anon, authenticated;

revoke all on function public._marino_next_cost(bigint, integer) from public, anon, authenticated;

revoke all on function public._marino_recalc_income(text) from public, anon, authenticated;

revoke all on function public._marino_refresh_energy(text) from public, anon, authenticated;

revoke all on function public._marino_rpc_id(text) from public, anon, authenticated;

revoke all on function public._marino_seed_buildings(text) from public, anon, authenticated;

revoke all on function public._marino_seed_store() from public, anon, authenticated;

revoke all on function public._marino_state(text) from public, anon, authenticated;

revoke all on function public.calc_building_cost(bigint, numeric, integer) from public, anon, authenticated;

revoke all on function public.collect_income(text, text) from public, anon, authenticated;

revoke all on function public.get_game_state(text) from public, anon, authenticated;

revoke all on function public.marino_activate_auto_tap(text) from public, anon, authenticated;

revoke all on function public.marino_admin_get_requests(text) from public, anon, authenticated;

revoke all on function public.marino_admin_get_users(text) from public, anon, authenticated;

revoke all on function public.marino_admin_resolve_request(text, integer, text) from public, anon, authenticated;

revoke all on function public.marino_admin_resolve_request(text, integer, text, text) from public, anon, authenticated;

revoke all on function public.marino_admin_toggle_ban(text, text) from public, anon, authenticated;

revoke all on function public.marino_admin_update_user(text, text, bigint, bigint, integer) from public, anon, authenticated;

revoke all on function public.marino_airdrop_status(text) from public, anon, authenticated;

revoke all on function public.marino_bj_deal(text, bigint) from public, anon, authenticated;

revoke all on function public.marino_bj_hit(text) from public, anon, authenticated;

revoke all on function public.marino_bj_score(jsonb) from public, anon, authenticated;

revoke all on function public.marino_bj_stand(text) from public, anon, authenticated;

revoke all on function public.marino_bootstrap(text) from public, anon, authenticated;

revoke all on function public.marino_building_income(integer, numeric, numeric) from public, anon, authenticated;

revoke all on function public.marino_buy_chips(text, bigint) from public, anon, authenticated;

revoke all on function public.marino_buy_sink(text, text, text) from public, anon, authenticated;

revoke all on function public.marino_check_coupons(text) from public, anon, authenticated;

revoke all on function public.marino_claim_ad_reward(text, text) from public, anon, authenticated;

revoke all on function public.marino_claim_cipher(text, text) from public, anon, authenticated;

revoke all on function public.marino_claim_combo(text, text[]) from public, anon, authenticated;

revoke all on function public.marino_claim_daily_login(text, text) from public, anon, authenticated;

revoke all on function public.marino_claim_referral(text, text, text) from public, anon, authenticated;

revoke all on function public.marino_claim_task(text, text, integer) from public, anon, authenticated;

revoke all on function public.marino_claim_task(text, text, integer, text) from public, anon, authenticated;

revoke all on function public.marino_connect_wallet(text, text) from public, anon, authenticated;

revoke all on function public.marino_generate_matches(integer) from public, anon, authenticated;

revoke all on function public.marino_get_boosts(text) from public, anon, authenticated;

revoke all on function public.marino_get_leaderboard(text, text, integer, integer) from public, anon, authenticated;

revoke all on function public.marino_get_live_matches() from public, anon, authenticated;

revoke all on function public.marino_get_my_notifications(text) from public, anon, authenticated;

revoke all on function public.marino_get_referrals(text) from public, anon, authenticated;

revoke all on function public.marino_get_today_cipher() from public, anon, authenticated;

revoke all on function public.marino_get_today_combo() from public, anon, authenticated;

revoke all on function public.marino_hk_state(text) from public, anon, authenticated;

revoke all on function public.marino_level_from_rep(numeric) from public, anon, authenticated;

revoke all on function public.marino_place_sports_bet(text, uuid, text, bigint) from public, anon, authenticated;

revoke all on function public.marino_play_horse_racing(text, integer, integer) from public, anon, authenticated;

revoke all on function public.marino_play_mini_game(text, text, text) from public, anon, authenticated;

revoke all on function public.marino_play_poker(text, integer) from public, anon, authenticated;

revoke all on function public.marino_play_roulette(text, bigint, text, text) from public, anon, authenticated;

revoke all on function public.marino_play_roulette_v2(text, jsonb, text) from public, anon, authenticated;

revoke all on function public.marino_play_slot(text, bigint, text) from public, anon, authenticated;

revoke all on function public.marino_play_virtual_sports(text, text, bigint, text) from public, anon, authenticated;

revoke all on function public.marino_prestige(text, text) from public, anon, authenticated;

revoke all on function public.marino_random_card() from public, anon, authenticated;

revoke all on function public.marino_recalculate_income(text) from public, anon, authenticated;

revoke all on function public.marino_reward_status(text) from public, anon, authenticated;

revoke all on function public.marino_save_settings(text, text, text, boolean, boolean, text) from public, anon, authenticated;

revoke all on function public.marino_store_json() from public, anon, authenticated;

revoke all on function public.marino_touch_state(text) from public, anon, authenticated;

revoke all on function public.marino_upgrade_capacity(text, text) from public, anon, authenticated;

revoke all on function public.marino_upgrade_energy_limit(text) from public, anon, authenticated;

revoke all on function public.marino_upgrade_multitap(text) from public, anon, authenticated;

revoke all on function public.marino_upgrade_tap(text, text) from public, anon, authenticated;

revoke all on function public.marino_upgrades_json(text) from public, anon, authenticated;

revoke all on function public.marino_use_full_energy(text) from public, anon, authenticated;

revoke all on function public.marino_use_tap_boost(text) from public, anon, authenticated;

revoke all on function public.register_player(text, text, text, text, text, text) from public, anon, authenticated;

revoke all on function public.register_player(text, text, text, text, text, text, text) from public, anon, authenticated;

revoke all on function public.request_reward(text, text, text) from public, anon, authenticated;

revoke all on function public.start_game(text, text, text, text, text, text) from public, anon, authenticated;

revoke all on function public.tap_coin(text, integer) from public, anon, authenticated;

revoke all on function public.upgrade_building(text, text, text) from public, anon, authenticated;



commit;
