begin;

-- These helpers belong to superseded schema generations. Their signatures are
-- retained so unknown legacy callers fail explicitly instead of reaching drifted
-- relations or columns. The reviewed gateways do not call them.
create or replace function public._marino_refresh_energy(p_telegram_id text)
returns void
language plpgsql
security definer
set search_path = pg_catalog, public
as $$
begin
  raise exception 'legacy_function_retired' using errcode = '55000';
end
$$;

create or replace function public._marino_seed_store()
returns void
language plpgsql
security definer
set search_path = pg_catalog, public
as $$
begin
  raise exception 'legacy_function_retired' using errcode = '55000';
end
$$;

create or replace function public._marino_state(p_telegram_id text)
returns jsonb
language plpgsql
security definer
set search_path = pg_catalog, public
as $$
begin
  raise exception 'legacy_function_retired' using errcode = '55000';
end
$$;

create or replace function public.marino_recalculate_income(p_telegram_id text)
returns numeric
language plpgsql
security definer
set search_path = pg_catalog, public
as $$
begin
  raise exception 'legacy_function_retired' using errcode = '55000';
end
$$;

create or replace function public.marino_bootstrap(p_telegram_id text)
returns void
language plpgsql
security definer
set search_path = pg_catalog, public
as $$
begin
  raise exception 'legacy_function_retired' using errcode = '55000';
end
$$;

create or replace function public.sync_leaderboard(p_telegram_id text)
returns void
language plpgsql
security definer
set search_path = pg_catalog, public
as $$
begin
  raise exception 'legacy_function_retired' using errcode = '55000';
end
$$;

create or replace function public._marino_seed_buildings(p_telegram_id text)
returns void
language plpgsql
security definer
set search_path = pg_catalog, public
as $$
begin
  raise exception 'legacy_function_retired' using errcode = '55000';
end
$$;

create or replace function public._marino_recalc_income(p_telegram_id text)
returns void
language plpgsql
security definer
set search_path = pg_catalog, public
as $$
begin
  raise exception 'legacy_function_retired' using errcode = '55000';
end
$$;

create or replace function public.marino_touch_state(p_telegram_id text)
returns jsonb
language plpgsql
security definer
set search_path = pg_catalog, public
as $$
begin
  raise exception 'legacy_function_retired' using errcode = '55000';
end
$$;

create or replace function public.marino_sync_player(p_telegram_id text)
returns void
language plpgsql
security definer
set search_path = pg_catalog, public
as $$
begin
  raise exception 'legacy_function_retired' using errcode = '55000';
end
$$;

-- Stale SQL wrappers discovered during canonical production reconciliation.
create or replace function public.marino_income_per_hour(p_telegram_id text)
returns numeric
language plpgsql
security invoker
set search_path = pg_catalog, public
as $$
begin
  raise exception 'legacy_function_retired' using errcode = '55000';
end
$$;

create or replace function public.marino_state(p_telegram_id text)
returns jsonb
language plpgsql
security invoker
set search_path = pg_catalog, public
as $$
begin
  raise exception 'legacy_function_retired' using errcode = '55000';
end
$$;

create or replace function public.marino_upgrades(p_telegram_id text)
returns jsonb
language plpgsql
security invoker
set search_path = pg_catalog, public
as $$
begin
  raise exception 'legacy_function_retired' using errcode = '55000';
end
$$;

create or replace function public.get_game_state(p_telegram_id text)
returns jsonb
language plpgsql
security invoker
set search_path = pg_catalog, public
as $$
begin
  raise exception 'legacy_function_retired' using errcode = '55000';
end
$$;

create or replace function public.marino_upgrades_json(p_telegram_id text)
returns jsonb
language plpgsql
security invoker
set search_path = pg_catalog, public
as $$
begin
  raise exception 'legacy_function_retired' using errcode = '55000';
end
$$;

-- Preserve the legacy three-argument admin behavior using the canonical review
-- timestamp. The four-argument overload used by marino_admin_rpc is unchanged.
create or replace function public.marino_admin_resolve_request(
  p_admin_id text,
  p_req_id integer,
  p_action text
)
returns text
language plpgsql
security definer
set search_path = pg_catalog, public
as $$
begin
  update public.marino_reward_requests
  set status = p_action,
      reviewed_at = now(),
      is_read = false
  where id = p_req_id
    and status = 'pending';

  return 'Başarılı';
end
$$;

-- marino_play_poker creates pg_temp.tmp_poker_matchups before using it. The
-- legacy static references are valid at runtime but are unresolved by
-- plpgsql_check. Rewrite only those references as dynamic pg_temp SQL while
-- preserving the exact matchup catalogue, RNG, bet and payout body in place.
do $reconcile_poker$
declare
  v_definition text;
  v_start integer;
  v_end_relative integer;
  v_end integer;
  v_block text;
  v_insert text;
  v_replacement text;
