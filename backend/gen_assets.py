"""Generate Marino Empire building & UI assets using Gemini Nano Banana.

Run once: `python3 /app/backend/gen_assets.py`
Outputs PNGs to /app/public/assets/buildings/ and /app/public/assets/boosts/
"""
import asyncio
import os
import base64
import sys
from pathlib import Path
from dotenv import load_dotenv
from emergentintegrations.llm.chat import LlmChat, UserMessage

load_dotenv("/app/backend/.env")
API_KEY = os.getenv("EMERGENT_LLM_KEY")
MODEL = "gemini-3.1-flash-image-preview"

# Shared style brief for cohesive look
STYLE = (
    "Style: ultra-detailed cinematic isometric 3D render, luxurious Las Vegas casino "
    "aesthetic, deep navy + gold + amber color palette, glowing neon highlights, "
    "rich reflective marble floors, dramatic rim lighting, subtle volumetric haze, "
    "transparent dark background, centered composition, no text, no watermarks, "
    "no people unless specified, premium mobile game icon quality, square 1:1, "
    "matches a tap-to-earn casino game called 'Marino Empire'."
)

BUILDINGS = [
    ("casino_lobby",
     "Grand casino lobby entrance with double golden doors, red velvet rope, "
     "chandelier, marble staircase, palm trees flanking the entrance."),
    ("slot_area",
     "Row of three glowing slot machines with cherries, sevens, and bells "
     "displayed on screens, gold trim, neon LED edges, scattered casino chips."),
    ("sportsbook_area",
     "Modern sports betting lounge with floor-to-ceiling LED screens showing "
     "stadium scenes, plush leather chairs, drink table, soccer ball and football helmet props."),
    ("vip_casino",
     "Exclusive VIP private gambling room with single illuminated poker table, "
     "ornate gold-leaf walls, crystal chandelier, stacked chip towers, champagne bottle in ice bucket."),
    ("rewards_office",
     "Reward vault office: cashier counter with stacks of golden coins and chips, "
     "a giant open safe full of gold bars in the background, ledger book on desk."),
    ("admin_control",
     "Casino security and admin control room: wall of CCTV monitors showing the casino floor, "
     "main desk with computer terminals, swivel chair, golden Marino Empire emblem above."),
]

BOOSTS = [
    ("full_energy",
     "Glowing golden battery icon at full charge with golden lightning crackle around it, "
     "casino chip motif on the battery body, isometric icon style."),
    ("tap_boost",
     "Stylized golden hand making a tapping gesture with a lightning bolt emanating, "
     "neon 5x multiplier hovering in the air, casino chips swirling around."),
    ("multitap",
     "Two golden fingertips with golden coins bursting upward in an arc, "
     "level-up plus icon, magical sparkles."),
    ("energy_limit",
     "Tall golden battery container with capacity meter overflowing, "
     "extra-large size, gilded edges, casino chip texture."),
    ("auto_tap",
     "Friendly small golden robot mascot tapping a giant Marino coin with both hands, "
     "spinning gear icon, clock face in background."),
]

COMBO_CARDS = [
    ("card_spade_a", "Premium Ace of Spades playing card, gold-foil intricate spade emblem, deep black background, casino quality."),
    ("card_heart_a", "Premium Ace of Hearts playing card, gold-foil heart, ruby red highlights."),
    ("card_club_a", "Premium Ace of Clubs playing card, gold-foil club emblem, emerald accents."),
    ("card_diamond_a", "Premium Ace of Diamonds playing card, gold-foil diamond emblem, sapphire blue accents."),
    ("card_king", "Premium King playing card, ornate golden crown with rubies, royal purple velvet background, gilded edges."),
    ("card_queen", "Premium Queen playing card, elegant golden tiara with diamonds, deep magenta background, gold filigree border."),
    ("card_jack", "Premium Jack playing card, golden knight helmet with feather plume, dark green velvet background."),
    ("card_joker", "Premium Joker playing card, mischievous golden jester mask with bells, multicolor confetti, dark background."),
    ("card_chip", "Single luxury casino poker chip, golden rim with engraved Marino emblem, top-down view, dramatic lighting."),
    ("card_dice", "Two pristine golden dice tumbling mid-air, dramatic lighting, casino backdrop blurred."),
    ("card_wheel", "Golden roulette wheel mini view, ball spinning, motion blur, casino felt background."),
    ("card_slot", "Single ornate slot machine front facing camera, golden trim, three lucky 777 reels showing."),
]

