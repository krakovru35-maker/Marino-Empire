# Marino Empire — Casino Tap-to-Earn Game (PRD)

## Original Problem Statement
> "Bu oyunu en zirveye taşımamız lazım, ne gerekiyorsa yapalım. Aynı Hamster Kombat gibi olsun (zaten benziyor) ama en ince detayına kadar yapalım. Oyunun konusu casino."

## User Choices
- **Karakter:** Casino oyuncusu (Marino mascot)
- **Özellikler:** Hepsi (tap, mining, upgrade cards, Daily Combo, Daily Cipher, tasks, airdrop, league, referral, boosts)
- **Auth:** Telegram-style (kayıtsız giriş — Telegram WebApp init data)
- **Diller:** Türkçe + İngilizce (anlık toggle)
- **Tasarım:** Özgün modern casino teması

## Architecture
- **Single-page Telegram Mini-App** at `/app/index.html` (~4k lines)
- **Backend:** Supabase (PostgreSQL + PostgREST + RPC) — game state, RPC tap_coin/casino mini-games/HK features
- **Sidecar Backend (this env):** FastAPI at `/app/backend/server.py` (/api/health)
- **Frontend (this env):** `serve` static server in `/app/frontend/` → port 3000
- **Storage:** Server-authoritative (Supabase tables) + localStorage offline fallback

## What's Been Implemented (Jan 2026)

### Hamster-Kombat-Tier Upgrades — SERVER-AUTHORITATIVE
- ✅ **Daily Combo**: 3-of-12 cards puzzle, 6 attempts/day, +5,000,000 coin via `marino_claim_combo` RPC
- ✅ **Daily Cipher**: Morse-code keyboard puzzle (12 words), +1,000,000 coin via `marino_claim_cipher` RPC
- ✅ **Boost Center**: 5 boosts via RPC — `marino_use_full_energy`, `marino_use_tap_boost`, `marino_upgrade_multitap`, `marino_upgrade_energy_limit`, `marino_activate_auto_tap`
- ✅ **Airdrop**: TON wallet placeholder via `marino_connect_wallet`; checklist via `marino_airdrop_status`
- ✅ **State Sync**: `marino_hk_state(p_telegram_id)` bundle RPC on init + 60s refresh
- ✅ **Deterministic Daily Puzzles**: `marino_get_today_combo()` + `marino_get_today_cipher()` (same answer for all players)
- ✅ **Offline Fallback**: If Supabase unreachable, localStorage logic kicks in seamlessly
- ✅ **i18n (TR/EN)**: Live language toggle, ~50 keys, persists in localStorage `m_lang`
- ✅ **Tap Combo Counter**: 10x/20x COMBO popup every 10 rapid taps
- ✅ **Coin Particle Burst**: 4-10 gold particles per tap
- ✅ **Pulse Ring + 5x Tap Boost Badge**: Visual indicators

### Supabase Tables Added (via `/app/supabase_migration.sql`)
- `marino_daily_combo` (player + date + attempts + won + picks)
- `marino_daily_cipher` (player + date + attempts + won)
- `marino_player_boosts` (multitap_lvl, energy_lvl, auto_tap_until, daily counters)
- `marino_wallets` (TON address per player)

### Supabase RPCs Added (13)
- `marino_get_today_combo`, `marino_get_today_cipher`
- `marino_claim_combo`, `marino_claim_cipher`
- `marino_get_boosts`, `marino_use_full_energy`, `marino_use_tap_boost`
- `marino_upgrade_multitap`, `marino_upgrade_energy_limit`, `marino_activate_auto_tap`
- `marino_connect_wallet`, `marino_airdrop_status`, `marino_hk_state`

### Pre-existing (preserved, not modified)
- Tap-to-earn with energy + regen, buildings/upgrades with passive income
- Casino mini-games: Slot, Roulette V2, Blackjack, Poker, Horse Racing, Card Flip, Wheel, Vault
- Live sports betting, tasks, friends + referrals + leaderboard
- 10-tier league, prestige, daily login 8-day cycle, sound/music settings

## Test Results
- 16/16 server RPC tests **PASS** (Python httpx direct calls)
- E2E browser tests: Combo wrong-attempt, Cipher solve, Full Energy boost, Wallet connect — all PASS, all reflected in Supabase
- Game UI: 0 JS errors, 0 UI bugs

## Backlog / Future
- **P1**: Real TonConnect SDK integration (currently generates mock TON addresses)
- **P2**: Daily Combo auto-reveal correct cards on Day End for replay value
- **P2**: Cipher word expansion (currently 12 words; add 50+ with theme rotation)
- **P2**: Auto-tap server-side accumulation (currently client-only timer)
- **P3**: Split `index.html` (~4k lines) into modular JS files

## Files Modified
- `/app/index.html` — added HK CSS + HTML + JS (~1200 lines)
- `/app/supabase_migration.sql` — 4 tables + 13 RPCs (run on Supabase by user)
- `/app/backend/server.py` — minimal FastAPI sidecar
- `/app/backend/requirements.txt`, `/app/backend/.env` (with SUPABASE creds)
- `/app/frontend/package.json`, `/app/frontend/.env`, `/app/frontend/public` (symlink to /app)