begin
  select pg_get_functiondef('public.marino_play_poker(text,integer)'::regprocedure)
  into v_definition;

  if v_definition is null
     or strpos(v_definition, 'CREATE TEMP TABLE IF NOT EXISTS tmp_poker_matchups') = 0
     or strpos(v_definition, 'IF NOT EXISTS (SELECT 1 FROM tmp_poker_matchups) THEN') = 0
     or strpos(v_definition, 'SELECT * INTO v_matrix FROM tmp_poker_matchups WHERE id = v_rnd;') = 0
  then
    raise exception 'marino_play_poker_definition_mismatch';
  end if;

  v_definition := replace(
    v_definition,
    'v_matrix RECORD;',
    'v_matrix RECORD;' || E'\n    v_matchups_empty BOOLEAN;\n    v_matchups_relation TEXT;'
  );
  v_definition := replace(
    v_definition,
    ') ON COMMIT DROP;',
    ') ON COMMIT DROP;' || E'\n    v_matchups_relation := quote_ident(pg_my_temp_schema()::regnamespace::text) || ''.'' || quote_ident(''tmp_poker_matchups'');'
  );
  v_definition := regexp_replace(
    v_definition,
    'BEGIN[[:space:]]+SELECT \* INTO v_user',
    'BEGIN' || E'\n    SELECT NULL::jsonb AS p_hand, NULL::jsonb AS d_hand, NULL::text AS winner, NULL::integer AS payout, NULL::text AS description INTO v_matrix;\n\n    SELECT * INTO v_user'
  );

  v_start := strpos(v_definition, '    IF NOT EXISTS (SELECT 1 FROM tmp_poker_matchups) THEN');
  v_end_relative := strpos(substr(v_definition, v_start), '    END IF;');
  if v_start = 0 or v_end_relative = 0 then
    raise exception 'marino_play_poker_seed_block_mismatch';
  end if;

  v_end := v_start + v_end_relative - 1 + length('    END IF;');
  v_block := substr(v_definition, v_start, v_end - v_start);
  v_insert := substr(
    v_block,
    strpos(v_block, '        INSERT INTO tmp_poker_matchups'),
    length(v_block)
      - strpos(v_block, '        INSERT INTO tmp_poker_matchups')
      - length(E'\n    END IF;')
      + 1
  );
  v_insert := replace(v_insert, 'INSERT INTO tmp_poker_matchups', 'INSERT INTO __MARINO_MATCHUP_TABLE__');

  v_replacement :=
    '    EXECUTE format(''SELECT NOT EXISTS (SELECT 1 FROM %s)'', v_matchups_relation)' ||
    E' INTO v_matchups_empty;\n' ||
    E'    IF v_matchups_empty THEN\n' ||
    '      EXECUTE replace($marino_poker_seed$' || E'\n' ||
    v_insert || E'\n' ||
    '      $marino_poker_seed$, ''__MARINO_MATCHUP_TABLE__'', v_matchups_relation);' || E'\n' ||
    '    END IF;';

  v_definition := overlay(
    v_definition placing v_replacement
    from v_start for (v_end - v_start)
  );
  v_definition := replace(
    v_definition,
    '    SELECT * INTO v_matrix FROM tmp_poker_matchups WHERE id = v_rnd;',
    '    EXECUTE format(''SELECT * FROM %s WHERE id = $1'', v_matchups_relation) INTO v_matrix USING v_rnd;'
  );

  execute v_definition;
end
$reconcile_poker$;

revoke all on function public._marino_refresh_energy(text) from public, anon, authenticated;
revoke all on function public._marino_seed_store() from public, anon, authenticated;
revoke all on function public._marino_state(text) from public, anon, authenticated;
revoke all on function public.marino_recalculate_income(text) from public, anon, authenticated;
revoke all on function public.marino_bootstrap(text) from public, anon, authenticated;
revoke all on function public.sync_leaderboard(text) from public, anon, authenticated;
revoke all on function public.marino_admin_resolve_request(text, integer, text) from public, anon, authenticated;
revoke all on function public._marino_seed_buildings(text) from public, anon, authenticated;
revoke all on function public._marino_recalc_income(text) from public, anon, authenticated;
revoke all on function public.marino_touch_state(text) from public, anon, authenticated;
revoke all on function public.marino_sync_player(text) from public, anon, authenticated;
revoke all on function public.marino_play_poker(text, integer) from public, anon, authenticated;
revoke all on function public.marino_income_per_hour(text) from public, anon, authenticated;
revoke all on function public.marino_state(text) from public, anon, authenticated;
revoke all on function public.marino_upgrades(text) from public, anon, authenticated;
revoke all on function public.get_game_state(text) from public, anon, authenticated;
revoke all on function public.marino_upgrades_json(text) from public, anon, authenticated;

commit;
