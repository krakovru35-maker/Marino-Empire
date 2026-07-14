-- Marino Empire P0 gameplay hardening: server-side tap throttling.
-- Prepared only as a migration file; do not run against production until staging passes.

begin;

create table if not exists public.marino_tap_rate_limits (
  telegram_id text primary key,
  window_started_at timestamptz not null default now(),
  taps_in_window integer not null default 0 check (taps_in_window >= 0 and taps_in_window <= 120),
  blocked_until timestamptz,
  last_request_at timestamptz,
  violation_count integer not null default 0 check (violation_count >= 0 and violation_count <= 1000000),
  updated_at timestamptz not null default now(),
  check (blocked_until is null or blocked_until >= window_started_at)
);

alter table public.marino_tap_rate_limits enable row level security;

revoke all on table public.marino_tap_rate_limits from public;
revoke all on table public.marino_tap_rate_limits from anon;
revoke all on table public.marino_tap_rate_limits from authenticated;

create or replace function public.tap_coin(p_telegram_id text, p_taps integer default 1) returns jsonb
  language plpgsql
  security definer
  set search_path = pg_catalog, public
as $$
declare
  v_player public.marino_players%rowtype;
  v_actual_taps integer;
  v_coin_gain bigint;
  v_xp_gain bigint;
  v_new_level integer;
  v_now timestamptz := now();
  v_window_started_at timestamptz;
  v_taps_in_window integer;
  v_blocked_until timestamptz;
  v_violation_count integer;
  v_window_seconds integer := 10;
  v_max_window_taps integer := 80;
  v_max_batch_taps integer := 10;
  v_block_seconds integer := 6;
begin
  if p_telegram_id is null or p_telegram_id !~ '^[0-9]{3,32}$' then
    raise exception 'invalid_identity';
  end if;

  if p_taps is null or p_taps < 1 or p_taps > v_max_batch_taps then
    raise exception 'invalid_tap_count';
  end if;

  insert into public.marino_tap_rate_limits (telegram_id, window_started_at, taps_in_window, last_request_at, updated_at)
  values (p_telegram_id, v_now, 0, v_now, v_now)
  on conflict (telegram_id) do nothing;

  select window_started_at, taps_in_window, blocked_until, violation_count
    into v_window_started_at, v_taps_in_window, v_blocked_until, v_violation_count
  from public.marino_tap_rate_limits
  where telegram_id = p_telegram_id
  for update;

  if v_blocked_until is not null and v_blocked_until > v_now then
    raise exception 'tap_rate_limited' using errcode = 'P0001';
  end if;

  if v_window_started_at < v_now - make_interval(secs => v_window_seconds) then
    v_window_started_at := v_now;
    v_taps_in_window := 0;
    v_blocked_until := null;
  end if;

  if v_taps_in_window + p_taps > v_max_window_taps then
    update public.marino_tap_rate_limits
       set blocked_until = v_now + make_interval(secs => v_block_seconds),
           violation_count = least(coalesce(v_violation_count, 0) + 1, 1000000),
           last_request_at = v_now,
           updated_at = v_now
     where telegram_id = p_telegram_id;
    raise exception 'tap_rate_limited' using errcode = 'P0001';
  end if;

  update public.marino_tap_rate_limits
     set window_started_at = v_window_started_at,
         taps_in_window = v_taps_in_window + p_taps,
         blocked_until = v_blocked_until,
         last_request_at = v_now,
         updated_at = v_now
   where telegram_id = p_telegram_id;

  select * into v_player
  from public.marino_players
  where telegram_id = p_telegram_id
  for update;

  if not found then
    raise exception 'Oyuncu bulunamadi.';
  end if;

  declare
    v_elapsed_min integer;
    v_regen integer;
  begin
    v_elapsed_min := floor(extract(epoch from (v_now - v_player.last_energy_update)) / 60.0);
    if v_elapsed_min > 0 and v_player.energy < v_player.max_energy then
      v_regen := least(v_elapsed_min, v_player.max_energy - v_player.energy);
      v_player.energy := least(v_player.max_energy, v_player.energy + v_regen);
    end if;
  end;

  if v_player.energy <= 0 then
    raise exception 'Enerji bitti. Biraz bekle.';
  end if;

  v_actual_taps := least(greatest(p_taps, 1), v_player.energy, v_max_batch_taps);

  v_coin_gain := v_player.tap_power * v_actual_taps * (1 + v_player.prestige_points * 0.05);
  if v_player.casino_level > 50 then
    v_coin_gain := floor(v_coin_gain * greatest(0.5, 1.0 - (v_player.casino_level - 50) * 0.005));
  end if;

  v_xp_gain := v_actual_taps * greatest(1, v_player.tap_power / 2);

  v_new_level := greatest(1, floor(power((v_player.reputation + v_xp_gain) / 50.0, 0.7))::integer);
  v_new_level := greatest(v_player.casino_level, v_new_level);

  update public.marino_players set
    marino_coin = marino_coin + v_coin_gain,
    energy = least(max_energy, v_player.energy - v_actual_taps),
    reputation = reputation + v_xp_gain,
    casino_level = v_new_level,
    last_energy_update = v_now,
    updated_at = v_now
  where id = v_player.id
  returning * into v_player;

  return jsonb_build_object(
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
end;
$$;

revoke all on function public.tap_coin(text, integer) from public;
revoke all on function public.tap_coin(text, integer) from anon;
revoke all on function public.tap_coin(text, integer) from authenticated;

commit;
