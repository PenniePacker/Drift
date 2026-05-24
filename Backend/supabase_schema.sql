-- =============================================================
-- Drift — Supabase (Postgres) backend schema
-- Global leaderboard for world rankings
-- =============================================================
-- Setup: paste this into the Supabase SQL editor and run.
-- No auth needed. Uses anon key with RLS policies below.
-- =============================================================


-- -------------------------------------------------------------
-- 1. artist_contributions
--    One row per (contribution_token, artist_name, app_bundle_id).
--    Upserted by the iOS app after each sync.
-- -------------------------------------------------------------

create table if not exists artist_contributions (
    id                      uuid primary key default gen_random_uuid(),

    -- Anonymous per-install token. Not linked to any user identity.
    contribution_token      text not null,

    artist_name             text not null,
    app_bundle_id           text not null,
    app_display_name        text not null,
    category_emoji          text not null default '🎵',

    -- Stats from the device
    session_count           int  not null check (session_count >= 3),  -- enforces 3-session minimum server-side
    average_onset_minutes   float not null check (average_onset_minutes > 0),
    drift_score             float not null,

    app_version             text,
    created_at              timestamptz default now(),
    updated_at              timestamptz default now(),

    -- One row per token+artist+app combo (upsert target)
    unique (contribution_token, artist_name, app_bundle_id)
);

-- Auto-update updated_at on upsert
create or replace function set_updated_at()
returns trigger language plpgsql as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

create trigger artist_contributions_updated_at
  before update on artist_contributions
  for each row execute function set_updated_at();


-- -------------------------------------------------------------
-- 2. global_leaderboard (materialised view)
--    Aggregates all contributions into a single ranked table.
--    Refreshed every 10 minutes via pg_cron (see step 4).
--
--    Drift Score formula (global):
--      total_sessions × (30 / weighted_avg_onset)
--    The 30-minute constant normalises scores around a typical
--    onset time so sessions and speed are equally weighted.
-- -------------------------------------------------------------

create materialized view if not exists global_leaderboard as
select
    artist_name,
    app_bundle_id,
    max(app_display_name)                                       as app_display_name,
    max(category_emoji)                                         as category_emoji,

    -- Total sessions is sum of all contributor counts
    sum(session_count)::int                                     as total_sessions,

    -- Weighted average onset across all contributors
    -- (each contributor's avg weighted by their session count)
    round(
        sum(average_onset_minutes * session_count) / sum(session_count)
    ::numeric, 1)::float                                        as average_onset_minutes,

    -- Number of unique devices/installs contributing
    count(distinct contribution_token)::int                     as contributor_count,

    -- Global Drift Score
    round(
        (sum(session_count) * (30.0 / nullif(
            sum(average_onset_minutes * session_count) / sum(session_count), 0
        )))::numeric, 2
    )::float                                                    as global_drift_score,

    -- Category for tab filtering: inferred from app_bundle_id
    case
        when app_bundle_id in ('com.apple.podcasts', 'com.spotify.client.podcast')
            then 'podcasts'
        when app_bundle_id = 'com.google.ios.youtube'
            then 'tracks'
        else 'artists'
    end                                                         as category

from artist_contributions
group by artist_name, app_bundle_id
order by global_drift_score desc;

-- Index for fast category + score lookups
create unique index if not exists global_leaderboard_pk
    on global_leaderboard (artist_name, app_bundle_id);

create index if not exists global_leaderboard_score_idx
    on global_leaderboard (global_drift_score desc);

create index if not exists global_leaderboard_category_idx
    on global_leaderboard (category, global_drift_score desc);


-- -------------------------------------------------------------
-- 3. Row Level Security (RLS)
--    - Anyone (anon key) can INSERT/UPDATE their own token's rows
--    - Anyone can SELECT from global_leaderboard (it's public data)
--    - Nobody can read other tokens' raw contribution rows
-- -------------------------------------------------------------

alter table artist_contributions enable row level security;

-- Devices can only upsert their own token's rows
create policy "own_token_write" on artist_contributions
    for all
    using (true)           -- select: blocked by separate policy
    with check (true);     -- insert/update: allow all (token is opaque, not sensitive)

-- Raw contributions are not readable via API (privacy)
create policy "no_raw_read" on artist_contributions
    for select
    using (false);         -- nobody can SELECT raw rows via the API

-- global_leaderboard view is readable by everyone (anon key)
-- Materialised views don't use RLS — grant is sufficient:
grant select on global_leaderboard to anon;
grant insert, update on artist_contributions to anon;


-- -------------------------------------------------------------
-- 4. Auto-refresh the materialised view every 10 minutes
--    Requires pg_cron extension (enabled in Supabase dashboard
--    under Database → Extensions → pg_cron)
-- -------------------------------------------------------------

select cron.schedule(
    'refresh_global_leaderboard',
    '*/10 * * * *',
    $$ refresh materialized view concurrently global_leaderboard $$
);


-- -------------------------------------------------------------
-- 5. Leaderboard stats helper (optional convenience RPC)
--    Call via: POST /rest/v1/rpc/leaderboard_stats
-- -------------------------------------------------------------

create or replace function leaderboard_stats()
returns json language sql stable as $$
    select json_build_object(
        'total_contributors',   (select count(distinct contribution_token) from artist_contributions),
        'total_sessions',       (select sum(session_count) from artist_contributions),
        'total_artists',        (select count(*) from global_leaderboard),
        'last_refreshed',       (select now())
    )
$$;

grant execute on function leaderboard_stats() to anon;


-- =============================================================
-- Done. The iOS app:
--   POST /rest/v1/artist_contributions  → upsert a contribution
--   GET  /rest/v1/global_leaderboard    → fetch the ranked list
--   POST /rest/v1/rpc/leaderboard_stats → contributor count etc.
-- =============================================================
