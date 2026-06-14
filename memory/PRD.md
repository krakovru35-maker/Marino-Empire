# Marino Empire — Casino Tap-to-Earn Game (PRD)

## Original Problem Statement
> "Bu oyunu en zirveye taşımamız lazım, ne gerekiyorsa yapalım. Aynı Hamster Kombat gibi olsun (zaten benziyor) ama en ince detayına kadar yapalım. Oyunun konusu casino."

## User Choices (gathered)
- **Karakter:** Casino oyuncusu (Marino mascot)
- **Özellikler:** Hepsi (tap, mining, upgrade cards, Daily Combo, Daily Cipher, tasks, airdrop, league, referral, boosts)
- **Auth:** Telegram-style (kayıtsız giriş — Telegram WebApp init data ile)
- **Diller:** Türkçe + İngilizce (anlık toggle)
- **Tasarım:** Özgün modern casino teması

## Architecture
- **Single-page Telegram Mini-App** at `/app/index.html` (~3.9k lines)
- **Backend:** Supabase (remote, not modifiable from this env) — game state, RPC: tap_coin, claim_task, etc.
- **Sidecar Backend (this env):** FastAPI at `/app/backend/server.py` (/api/health)
- **Frontend (this env):** `serve` static server in `/app/frontend/` pointing to `/app/` via symlink — port 3000
- **Storage for new features:** localStorage (client-only persistence)

## What's Been Implemented (this session — Jan 2026)

### Hamster-Kombat-Tier Upgrades
- ✅ **Daily Combo**: 3-of-12 cards puzzle, deterministic daily seed, 6 attempts/day, +5,000,000 Coin reward, live countdown timer
- ✅ **Daily Cipher**: Morse-code keyboard puzzle, 12-word dictionary (deterministic daily), +1,000,000 Coin reward
- ✅ **Boost Center**: 5 boosts — Tam Enerji (3/day free), Tap Boost (3/day, 5x 20s), Çoklu Tıklama (paid, +1 tap power perm), Enerji Limiti (paid, +500 max perm), Otomatik Tıklama (5k coin, 12h auto-tap)
- ✅ **Airdrop Sheet**: $MARINO AIRDROP page with 6-item checklist (TG join, invite 3, level 10, 3-day streak, buy chips, connect TON wallet), animated coin hero, wallet-connect placeholder
- ✅ **i18n (TR/EN)**: Live language toggle in header, ~50 translation keys, persists in localStorage `m_lang`
- ✅ **Tap Combo Counter**: 10x/20x/30x... COMBO! popup every 10 rapid taps (<600ms apart) with sound + orange glow
- ✅ **Coin Particle Burst**: 4-10 gold particles fly out from tap location on each tap (10 when boost active)
- ✅ **Pulse Ring**: Animated gold ring around tap target
- ✅ **5x Tap Boost Visual Badge**: Green pulsing badge appears for 20s after activating Tap Boost

### Pre-existing (preserved, not modified)
- Tap-to-earn with energy + regen
- Buildings/Upgrades with passive income
- Casino mini-games: Slot (Marino Slot), Roulette V2, Blackjack, Poker, Horse Racing, Card Flip, Wheel of Fortune, Vault
- Live sports betting (auto-generated matches)
- Tasks (social/daily/level)
- Friends + Referrals + Leaderboard
- 10-tier League (Bronze→Marino Empire)
- Prestige system
- Daily login 8-day cycle rewards
- Sound + music settings, notifications, intro video

## Test Results
- Test report: `/app/test_reports/iteration_1.json`
- **100% pass** on all 9 new HK-tier features
- 0 JS errors, 0 ui bugs

## Backlog / Future
- **P1**: Migrate Daily Combo / Cipher rewards to Supabase RPC (so server-authoritative; currently localStorage)
- **P1**: Real TON Wallet connect (TonConnect SDK) — currently placeholder
- **P2**: Push notifications for daily streak break warnings
- **P2**: Split index.html JS into separate files for maintainability (currently 3.9k lines)
- **P2**: More cipher word dictionary entries (currently 12 words)
- **P3**: Animated daily combo card flip reveal on success

## Files Modified
- `/app/index.html` — added ~1100 lines (CSS + HTML + JS for HK features)
- `/app/backend/server.py` (new, sidecar health endpoint)
- `/app/backend/requirements.txt`, `/app/backend/.env`
- `/app/frontend/package.json`, `/app/frontend/.env`, `/app/frontend/public` (symlink to /app)
