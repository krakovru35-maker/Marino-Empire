(() => {
  'use strict';
  const icon = id => `<svg viewBox="0 0 24 24" aria-hidden="true"><use href="./assets/ui/casino/marino-casino-icons.svg#casino-${id}"></use></svg>`;
  const games = [
    { id: 'slots', name: 'Marino Fortune Slots', type: '5x3 VIDEO SLOT', description: 'Server onayli coin slot deneyimi.', icon: 'slot', right: 'COIN', ready: true },
    { id: 'roulette', name: 'Marino European Roulette', type: 'TEK SIFIR AVRUPA RULETI', description: 'Server onayli chip rulet masasi.', icon: 'roulette', right: 'CHIP', ready: true },
    { id: 'blackjack', name: 'Marino Blackjack Lounge', type: '6 DECK VIP BLACKJACK', description: 'Server onayli chip blackjack masasi.', icon: 'blackjack', right: 'CHIP', ready: true },
    { id: 'baccarat', name: 'VIP Baccarat', type: 'PRIVATE TABLE', description: 'Seckin casino kati icin hazirlaniyor.', icon: 'vip', right: 'YAKINDA' }
  ];
  function card(game, index) {
    return `<article class="casino-lobby-card game-${game.id} ${game.ready ? '' : 'is-coming'}"><div class="casino-cover-art">${icon(game.icon)}<i></i><b>M</b></div><div class="casino-card-copy"><span>${game.type}</span><h3>${game.name}</h3><p>${game.description}</p><small>Sonuc ve bakiye sunucu onaylidir</small></div><div class="casino-card-actions"><em>${game.right}</em>${game.ready ? `<button type="button" data-casino-play="${game.id}">OYNA</button><button type="button" data-casino-rules="${game.id}">KURALLAR</button>` : '<button type="button" disabled>YAKINDA</button>'}${index === 0 ? '<mark>SON OYNANAN</mark>' : ''}</div></article>`;
  }
  function render() {
    const list = document.querySelector('#listStore');
    if (!list) return;
    const wallet = window.MarinoEconomyBridge?.snapshot?.() || window.MarinoDemoWallet?.snapshot?.() || {};
    list.innerHTML = `<section class="casino-lobby"><header><div><span>MARINO EMPIRE</span><h2>MARINO CASINO</h2><p>Server onayli oyunlar; basarisiz RPC bakiyeye yansimaz.</p></div><div class="casino-lobby-balance"><small>GERCEK BAKIYE</small><strong>${new Intl.NumberFormat('tr-TR').format(wallet.coin || wallet.balance || 0)} Coin</strong><strong>${new Intl.NumberFormat('tr-TR').format(wallet.chips || 0)} Chip</strong></div></header><div class="casino-lobby-stats"><span>${icon('free-spin')}<b>${wallet.freeSpins || 0}</b><small>Free Spin kapali</small></span><span>${icon('free-bet')}<b>${wallet.freeBets || 0}</b><small>Free Bet kapali</small></span><span>${icon('win')}<b>Server</b><small>Gorev</small></span></div>${window.MarinoCasinoProgression?.lobbyMarkup?.() || ''}<div class="casino-game-grid">${games.map(card).join('')}</div><footer><b>18+ gorsel alani</b><span>Ekonomik sonuc yalniz server RPC basarili olursa islenir.</span></footer></section>`;
  }
  function open(id) {
    const game = id === 'slots' ? window.MarinoSlots : id === 'roulette' ? window.MarinoRoulette : id === 'blackjack' ? window.MarinoBlackjack : null;
    if (game) {
      window.MarinoCasinoProgression?.record?.('casino_visit', { game: id });
      window.MarinoGameShell?.open(game);
    }
  }
  function openDirectPreview() {
    if (window.MarinoLocalPreview?.detect?.(window.location, window.Telegram?.WebApp) !== true) return false;
    const requested = new URLSearchParams(window.location.search).get('game');
    if (requested === 'slot') open('slots');
    else if (requested === 'roulette') open('roulette');
    else if (requested === 'blackjack') open('blackjack');
    else return false;
    return true;
  }
  document.addEventListener('click', event => {
    const nav = event.target.closest('.nav-btn[data-tab="store"]');
    if (nav) setTimeout(render, 0);
    const play = event.target.closest('[data-casino-play]');
    if (play) open(play.dataset.casinoPlay);
    const rules = event.target.closest('[data-casino-rules]');
    if (rules) {
      open(rules.dataset.casinoRules);
      window.MarinoCasinoProgression?.record?.('rules_open', { game: rules.dataset.casinoRules });
      setTimeout(() => document.querySelector('[data-shell-action="rules"]')?.click(), 0);
    }
  });
  window.MarinoCasinoLobby = Object.freeze({ render, open, openDirectPreview, games });
  if (document.readyState === 'loading') document.addEventListener('DOMContentLoaded', () => setTimeout(openDirectPreview, 0), { once: true });
  else setTimeout(openDirectPreview, 0);
})();
