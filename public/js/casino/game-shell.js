(() => {
  'use strict';
  const state = { game: null, active: false, startedAt: 0, timer: 0, backBound: false };
  const icon = (path, label) => `<svg viewBox="0 0 24 24" aria-label="${label}" role="img"><path d="${path}"/></svg>`;
  const isPreview = () => window.MarinoLocalPreview?.detect?.(window.location, window.Telegram?.WebApp) === true;

  function ensure() {
    let root = document.querySelector('#casinoGameShell');
    if (root) return root;
    root = document.createElement('section');
    root.id = 'casinoGameShell';
    root.className = 'casino-game-shell';
    root.hidden = true;
    root.setAttribute('aria-modal', 'true');
    root.setAttribute('role', 'dialog');
    root.innerHTML = `<div class="casino-shell-backdrop"></div><div class="casino-shell-frame"><header class="casino-shell-header"><div class="casino-shell-brand"><span>MARINO CASINO</span><h2 id="casinoShellTitle">Oyun</h2></div><div class="casino-shell-wallet"><span>GERCEK BAKIYE</span><strong id="casinoShellBalance">0</strong></div><button type="button" data-shell-action="sound" aria-label="Sesi ac veya kapat">${icon('M5 9v6h4l5 4V5L9 9H5m12 1a4 4 0 0 1 0 4', 'Ses')}</button><button type="button" data-shell-action="fullscreen" aria-label="Tam ekran">${icon('M8 3H3v5h5v5M8 21H3v-5m13 5h5v-5', 'Tam ekran')}</button><button type="button" data-shell-action="close" aria-label="Oyundan cik">${icon('M6 6l12 12M18 6 6 18', 'Kapat')}</button></header><div class="casino-shell-meta"><span id="casinoShellRights">Server onayli ekonomi</span><button type="button" data-shell-action="rules">Kurallar</button><button type="button" data-shell-action="history">Gecmis</button><span id="casinoShellSession">00:00</span></div><div id="casinoShellStage" class="casino-shell-stage" role="main"></div><aside id="casinoShellPanel" class="casino-shell-panel" hidden></aside><footer><span>Sonuc ve bakiye yalniz sunucu onayiyla islenir</span><button type="button" data-shell-action="break">Mola ver</button></footer></div>`;
    document.body.appendChild(root);
    root.addEventListener('pointerdown', event => event.stopPropagation());
    root.addEventListener('click', onAction);
    return root;
  }

  function wallet() {
    const bridge = window.MarinoEconomyBridge;
    const snap = bridge?.snapshot?.() || window.MarinoDemoWallet?.snapshot?.() || { balance: 0, coin: 0, chips: 0 };
    const coin = Number(snap.coin ?? snap.balance ?? 0);
    const chips = Number(snap.chips || 0);
    document.querySelector('#casinoShellBalance').textContent = `${new Intl.NumberFormat('tr-TR').format(coin)} Coin / ${new Intl.NumberFormat('tr-TR').format(chips)} Chip`;
    document.querySelector('#casinoShellRights').textContent = bridge?.preview ? 'Yerel UI onizleme' : 'Server onayli ekonomi';
  }

  function onAction(event) {
    const action = event.target.closest('[data-shell-action]')?.dataset.shellAction;
    if (!action) return;
    if (action === 'close') return close();
    if (action === 'rules') return panel('rules');
    if (action === 'history') return panel('history');
    if (action === 'break' || action === 'lobby') return close(true);
    if (action === 'retry') return mountGame();
    if (action === 'fullscreen') return document.documentElement.requestFullscreen?.().catch(() => {});
    if (action === 'sound') {
      const button = event.target.closest('button');
      button.classList.toggle('muted');
      document.querySelector('#swSfx')?.classList.toggle('on', !button.classList.contains('muted'));
    }
  }

  function panel(type) {
    const el = document.querySelector('#casinoShellPanel');
    if (!el) return;
    const history = state.game?.history?.() || [];
    el.hidden = false;
    el.innerHTML = `<button type="button" data-panel-close aria-label="Paneli kapat">x</button>${type === 'rules' ? `<h3>${state.game?.name || 'Oyun'} Kurallari</h3>${state.game?.rules || ''}` : `<h3>Sonuc Gecmisi</h3><ol>${history.length ? history.map(item => `<li>${item}</li>`).join('') : '<li>Henuz sonuc yok.</li>'}</ol>`}`;
    el.querySelector('[data-panel-close]').onclick = () => { el.hidden = true; };
    window.MarinoAudio?.play?.('ui_open');
  }

  function bindBack() {
    const back = window.Telegram?.WebApp?.BackButton;
    if (!back || state.backBound) return;
    back.onClick(close);
    back.show();
    state.backBound = true;
  }

  function unbindBack() {
    const back = window.Telegram?.WebApp?.BackButton;
    if (!back || !state.backBound) return;
    back.offClick?.(close);
    back.hide();
    state.backBound = false;
  }

  function formatTime() {
    const seconds = Math.floor((Date.now() - state.startedAt) / 1000);
    return `${String(Math.floor(seconds / 60)).padStart(2, '0')}:${String(seconds % 60).padStart(2, '0')}`;
  }

  function errorCard(code, error) {
    const stage = document.querySelector('#casinoShellStage');
    stage.replaceChildren();
    const card = document.createElement('section');
    card.className = 'casino-mount-error';
    card.setAttribute('role', 'alert');
    card.innerHTML = `<span>MARINO CASINO</span><h3>Oyun yuklenemedi</h3><p>Oyun kabugu guvenli bicimde durduruldu. Lutfen yeniden deneyin.</p><small>Hata kodu: ${code}</small><div><button type="button" data-shell-action="retry">Tekrar Dene</button><button type="button" data-shell-action="lobby">Casino Lobisine Don</button></div>`;
    stage.appendChild(card);
    if (isPreview()) console.error(`[MarinoCasino:${code}]`, error);
    return false;
  }

  function mountGame() {
    const stage = document.querySelector('#casinoShellStage');
    if (!stage || !state.game) return false;
    stage.replaceChildren();
    let mounted;
    try {
      mounted = state.game.mount();
      if (!(mounted instanceof Element)) throw new TypeError('invalid_mount_element');
      stage.appendChild(mounted);
    } catch (error) {
      return errorCard('CG-MOUNT-01', error);
    }
    try {
      state.game.onOpen?.();
    } catch (error) {
      return errorCard('CG-OPEN-02', error);
    }
    return true;
  }

  function open(game) {
    const root = ensure();
    state.game = game;
    state.active = true;
    state.startedAt = Date.now();
    root.hidden = false;
    document.documentElement.classList.add('casino-game-open');
    document.body.classList.add('casino-scroll-lock');
    document.querySelector('#casinoShellTitle').textContent = game?.name || 'Oyun';
    wallet();
    bindBack();
    clearInterval(state.timer);
    state.timer = setInterval(() => {
      const el = document.querySelector('#casinoShellSession');
      if (el) el.textContent = formatTime();
      wallet();
    }, 1000);
    window.MarinoAudio?.play?.('ui_open');
    return mountGame();
  }

  function close(force = false) {
    if (!state.active) return true;
    if (!force && state.game?.isActive?.() && !window.confirm('Aktif tur devam ediyor. Oyundan cikilsin mi?')) return false;
    state.game?.onClose?.();
    state.active = false;
    clearInterval(state.timer);
    hidePanel();
    unbindBack();
    const root = ensure();
    root.hidden = true;
    document.documentElement.classList.remove('casino-game-open');
    document.body.classList.remove('casino-scroll-lock');
    window.MarinoAudio?.play?.('ui_close');
    return true;
  }

  function hidePanel() {
    const el = document.querySelector('#casinoShellPanel');
    if (el) el.hidden = true;
  }

  function keydown(event) {
    if (state.active && event.key === 'Escape') {
      event.preventDefault();
      if (!document.querySelector('#casinoShellPanel')?.hidden) return hidePanel();
      close();
    }
  }

  document.addEventListener('keydown', keydown, true);
  document.addEventListener('visibilitychange', () => { if (state.active) state.game?.setPaused?.(document.hidden); });
  window.MarinoGameShell = Object.freeze({ open, close, retry: mountGame, openPanel: panel, refreshWallet: wallet, isOpen: () => state.active });
})();
