-- Marino Empire operations activation pack.
-- Prepared as a migration file only; apply in staging before production.

begin;

insert into public.marino_buildings
  (building_key, building_name, base_cost, base_income, cost_multiplier, unlock_level, sort_order)
values
  ('casino_lobby','Slot Salonu',1200,180,1.18,1,1),
  ('slot_area','Slot Alanı',1400,210,1.18,1,2),
  ('roulette_table','Rulet Masası',2400,260,1.18,2,3),
  ('blackjack_lounge','Blackjack Lounge',4200,390,1.18,4,4),
  ('casino_bar','Casino Bar',3100,310,1.18,3,5),
  ('security_center','Güvenlik Merkezi',5400,460,1.18,6,6),
  ('vip_hall','VIP Salon',7200,620,1.18,7,7),
  ('hotel_floor','Otel Katı',9800,760,1.18,10,8),
  ('marina','Marina',14500,980,1.18,15,9),
  ('private_vault','Özel Kasa',21000,1320,1.18,20,10),
  ('marino_penthouse','Marino Penthouse',32000,1900,1.18,30,11)
on conflict (building_key) do update set
  building_name = excluded.building_name,
  base_cost = excluded.base_cost,
  base_income = excluded.base_income,
  cost_multiplier = excluded.cost_multiplier,
  unlock_level = excluded.unlock_level,
  sort_order = excluded.sort_order;

insert into public.marino_player_buildings (player_id, building_key, level)
select p.id, b.building_key, case when b.building_key in ('casino_lobby','slot_area') then 1 else 0 end
from public.marino_players p
cross join public.marino_buildings b
where b.building_key in (
  'casino_lobby','slot_area','roulette_table','blackjack_lounge','casino_bar','security_center',
  'vip_hall','hotel_floor','marina','private_vault','marino_penthouse'
)
on conflict (player_id, building_key) do nothing;

insert into public.marino_admin_action_policies(action,permission_key,critical) values
  ('rewards_config','rewards.view',false),
  ('casino_config','casino.manage',true),
  ('social_penalties_list','social.view',false),
  ('social_penalty_release','social.moderate',true),
  ('notification_broadcast_prepare','notifications.send',true),
  ('settings_get','settings.manage',false),
  ('settings_set','settings.manage',true)
on conflict(action) do update set permission_key=excluded.permission_key,critical=excluded.critical;

commit;
