# Marino Empire — Casino Tap-to-Earn Game (PRD)

## Original Problem Statement
> "Bu oyunu en zirveye taşımamız lazım, ne gerekiyorsa yapalım. Aynı Hamster Kombat gibi olsun (zaten benziyor) ama en ince detayına kadar yapalım. Oyunun konusu casino."
> + "Binalar sekmesinde binaların görselleri yok, bunları üret. Görseller vs daha da ne katabiliyorsak katalım, mükemmeliyete ulaşsın oyun."

## User Choices
- **Karakter:** Casino oyuncusu (Marino mascot)
- **Özellikler:** Hepsi (tap, mining, upgrade cards, Daily Combo, Daily Cipher, tasks, airdrop, league, referral, boosts)
- **Auth:** Telegram-style (Telegram WebApp init data)
- **Diller:** Türkçe + İngilizce (anlık toggle)
- **Tasarım:** Özgün modern casino teması

## Architecture
- **Single-page Telegram Mini-App** at `/app/index.html` (~4.1k lines)
- **Backend:** Supabase (PostgreSQL + PostgREST + RPC) + FastAPI sidecar
- **Frontend:** `serve` static server (`/app/frontend/public` → `/app` symlink) on port 3000
- **AI Assets:** Gemini Nano Banana (`gemini-3.1-flash-image-preview`) via emergentintegrations + EMERGENT_LLM_KEY
- **Storage:** Server-authoritative (Supabase tables) + localStorage offline fallback

## What's Been Implemented (Jan 2026)

### Iteration 1 — Hamster-Kombat-Tier Features
- Daily Combo, Daily Cipher, Boost Center, Airdrop, TR/EN i18n, tap-combo counter, particle effects
- 4 new Supabase tables + 13 RPC functions
- Server-authoritative with offline fallback

### Iteration 2 — Premium AI-Generated Visuals (this session)
- **6 building images** (1024x1024): `casino_lobby`, `slot_area`, `sportsbook_area`, `vip_casino`, `rewards_office`, `admin_control` → `/app/public/assets/buildings/*.png`
- **5 boost icons**: `full_energy`, `tap_boost`, `multitap`, `energy_limit`, `auto_tap` → `/app/public/assets/boosts/*.png`
- **12 combo cards**: 4 Aces + King/Queen/Jack/Joker + Chip/Dice/Wheel/Slot → `/app/public/assets/combo_cards/*.png`
- **6 league badges**: Bronze→Marino Empire hexagonal medals → `/app/public/assets/leagues/*.png`
- **Airdrop hero**: Premium $MARINO coin landing graphic → `/app/public/assets/extra/airdrop_hero.png`
- **Item-ico polish**: Gold-tinted gradient border, lock overlay for locked buildings, rounded corners, shadow effects
- **Frontend wired**: All locations now use generated images with emoji/legacy fallbacks via `onerror`

### Asset Generation Pipeline
- `/app/backend/gen_assets.py` — single-file Python script using Gemini Nano Banana
- Idempotent: skips files already present + size > 5KB
- Usage: `python3 gen_assets.py buildings boosts cards leagues extra`
- Style brief: cinematic isometric 3D render, Las Vegas casino aesthetic, navy+gold+amber palette

## Backlog / Future
- **P1**: Real TonConnect SDK integration (currently mock UQ... addresses)
- **P2**: Generate task icons (social, daily, level) via Gemini
- **P2**: Add more casino room background videos
- **P3**: Split `index.html` into modular JS

## Files Modified This Session
- `/app/backend/gen_assets.py` — NEW, asset generation pipeline
- `/app/backend/.env` — added `EMERGENT_LLM_KEY`
- `/app/index.html` — building/boost/league image integration (~40 line changes)
- 29 PNG files generated: 6 buildings + 5 boosts + 12 cards + 6 leagues + 2 extras
- `/app/supabase_migration.sql` — already deployed to Supabase by user

## Test Status
- E2E browser test: All sheets render with new images ✓ (buildings list, boost center, combo cards, league list, airdrop hero, league badge)
- 0 JS errors, 0 broken images, fallbacks work
