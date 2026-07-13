(() => {
  'use strict';

  const TIER_NAMES = { 1: 'Arka Oda', 2: 'Marino Lounge', 3: 'Grand Casino' };
  const state = { tier: 0, previewTier: 0, transitionTimer: 0, countFrame: 0 };

  function selectTier(progression = {}) {
    const level = Number(progression.level || 0);
    const buildingLevel = Number(progression.buildingLevel || 0);
    const value = level > 0 ? level : buildingLevel;
    return value >= 30 ? 3 : value >= 10 ? 2 : 1;
  }

  function reducedOrLite() {
    return document.documentElement.dataset.quality === 'lite'
      || window.matchMedia?.('(prefers-reduced-motion: reduce)').matches === true;
  }

  function celebrateTransition(tier) {
    const home = document.querySelector('#view-home');
    const notice = document.querySelector('#empireTierTransition');
    const name = document.querySelector('#empireTierName');
    const marino = document.querySelector('#btnTap');
    if (!home || !notice || !name) return;
    clearTimeout(state.transitionTimer);
    name.textContent = TIER_NAMES[tier];
    notice.hidden = false;
    home.classList.remove('empire-tier-changing');
    void home.offsetWidth;
    home.classList.add('empire-tier-changing');
    if (!reducedOrLite()) marino?.classList.add('empire-tier-celebrate');
    state.transitionTimer = window.setTimeout(() => {
      home.classList.remove('empire-tier-changing');
      marino?.classList.remove('empire-tier-celebrate');
      notice.hidden = true;
    }, 1150);
  }

  function applyTier(tier, announce = true) {
    const home = document.querySelector('#view-home');
    if (!home || tier === state.tier) return tier;
    const previous = state.tier;
    home.classList.remove('empire-tier-1', 'empire-tier-2', 'empire-tier-3');
    home.classList.add(`empire-tier-${tier}`);
    home.dataset.empireTier = String(tier);
    state.tier = tier;
    if (previous && announce) celebrateTransition(tier);
    return tier;
  }

  function syncScene(progression = {}) {
    return applyTier(state.previewTier || selectTier(progression), true);
  }

  function successHaptic() {
    const feedback = window.Telegram?.WebApp?.HapticFeedback;
    if (!feedback || typeof feedback.notificationOccurred !== 'function') return;
    try { feedback.notificationOccurred('success'); } catch (_) { }
  }

  function animateBalance(from, to) {
    const output = document.querySelector('#valCoin');
    if (!output) return;
    cancelAnimationFrame(state.countFrame);
    if (reducedOrLite() || !Number.isFinite(from) || !Number.isFinite(to)) {
      output.textContent = new Intl.NumberFormat('en-US').format(to);
      output.classList.add('collect-count-pop');
      window.setTimeout(() => output.classList.remove('collect-count-pop'), 320);
      return;
    }
    const started = performance.now();
    const draw = now => {
      const progress = Math.min(1, (now - started) / 650);
      const eased = 1 - Math.pow(1 - progress, 3);
      output.textContent = new Intl.NumberFormat('en-US').format(Math.round(from + (to - from) * eased));
      if (progress < 1) state.countFrame = requestAnimationFrame(draw);
      else output.classList.add('collect-count-pop');
    };
    state.countFrame = requestAnimationFrame(draw);
    window.setTimeout(() => output.classList.remove('collect-count-pop'), 900);
  }

  function emitCollectTrail() {
    if (reducedOrLite()) return;
    const source = document.querySelector('#btnCollect');
    const target = document.querySelector('.bal-coin img');
    const app = document.querySelector('#app');
    if (!source || !target || !app) return;
    const a = source.getBoundingClientRect(), b = target.getBoundingClientRect();
    const x = a.left + a.width / 2, y = a.top + a.height / 2;
    for (let i = 0; i < 5; i += 1) {
      const coin = document.createElement('i');
      coin.className = 'collect-flight';
      coin.style.left = `${x}px`;
      coin.style.top = `${y}px`;
      coin.style.setProperty('--flight-x', `${b.left + b.width / 2 - x}px`);
      coin.style.setProperty('--flight-y', `${b.top + b.height / 2 - y}px`);
      coin.style.setProperty('--flight-delay', `${i * 48}ms`);
      app.appendChild(coin);
      coin.addEventListener('animationend', () => coin.remove(), { once: true });
    }
  }

  function collectSuccess(result = {}) {
    const from = Number(result.from), to = Number(result.to);
    emitCollectTrail();
    animateBalance(from, to);
    const marino = document.querySelector('#btnTap');
    marino?.classList.remove('empire-collect-success');
    void marino?.offsetWidth;
    marino?.classList.add('empire-collect-success');
    window.setTimeout(() => marino?.classList.remove('empire-collect-success'), 700);
    successHaptic();
    window.MarinoAudio?.play?.('collect_vault');
    document.dispatchEvent(new CustomEvent('marino:collect-success', { detail: { amount: Number(result.amount || 0) } }));
  }

  function isLocalPreview() {
    return window.MarinoLocalPreview?.detect?.(window.location, window.Telegram?.WebApp) === true;
  }

  function installPreviewControl() {
    if (!isLocalPreview() || document.querySelector('#empireTierControl')) return;
    const control = document.createElement('div');
    control.id = 'empireTierControl';
    control.className = 'empire-tier-control';
    control.setAttribute('aria-label', 'Living Empire sahne testi');
    control.innerHTML = '<span>SCENE</span>' + [1, 2, 3].map(tier => `<button type="button" data-tier="${tier}" aria-label="Tier ${tier}: ${TIER_NAMES[tier]}">T${tier}</button>`).join('');
    control.addEventListener('click', event => {
      const button = event.target.closest('button[data-tier]');
      if (!button) return;
      state.previewTier = Number(button.dataset.tier);
      control.querySelectorAll('button').forEach(item => item.classList.toggle('active', item === button));
      applyTier(state.previewTier, true);
    });
    document.querySelector('#app')?.appendChild(control);
  }

  function init() {
    installPreviewControl();
    const level = Number(document.querySelector('#valLvl')?.textContent || 0);
    applyTier(selectTier({ level }), false);
  }

  window.MarinoPhase2A = Object.freeze({ selectTier, syncScene, collectSuccess, isLocalPreview });
  if (document.readyState === 'loading') document.addEventListener('DOMContentLoaded', init, { once: true });
  else init();
})();
