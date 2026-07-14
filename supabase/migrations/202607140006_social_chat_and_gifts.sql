-- Secure social chat, anonymous identities, moderation and coin-sink gifts.
-- Forward-only: no existing player data is deleted or rewritten.

begin;

create table public.marino_social_profiles (
  auth_user_id uuid primary key references auth.users(id) on delete cascade,
  social_code text not null unique check (social_code ~ '^[A-F0-9]{3}$'),
  public_alias text not null check (public_alias ~ '^(.\*{3}|Oyuncu) #[A-F0-9]{3}$'),
  notifications_enabled boolean not null default true,
  muted_until timestamptz,
  permanent_chat_ban boolean not null default false,
  spam_strikes smallint not null default 0 check (spam_strikes between 0 and 3),
  last_message_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.marino_chat_messages (
  id uuid primary key default gen_random_uuid(),
  sender_auth_user_id uuid not null references public.marino_social_profiles(auth_user_id) on delete cascade,
  channel_type text not null check (channel_type in ('general','league','private')),
  league_key text check (league_key is null or league_key in ('bronze','silver','gold','platinum','diamond','master','supreme','champion','legend','emperor')),
  recipient_auth_user_id uuid references public.marino_social_profiles(auth_user_id) on delete cascade,
  message_kind text not null default 'text' check (message_kind in ('text','gift','system')),
  filtered_body text not null check (char_length(filtered_body) between 1 and 240),
  normalized_fingerprint text not null check (char_length(normalized_fingerprint) = 64),
  gift_transaction_id uuid unique,
  deleted_at timestamptz,
  removed_by_moderator_at timestamptz,
  created_at timestamptz not null default now(),
  check (
    (channel_type = 'general' and league_key is null and recipient_auth_user_id is null) or
    (channel_type = 'league' and league_key is not null and recipient_auth_user_id is null) or
    (channel_type = 'private' and league_key is null and recipient_auth_user_id is not null)
  ),
  check (sender_auth_user_id is distinct from recipient_auth_user_id)
);

create table public.marino_chat_blocks (
  blocker_auth_user_id uuid not null references public.marino_social_profiles(auth_user_id) on delete cascade,
  blocked_auth_user_id uuid not null references public.marino_social_profiles(auth_user_id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (blocker_auth_user_id, blocked_auth_user_id),
  check (blocker_auth_user_id <> blocked_auth_user_id)
);

create table public.marino_chat_reports (
  id bigint generated always as identity primary key,
  reporter_auth_user_id uuid not null references public.marino_social_profiles(auth_user_id) on delete cascade,
  message_id uuid not null references public.marino_chat_messages(id) on delete cascade,
  reason text not null check (reason in ('contact_info','insult','harassment','spam','fraud','inappropriate','other')),
  status text not null default 'open' check (status in ('open','reviewed','dismissed','actioned')),
  reviewed_by uuid references auth.users(id),
  reviewed_at timestamptz,
  created_at timestamptz not null default now(),
  unique (reporter_auth_user_id, message_id)
);

create table public.marino_friend_requests (
  id uuid primary key default gen_random_uuid(),
  requester_auth_user_id uuid not null references public.marino_social_profiles(auth_user_id) on delete cascade,
  recipient_auth_user_id uuid not null references public.marino_social_profiles(auth_user_id) on delete cascade,
  status text not null default 'pending' check (status in ('pending','accepted','rejected','cancelled')),
  created_at timestamptz not null default now(),
  resolved_at timestamptz,
  check (requester_auth_user_id <> recipient_auth_user_id)
);

create unique index marino_friend_requests_pending_unique
  on public.marino_friend_requests (requester_auth_user_id, recipient_auth_user_id)
  where status = 'pending';

create table public.marino_friendships (
  user_low uuid not null references public.marino_social_profiles(auth_user_id) on delete cascade,
  user_high uuid not null references public.marino_social_profiles(auth_user_id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (user_low, user_high),
  check (user_low < user_high)
);

create table public.marino_gift_catalog (
  gift_key text primary key check (gift_key ~ '^[a-z][a-z0-9_]{1,31}$'),
  display_name text not null check (char_length(display_name) between 1 and 40),
  emoji text not null check (char_length(emoji) between 1 and 12),
  coin_price bigint not null check (coin_price between 1 and 1000000000),
  prestige_points integer not null check (prestige_points between 0 and 10000),
  active boolean not null default true,
  sort_order smallint not null unique,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.marino_gift_transactions (
  id uuid primary key default gen_random_uuid(),
  sender_auth_user_id uuid not null references public.marino_social_profiles(auth_user_id),
  recipient_auth_user_id uuid not null references public.marino_social_profiles(auth_user_id),
  gift_key text not null references public.marino_gift_catalog(gift_key),
  coin_price bigint not null check (coin_price > 0),
  prestige_points integer not null check (prestige_points >= 0),
  request_id uuid not null,
  created_at timestamptz not null default now(),
  unique (sender_auth_user_id, request_id),
  check (sender_auth_user_id <> recipient_auth_user_id)
);

alter table public.marino_chat_messages
  add constraint marino_chat_messages_gift_fk foreign key (gift_transaction_id)
  references public.marino_gift_transactions(id);

create table public.marino_social_stats (
  auth_user_id uuid primary key references public.marino_social_profiles(auth_user_id) on delete cascade,
  gifts_received bigint not null default 0 check (gifts_received >= 0),
  prestige_points bigint not null default 0 check (prestige_points >= 0),
  updated_at timestamptz not null default now()
);

create index marino_chat_messages_general_idx on public.marino_chat_messages (created_at desc, id) where channel_type = 'general' and deleted_at is null and removed_by_moderator_at is null;
create index marino_chat_messages_league_idx on public.marino_chat_messages (league_key, created_at desc, id) where channel_type = 'league' and deleted_at is null and removed_by_moderator_at is null;
create index marino_chat_messages_private_sender_idx on public.marino_chat_messages (sender_auth_user_id, recipient_auth_user_id, created_at desc) where channel_type = 'private' and deleted_at is null and removed_by_moderator_at is null;
create index marino_chat_reports_queue_idx on public.marino_chat_reports (status, created_at);
create index marino_friend_requests_recipient_idx on public.marino_friend_requests (recipient_auth_user_id, status, created_at desc);
create index marino_gift_transactions_sender_day_idx on public.marino_gift_transactions (sender_auth_user_id, created_at desc);
create index marino_gift_transactions_recipient_day_idx on public.marino_gift_transactions (recipient_auth_user_id, created_at desc);

insert into public.marino_gift_catalog(gift_key, display_name, emoji, coin_price, prestige_points, sort_order)
values
  ('water', 'Su', '💧', 1000, 1, 1),
  ('tea', 'Çay', '🫖', 2500, 3, 2),
  ('soda', 'Soda', '🥤', 5000, 5, 3),
  ('coffee', 'Kahve', '☕', 10000, 10, 4),
  ('flower', 'Çiçek', '🌷', 25000, 25, 5),
  ('bouquet', 'Buket', '💐', 100000, 100, 6),
  ('emperor', 'İmparator Hediyesi', '👑', 500000, 500, 7);

do $$
declare v_table text;
begin
  foreach v_table in array array[
    'marino_social_profiles','marino_chat_messages','marino_chat_blocks','marino_chat_reports',
    'marino_friend_requests','marino_friendships','marino_gift_catalog','marino_gift_transactions','marino_social_stats'
  ] loop
    execute format('alter table public.%I enable row level security', v_table);
    execute format('revoke all on table public.%I from public, anon, authenticated', v_table);
  end loop;
end $$;

revoke all on sequence public.marino_chat_reports_id_seq from public, anon, authenticated;

create or replace function public.marino_social_league(p_level integer)
returns text language sql immutable
set search_path = pg_catalog, public
as $$
  select case
    when p_level >= 90 then 'emperor' when p_level >= 80 then 'legend'
    when p_level >= 70 then 'champion' when p_level >= 60 then 'supreme'
    when p_level >= 50 then 'master' when p_level >= 40 then 'diamond'
    when p_level >= 30 then 'platinum' when p_level >= 20 then 'gold'
    when p_level >= 10 then 'silver' else 'bronze' end
$$;

create or replace function public.marino_social_require_user()
returns table(auth_user_id uuid, telegram_id text, player_id bigint, league_key text)
language plpgsql stable security definer
set search_path = pg_catalog, public
as $$
declare v_auth uuid := auth.uid();
begin
  if v_auth is null then raise exception 'authentication_required' using errcode = '42501'; end if;
  return query
    select v_auth, l.telegram_id, p.id, public.marino_social_league(p.casino_level)
    from public.marino_identity_links l
    join public.marino_players p on p.telegram_id = l.telegram_id
    where l.auth_user_id = v_auth
      and l.last_verified_at > now() - interval '24 hours'
      and not p.is_banned;
  if not found then raise exception 'verified_identity_required' using errcode = '42501'; end if;
end $$;

create or replace function public.marino_social_ensure_profile()
returns public.marino_social_profiles
language plpgsql security definer
set search_path = pg_catalog, public
as $$
declare
  v_user record;
  v_profile public.marino_social_profiles;
  v_display text;
  v_initial text;
  v_code text;
  v_identity_created timestamptz;
  v_attempt integer := 0;
begin
  select * into strict v_user from public.marino_social_require_user();
  select * into v_profile from public.marino_social_profiles where auth_user_id = v_user.auth_user_id;
  if found then return v_profile; end if;

  select nullif(btrim(display_name), ''), created_at into v_display, v_identity_created
  from public.marino_identity_links where auth_user_id = v_user.auth_user_id;
  v_initial := case when v_display is null then null else upper(substring(v_display from 1 for 1)) end;

  loop
    v_attempt := v_attempt + 1;
    if v_attempt > 32 then raise exception 'social_code_generation_failed'; end if;
    v_code := upper(substring(encode(gen_random_bytes(2), 'hex') from 1 for 3));
    begin
      insert into public.marino_social_profiles(auth_user_id, social_code, public_alias, created_at)
      values (v_user.auth_user_id, v_code, coalesce(v_initial || '***', 'Oyuncu') || ' #' || v_code, coalesce(v_identity_created, now()))
      returning * into v_profile;
      insert into public.marino_social_stats(auth_user_id) values (v_user.auth_user_id);
      return v_profile;
    exception when unique_violation then
      select * into v_profile from public.marino_social_profiles where auth_user_id = v_user.auth_user_id;
      if found then return v_profile; end if;
    end;
  end loop;
end $$;

create or replace function public.marino_chat_filter(p_text text)
returns text language plpgsql security definer
set search_path = pg_catalog, public
as $$
declare
  v_user record;
  v_text text;
  v_fold text;
  v_token text;
  v_identity record;
  v_digit_words text;
begin
  select * into strict v_user from public.marino_social_require_user();
  if p_text is null or char_length(p_text) > 160 then raise exception 'message_length_invalid'; end if;
  v_text := normalize(p_text, NFKC);
  v_text := regexp_replace(v_text, '[[:cntrl:]]', '', 'g');
  v_text := translate(v_text, U&'\200B\200C\200D\200E\200F\202A\202B\202C\202D\202E\2060\FEFF', '');
  v_text := btrim(regexp_replace(v_text, '[[:space:]]+', ' ', 'g'));
  if v_text = '' or v_text !~ '[[:alnum:]]' then raise exception 'message_content_required'; end if;

  v_fold := lower(translate(v_text, 'IİŞĞÜÖÇ', 'ıişğüöç'));
  if v_fold ~ '(https?://|www\.|t\.me|telegram|whatsapp|instagram|discord|snapchat|facebook|twitter|(^|[^[:alnum:]])x[[:space:]]*[:@]|(^|[^[:alnum:]])(wp|tg|dc|insta)[[:space:]]*[:@])' then
    v_text := '[iletişim bilgisi gizlendi]';
  elsif v_fold ~ '(^|[^[:alnum:]_.-])[[:alnum:]_.+-]+@[[:alnum:]-]+(\.[[:alnum:]-]+)+' then
    v_text := '[iletişim bilgisi gizlendi]';
  elsif v_fold ~ '(^|[^[:alnum:]])@[[:alnum:]_]{3,32}' then
    v_text := '[iletişim bilgisi gizlendi]';
  elsif regexp_replace(translate(v_fold, 'oıl', '011'), '[^0-9]', '', 'g') ~ '[0-9]{7,}' then
    v_text := '[iletişim bilgisi gizlendi]';
  elsif upper(regexp_replace(v_fold, '[^[:alnum:]]', '', 'g')) ~ '[A-Z]{2}[0-9]{2}[A-Z0-9]{10,30}' then
    v_text := '[iletişim bilgisi gizlendi]';
  end if;

  v_digit_words := regexp_replace(v_fold, '[^[:alpha:]]', '', 'g');
  if v_digit_words ~ '(sıfır|bir|iki|üç|dört|beş|altı|yedi|sekiz|dokuz).*(sıfır|bir|iki|üç|dört|beş|altı|yedi|sekiz|dokuz).*(sıfır|bir|iki|üç|dört|beş|altı|yedi|sekiz|dokuz).*(sıfır|bir|iki|üç|dört|beş|altı|yedi|sekiz|dokuz).*(sıfır|bir|iki|üç|dört|beş|altı|yedi|sekiz|dokuz)' then
    v_text := '[iletişim bilgisi gizlendi]';
  end if;

  select display_name, telegram_username into v_identity
  from public.marino_identity_links where auth_user_id = v_user.auth_user_id;
  for v_token in
    select lower(word) from regexp_split_to_table(coalesce(v_identity.display_name, ''), '[^[:alpha:]]+') word where char_length(word) >= 3
    union
    select lower(coalesce(v_identity.telegram_username, '')) where char_length(coalesce(v_identity.telegram_username, '')) >= 3
  loop
    v_text := regexp_replace(v_text, '(^|[^[:alnum:]])' || regexp_replace(v_token, '([\[\]().*+?^$|{}\\-])', '\\\1', 'g') || '([^[:alnum:]]|$)', '\1****\2', 'gi');
  end loop;

  if char_length(v_text) > 160 then v_text := substring(v_text from 1 for 160); end if;
  return v_text;
end $$;

create or replace function public.marino_social_are_friends(p_a uuid, p_b uuid)
returns boolean language sql stable security definer
set search_path = pg_catalog, public
as $$ select exists(select 1 from public.marino_friendships where user_low = least(p_a,p_b) and user_high = greatest(p_a,p_b)) $$;

create or replace function public.marino_social_is_blocked(p_a uuid, p_b uuid)
returns boolean language sql stable security definer
set search_path = pg_catalog, public
as $$ select exists(select 1 from public.marino_chat_blocks where (blocker_auth_user_id=p_a and blocked_auth_user_id=p_b) or (blocker_auth_user_id=p_b and blocked_auth_user_id=p_a)) $$;

create or replace function public.marino_chat_send(p_channel text, p_body text, p_recipient_code text default null)
returns jsonb language plpgsql security definer
set search_path = pg_catalog, public
as $$
declare
  v_user record; v_profile public.marino_social_profiles; v_recipient uuid; v_filtered text; v_fingerprint text;
  v_minute integer; v_hour integer; v_strikes integer; v_mute interval; v_message public.marino_chat_messages;
begin
  select * into strict v_user from public.marino_social_require_user();
  v_profile := public.marino_social_ensure_profile();
  select * into v_profile from public.marino_social_profiles where auth_user_id=v_user.auth_user_id for update;
  if v_profile.permanent_chat_ban then raise exception 'chat_banned' using errcode='42501'; end if;
  if v_profile.muted_until > now() then raise exception 'chat_muted_until:%', v_profile.muted_until using errcode='42501'; end if;
  if v_profile.created_at > now() - interval '10 minutes' then raise exception 'new_account_read_only' using errcode='42501'; end if;
  if p_channel not in ('general','league','private') then raise exception 'invalid_channel'; end if;
  if p_channel='private' then
    if p_recipient_code !~ '^[A-F0-9]{3}$' then raise exception 'recipient_required'; end if;
    select auth_user_id into v_recipient from public.marino_social_profiles where social_code=p_recipient_code;
    if v_recipient is null or not public.marino_social_are_friends(v_user.auth_user_id,v_recipient) or public.marino_social_is_blocked(v_user.auth_user_id,v_recipient) then raise exception 'private_recipient_not_allowed' using errcode='42501'; end if;
  elsif p_recipient_code is not null then raise exception 'recipient_not_allowed'; end if;

  v_filtered := public.marino_chat_filter(p_body);
  v_fingerprint := encode(digest(lower(v_filtered),'sha256'),'hex');
  select count(*) filter(where created_at >= now()-interval '1 minute'), count(*) filter(where created_at >= now()-interval '1 hour')
    into v_minute,v_hour from public.marino_chat_messages where sender_auth_user_id=v_user.auth_user_id;
  if v_profile.last_message_at > now()-interval '2 seconds' or v_minute >= 20 or v_hour >= 200 or
    (select normalized_fingerprint=v_fingerprint from public.marino_chat_messages where sender_auth_user_id=v_user.auth_user_id order by created_at desc limit 1) is true then
    v_strikes := least(3, case when v_profile.updated_at < now()-interval '24 hours' then 1 else v_profile.spam_strikes+1 end);
    v_mute := case v_strikes when 1 then interval '10 minutes' when 2 then interval '1 hour' else interval '24 hours' end;
    update public.marino_social_profiles set spam_strikes=v_strikes, muted_until=now()+v_mute, updated_at=now() where auth_user_id=v_user.auth_user_id;
    return jsonb_build_object('ok',false,'error','rate_limited','retry_after_seconds',extract(epoch from v_mute)::integer);
  end if;

  insert into public.marino_chat_messages(sender_auth_user_id,channel_type,league_key,recipient_auth_user_id,filtered_body,normalized_fingerprint)
  values(v_user.auth_user_id,p_channel,case when p_channel='league' then v_user.league_key end,v_recipient,v_filtered,v_fingerprint)
  returning * into v_message;
  update public.marino_social_profiles set last_message_at=now(),updated_at=now() where auth_user_id=v_user.auth_user_id;
  return jsonb_build_object('ok',true,'message_id',v_message.id,'alias',v_profile.public_alias,'body',v_filtered,'channel',p_channel,'created_at',v_message.created_at);
end $$;

create or replace function public.marino_gift_send(p_recipient_code text, p_gift_key text, p_request_id uuid)
returns jsonb language plpgsql security definer
set search_path = pg_catalog, public
as $$
declare
  v_user record; v_sender public.marino_social_profiles; v_recipient public.marino_social_profiles; v_gift public.marino_gift_catalog;
  v_player public.marino_players; v_tx public.marino_gift_transactions; v_day_total integer; v_pair_total integer; v_body text;
begin
  if p_request_id is null then raise exception 'request_id_required'; end if;
  select * into strict v_user from public.marino_social_require_user();
  v_sender := public.marino_social_ensure_profile();
  select * into v_recipient from public.marino_social_profiles where social_code=p_recipient_code;
  if v_recipient.auth_user_id is null or v_recipient.auth_user_id=v_user.auth_user_id then raise exception 'invalid_recipient'; end if;
  if public.marino_social_is_blocked(v_user.auth_user_id,v_recipient.auth_user_id) then raise exception 'recipient_blocked' using errcode='42501'; end if;
  select * into v_gift from public.marino_gift_catalog where gift_key=p_gift_key and active;
  if v_gift.gift_key is null then raise exception 'gift_not_available'; end if;
  select * into v_tx from public.marino_gift_transactions where sender_auth_user_id=v_user.auth_user_id and request_id=p_request_id;
  if found then return jsonb_build_object('ok',true,'idempotent',true,'transaction_id',v_tx.id); end if;
  select count(*),count(*) filter(where recipient_auth_user_id=v_recipient.auth_user_id) into v_day_total,v_pair_total
  from public.marino_gift_transactions where sender_auth_user_id=v_user.auth_user_id and created_at >= date_trunc('day',now());
  if v_day_total >= 10 then raise exception 'daily_gift_limit'; end if;
  if v_pair_total >= 3 then raise exception 'recipient_daily_gift_limit'; end if;
  select * into strict v_player from public.marino_players where id=v_user.player_id for update;
  if coalesce(v_player.marino_coin,0) < v_gift.coin_price then raise exception 'insufficient_coin'; end if;
  update public.marino_players set marino_coin=marino_coin-v_gift.coin_price,updated_at=now() where id=v_player.id;
  insert into public.marino_gift_transactions(sender_auth_user_id,recipient_auth_user_id,gift_key,coin_price,prestige_points,request_id)
  values(v_user.auth_user_id,v_recipient.auth_user_id,v_gift.gift_key,v_gift.coin_price,v_gift.prestige_points,p_request_id) returning * into v_tx;
  insert into public.marino_social_stats(auth_user_id,gifts_received,prestige_points) values(v_recipient.auth_user_id,1,v_gift.prestige_points)
  on conflict(auth_user_id) do update set gifts_received=public.marino_social_stats.gifts_received+1,prestige_points=public.marino_social_stats.prestige_points+excluded.prestige_points,updated_at=now();
  v_body := v_sender.public_alias || ', ' || v_recipient.public_alias || ' oyuncusuna ' || lower(v_gift.display_name) || ' gönderdi ' || v_gift.emoji;
  insert into public.marino_chat_messages(sender_auth_user_id,channel_type,message_kind,filtered_body,normalized_fingerprint,gift_transaction_id)
  values(v_user.auth_user_id,'general','gift',v_body,encode(digest(v_tx.id::text,'sha256'),'hex'),v_tx.id);
  return jsonb_build_object('ok',true,'idempotent',false,'transaction_id',v_tx.id,'coin_spent',v_gift.coin_price,'coin_balance',v_player.marino_coin-v_gift.coin_price);
exception when unique_violation then
  select * into v_tx from public.marino_gift_transactions where sender_auth_user_id=v_user.auth_user_id and request_id=p_request_id;
  if found then return jsonb_build_object('ok',true,'idempotent',true,'transaction_id',v_tx.id); end if;
  raise;
end $$;

create or replace function public.marino_social_rpc(p_action text, p_payload jsonb default '{}'::jsonb, p_request_id uuid default null)
returns jsonb language plpgsql security definer
set search_path = pg_catalog, public
as $$
declare
  v_user record; v_profile public.marino_social_profiles; v_target uuid; v_request public.marino_friend_requests; v_limit integer;
  v_cursor timestamptz; v_result jsonb; v_message uuid; v_reason text;
begin
  if p_payload is null or jsonb_typeof(p_payload)<>'object' or pg_column_size(p_payload)>4096 then raise exception 'invalid_payload'; end if;
  if p_payload ?| array['telegram_id','p_telegram_id','auth_user_id','player_id','coin_price'] then raise exception 'caller_identity_or_price_not_allowed' using errcode='42501'; end if;
  select * into strict v_user from public.marino_social_require_user();
  v_profile := public.marino_social_ensure_profile();

  case p_action
    when 'bootstrap' then
      select jsonb_build_object('alias',v_profile.public_alias,'social_code',v_profile.social_code,'league',v_user.league_key,
        'notifications_enabled',v_profile.notifications_enabled,'read_only_until',v_profile.created_at+interval '10 minutes',
        'muted_until',v_profile.muted_until,'chat_banned',v_profile.permanent_chat_ban,
        'pending_requests',(select count(*) from public.marino_friend_requests where recipient_auth_user_id=v_user.auth_user_id and status='pending')) into v_result;
    when 'history' then
      v_limit:=least(100,greatest(1,coalesce((p_payload->>'limit')::integer,50)));
      v_cursor:=coalesce((p_payload->>'before')::timestamptz,now()+interval '1 second');
      if p_payload->>'channel' not in ('general','league','private') then raise exception 'invalid_channel'; end if;
      if p_payload->>'channel'='private' then select auth_user_id into v_target from public.marino_social_profiles where social_code=p_payload->>'recipient_code'; end if;
      select coalesce(jsonb_agg(x.payload order by x.created_at),'[]'::jsonb) into v_result from (
        select m.created_at,jsonb_build_object('id',m.id,'alias',sp.public_alias,'social_code',sp.social_code,'body',m.filtered_body,'kind',m.message_kind,'created_at',m.created_at,'own',m.sender_auth_user_id=v_user.auth_user_id) payload
        from public.marino_chat_messages m join public.marino_social_profiles sp on sp.auth_user_id=m.sender_auth_user_id
        where m.deleted_at is null and m.removed_by_moderator_at is null and m.created_at<v_cursor
          and not public.marino_social_is_blocked(v_user.auth_user_id,m.sender_auth_user_id)
          and ((p_payload->>'channel'='general' and m.channel_type='general')
            or (p_payload->>'channel'='league' and m.channel_type='league' and m.league_key=v_user.league_key)
            or (p_payload->>'channel'='private' and m.channel_type='private' and v_target is not null and ((m.sender_auth_user_id=v_user.auth_user_id and m.recipient_auth_user_id=v_target) or (m.sender_auth_user_id=v_target and m.recipient_auth_user_id=v_user.auth_user_id))))
        order by m.created_at desc limit v_limit
      ) x;
    when 'send' then v_result:=public.marino_chat_send(p_payload->>'channel',p_payload->>'body',p_payload->>'recipient_code');
    when 'delete_own' then
      v_message:=(p_payload->>'message_id')::uuid;
      update public.marino_chat_messages set deleted_at=now() where id=v_message and sender_auth_user_id=v_user.auth_user_id and deleted_at is null returning jsonb_build_object('ok',true) into v_result;
      if v_result is null then raise exception 'message_not_found' using errcode='42501'; end if;
    when 'block' then
      select auth_user_id into v_target from public.marino_social_profiles where social_code=p_payload->>'social_code';
      if v_target is null or v_target=v_user.auth_user_id then raise exception 'invalid_target'; end if;
      insert into public.marino_chat_blocks values(v_user.auth_user_id,v_target,now()) on conflict do nothing;
      delete from public.marino_friendships where user_low=least(v_user.auth_user_id,v_target) and user_high=greatest(v_user.auth_user_id,v_target);
      v_result:=jsonb_build_object('ok',true);
    when 'unblock' then
      select auth_user_id into v_target from public.marino_social_profiles where social_code=p_payload->>'social_code';
      delete from public.marino_chat_blocks where blocker_auth_user_id=v_user.auth_user_id and blocked_auth_user_id=v_target;
      v_result:=jsonb_build_object('ok',true);
    when 'report' then
      v_message:=(p_payload->>'message_id')::uuid; v_reason:=p_payload->>'reason';
      if v_reason not in ('contact_info','insult','harassment','spam','fraud','inappropriate','other') then raise exception 'invalid_reason'; end if;
      insert into public.marino_chat_reports(reporter_auth_user_id,message_id,reason)
      select v_user.auth_user_id,m.id,v_reason from public.marino_chat_messages m where m.id=v_message and m.sender_auth_user_id<>v_user.auth_user_id and m.deleted_at is null
      on conflict(reporter_auth_user_id,message_id) do nothing;
      if not found then raise exception 'report_not_allowed'; end if;
      v_result:=jsonb_build_object('ok',true);
    when 'friend_request' then
      select auth_user_id into v_target from public.marino_social_profiles where social_code=p_payload->>'social_code';
      if v_target is null or v_target=v_user.auth_user_id or public.marino_social_is_blocked(v_user.auth_user_id,v_target) then raise exception 'friend_request_not_allowed'; end if;
      if public.marino_social_are_friends(v_user.auth_user_id,v_target) then raise exception 'already_friends'; end if;
      insert into public.marino_friend_requests(requester_auth_user_id,recipient_auth_user_id) values(v_user.auth_user_id,v_target) returning * into v_request;
      v_result:=jsonb_build_object('ok',true,'request_id',v_request.id);
    when 'friend_accept','friend_reject' then
      select * into v_request from public.marino_friend_requests where id=(p_payload->>'request_id')::uuid and recipient_auth_user_id=v_user.auth_user_id and status='pending' for update;
      if v_request.id is null or public.marino_social_is_blocked(v_user.auth_user_id,v_request.requester_auth_user_id) then raise exception 'friend_request_not_found'; end if;
      update public.marino_friend_requests set status=case when p_action='friend_accept' then 'accepted' else 'rejected' end,resolved_at=now() where id=v_request.id;
      if p_action='friend_accept' then insert into public.marino_friendships values(least(v_user.auth_user_id,v_request.requester_auth_user_id),greatest(v_user.auth_user_id,v_request.requester_auth_user_id),now()) on conflict do nothing; end if;
      v_result:=jsonb_build_object('ok',true);
    when 'friend_remove' then
      select auth_user_id into v_target from public.marino_social_profiles where social_code=p_payload->>'social_code';
      delete from public.marino_friendships where user_low=least(v_user.auth_user_id,v_target) and user_high=greatest(v_user.auth_user_id,v_target);
      v_result:=jsonb_build_object('ok',true);
    when 'friends' then
      select jsonb_build_object(
        'friends',coalesce((select jsonb_agg(jsonb_build_object('alias',sp.public_alias,'social_code',sp.social_code)) from public.marino_friendships f join public.marino_social_profiles sp on sp.auth_user_id=case when f.user_low=v_user.auth_user_id then f.user_high else f.user_low end where f.user_low=v_user.auth_user_id or f.user_high=v_user.auth_user_id),'[]'::jsonb),
        'requests',coalesce((select jsonb_agg(jsonb_build_object('request_id',r.id,'alias',sp.public_alias,'social_code',sp.social_code,'created_at',r.created_at)) from public.marino_friend_requests r join public.marino_social_profiles sp on sp.auth_user_id=r.requester_auth_user_id where r.recipient_auth_user_id=v_user.auth_user_id and r.status='pending'),'[]'::jsonb)
      ) into v_result;
    when 'gift_catalog' then
      select jsonb_build_object('items',coalesce(jsonb_agg(jsonb_build_object('key',gift_key,'name',display_name,'emoji',emoji,'price',coin_price,'prestige',prestige_points) order by sort_order),'[]'::jsonb),
        'sent_today',(select count(*) from public.marino_gift_transactions where sender_auth_user_id=v_user.auth_user_id and created_at>=date_trunc('day',now())),'daily_limit',10) into v_result from public.marino_gift_catalog where active;
    when 'gift_send' then v_result:=public.marino_gift_send(p_payload->>'recipient_code',p_payload->>'gift_key',p_request_id);
    when 'gift_inventory' then
      select jsonb_build_object('gifts_received',s.gifts_received,'prestige_points',s.prestige_points,'received_today',(select count(*) from public.marino_gift_transactions where recipient_auth_user_id=v_user.auth_user_id and created_at>=date_trunc('day',now())),
        'collection',coalesce((select jsonb_agg(jsonb_build_object('key',g.gift_key,'name',c.display_name,'emoji',c.emoji,'count',g.amount)) from (select gift_key,count(*) amount from public.marino_gift_transactions where recipient_auth_user_id=v_user.auth_user_id group by gift_key) g join public.marino_gift_catalog c using(gift_key)),'[]'::jsonb)) into v_result from public.marino_social_stats s where s.auth_user_id=v_user.auth_user_id;
    when 'notifications' then
      select jsonb_build_object('friend_requests',(select count(*) from public.marino_friend_requests where recipient_auth_user_id=v_user.auth_user_id and status='pending'),'gifts_today',(select count(*) from public.marino_gift_transactions where recipient_auth_user_id=v_user.auth_user_id and created_at>=date_trunc('day',now())),'muted_until',v_profile.muted_until) into v_result;
    when 'set_notifications' then
      if jsonb_typeof(p_payload->'enabled')<>'boolean' then raise exception 'invalid_enabled'; end if;
      update public.marino_social_profiles set notifications_enabled=(p_payload->>'enabled')::boolean,updated_at=now() where auth_user_id=v_user.auth_user_id;
      v_result:=jsonb_build_object('ok',true);
    else raise exception 'social_action_not_allowed' using errcode='42501';
  end case;
  return v_result;
exception when invalid_text_representation or numeric_value_out_of_range or datetime_field_overflow then
  raise exception 'invalid_payload_value';
end $$;

create or replace function public.marino_social_admin_rpc(p_action text,p_payload jsonb default '{}'::jsonb,p_request_id uuid default gen_random_uuid())
returns jsonb language plpgsql security definer
set search_path = pg_catalog, public
as $$
declare v_user uuid:=auth.uid(); v_role text; v_target uuid; v_result jsonb; v_seconds integer;
begin
  select role into v_role from public.marino_admin_roles where auth_user_id=v_user and active and (expires_at is null or expires_at>now());
  if v_role not in ('operator','security_admin') then raise exception 'admin_role_required' using errcode='42501'; end if;
  if p_request_id is null or p_payload ?| array['admin_id','auth_user_id','telegram_id'] then raise exception 'invalid_admin_request'; end if;
  insert into public.marino_admin_audit_log(auth_user_id,action,target_id,request_id,payload)
  values(v_user,'social_'||p_action,p_payload->>'social_code',p_request_id,p_payload-array['note']) on conflict do nothing;
  if not found then raise exception 'duplicate_admin_request'; end if;
  if p_action='queue' then
    select coalesce(jsonb_agg(x),'[]'::jsonb) into v_result from (select r.id report_id,r.reason,r.created_at,m.id message_id,m.filtered_body,m.channel_type,sp.public_alias,sp.social_code,(select count(*) from public.marino_chat_reports r2 where r2.message_id=m.id and r2.status='open') report_count from public.marino_chat_reports r join public.marino_chat_messages m on m.id=r.message_id join public.marino_social_profiles sp on sp.auth_user_id=m.sender_auth_user_id where r.status='open' order by r.created_at limit 100) x;
  elsif p_action in ('mute','permanent_mute','game_ban') then
    select auth_user_id into v_target from public.marino_social_profiles where social_code=p_payload->>'social_code'; if v_target is null then raise exception 'target_not_found'; end if;
    if p_action='mute' then v_seconds:=least(86400,greatest(600,(p_payload->>'seconds')::integer)); update public.marino_social_profiles set muted_until=now()+make_interval(secs=>v_seconds),updated_at=now() where auth_user_id=v_target;
    elsif p_action='permanent_mute' then if v_role<>'security_admin' then raise exception 'security_admin_required'; end if; update public.marino_social_profiles set permanent_chat_ban=true,updated_at=now() where auth_user_id=v_target;
    else if v_role<>'security_admin' then raise exception 'security_admin_required'; end if; update public.marino_players p set is_banned=true,updated_at=now() from public.marino_identity_links l where l.auth_user_id=v_target and p.telegram_id=l.telegram_id; end if;
    v_result:=jsonb_build_object('ok',true);
  elsif p_action='remove_message' then
    update public.marino_chat_messages set removed_by_moderator_at=now() where id=(p_payload->>'message_id')::uuid and removed_by_moderator_at is null;
    update public.marino_chat_reports set status='actioned',reviewed_by=v_user,reviewed_at=now() where message_id=(p_payload->>'message_id')::uuid and status='open'; v_result:=jsonb_build_object('ok',true);
  elsif p_action='resolve_report' then
    if p_payload->>'status' not in ('reviewed','dismissed') then raise exception 'invalid_status'; end if;
    update public.marino_chat_reports set status=p_payload->>'status',reviewed_by=v_user,reviewed_at=now() where id=(p_payload->>'report_id')::bigint and status='open'; v_result:=jsonb_build_object('ok',true);
  else raise exception 'social_admin_action_not_allowed' using errcode='42501'; end if;
  return v_result;
end $$;

do $$
declare r record;
begin
  for r in select p.oid::regprocedure signature from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and p.proname in ('marino_social_league','marino_social_require_user','marino_social_ensure_profile','marino_chat_filter','marino_social_are_friends','marino_social_is_blocked','marino_chat_send','marino_gift_send','marino_social_rpc','marino_social_admin_rpc') loop
    execute format('revoke all on function %s from public, anon, authenticated',r.signature);
  end loop;
end $$;

grant execute on function public.marino_social_rpc(text,jsonb,uuid) to authenticated;
grant execute on function public.marino_social_admin_rpc(text,jsonb,uuid) to authenticated;

commit;