LEAGUES = [
    ("league_bronze",   "Bronze league badge medal, hexagonal shape, polished bronze metal, casino chip motif inside, glowing rim, transparent background."),
    ("league_silver",   "Silver league badge medal, hexagonal shape, brushed silver, casino chip motif, glowing rim."),
    ("league_gold",     "Gold league badge medal, hexagonal shape, shining 24k gold, royal casino emblem, sparkling diamonds, glowing rim."),
    ("league_platinum", "Platinum league badge medal, hexagonal shape, iridescent platinum, sapphire accents, glowing rim."),
    ("league_diamond",  "Diamond league badge medal, hexagonal shape, crystal diamond, brilliant cuts, blue-white glow."),
    ("league_marino",   "Marino Empire ultimate league badge medal, hexagonal shape, golden crown on top, royal purple jewel center, intense gold glow."),
]

EXTRA = [
    ("airdrop_hero", "Massive premium golden Marino casino coin floating in mid-air, embossed M emblem with crown, intense golden rays radiating outward, particle sparkles, dramatic spotlight, dark casino interior background, premium tap-to-earn airdrop landing graphic."),
    ("league_chevron", "Glowing golden chevron arrow pointing right, casino style, transparent background, premium UI element."),
]


async def gen_one(slug: str, prompt: str, out_dir: Path):
    out_path = out_dir / f"{slug}.png"
    if out_path.exists() and out_path.stat().st_size > 5000:
        print(f"  [skip] {slug}.png exists ({out_path.stat().st_size} bytes)")
        return True
    chat = LlmChat(api_key=API_KEY, session_id=f"marino-{slug}",
                   system_message="You are a master casino game illustrator.")
    chat.with_model("gemini", MODEL).with_params(modalities=["image", "text"])
    full = f"{prompt}\n\n{STYLE}"
    msg = UserMessage(text=full)
    try:
        text, images = await chat.send_message_multimodal_response(msg)
        if images:
            img_bytes = base64.b64decode(images[0]["data"])
            out_path.write_bytes(img_bytes)
            print(f"  [ok]   {slug}.png  ({len(img_bytes)} bytes)")
            return True
        else:
            print(f"  [fail] {slug}: no images (text={text[:80]!r})")
            return False
    except Exception as e:
        print(f"  [err]  {slug}: {e}")
        return False


async def main(targets):
    Path("/app/public/assets/buildings").mkdir(parents=True, exist_ok=True)
    Path("/app/public/assets/boosts").mkdir(parents=True, exist_ok=True)
    Path("/app/public/assets/combo_cards").mkdir(parents=True, exist_ok=True)

    if "buildings" in targets:
        print("\n=== BUILDINGS ===")
        for slug, prompt in BUILDINGS:
            await gen_one(slug, prompt, Path("/app/public/assets/buildings"))

    if "boosts" in targets:
        print("\n=== BOOSTS ===")
        for slug, prompt in BOOSTS:
            await gen_one(slug, prompt, Path("/app/public/assets/boosts"))

    if "cards" in targets:
        print("\n=== COMBO CARDS ===")
        for slug, prompt in COMBO_CARDS:
            await gen_one(slug, prompt, Path("/app/public/assets/combo_cards"))

    if "leagues" in targets:
        Path("/app/public/assets/leagues").mkdir(parents=True, exist_ok=True)
        print("\n=== LEAGUES ===")
        for slug, prompt in LEAGUES:
            await gen_one(slug, prompt, Path("/app/public/assets/leagues"))

    if "extra" in targets:
        Path("/app/public/assets/extra").mkdir(parents=True, exist_ok=True)
        print("\n=== EXTRA ===")
        for slug, prompt in EXTRA:
            await gen_one(slug, prompt, Path("/app/public/assets/extra"))


if __name__ == "__main__":
    targets = sys.argv[1:] if len(sys.argv) > 1 else ["buildings", "boosts", "cards", "leagues", "extra"]
    asyncio.run(main(targets))
