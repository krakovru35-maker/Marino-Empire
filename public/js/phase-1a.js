(() => {
  'use strict';

  const state = { combo: 0, lastTap: 0, lastHaptic: -Infinity, pendingHaptic: 0, resetTimer: 0, viewportTimer: 0 };
  const root = document.documentElement;

  function effectiveViewportHeight() {
    const telegramHeight = Number(window.Telegram?.WebApp?.viewportStableHeight || 0);
    return telegramHeight > 0 ? telegramHeight : window.innerHeight;
  }

  function selectQuality() {
    const reduced = window.matchMedia?.('(prefers-reduced-motion: reduce)').matches;
    const memory = Number(navigator.deviceMemory || 0);
    const cores = Number(navigator.hardwareConcurrency || 0);
    const compact = effectiveViewportHeight() <= 568;
    const quality = reduced || compact || (memory && memory <= 2) || (cores && cores <= 2)
      ? 'lite'
      : ((memory >= 8 || cores >= 8) ? 'ultra' : 'balanced');
    if (root.dataset.quality === quality) return;
    root.classList.remove('quality-ultra', 'quality-balanced', 'quality-lite');
    root.classList.add(`quality-${quality}`);
    root.dataset.quality = quality;
  }

  function updateViewport() {
    const height = effectiveViewportHeight();
    root.style.setProperty('--app-height', `${Math.round(height)}px`);
  }

  function haptic(style = 'light', preserve = false) {
    const now = performance.now();
    const remaining = 70 - (now - state.lastHaptic);
    if (remaining > 0) {
      if (preserve) {
        clearTimeout(state.pendingHaptic);
        state.pendingHaptic = window.setTimeout(() => haptic(style, false), remaining);
      }
      return false;
    }
    const feedback = window.Telegram?.WebApp?.HapticFeedback;
    if (!feedback || typeof feedback.impactOccurred !== 'function') return false;
    try {
      feedback.impactOccurred(style);
      state.lastHaptic = now;
      return true;
    } catch (_) {
      return false;
    }
  }

  function refreshViewportProfile() {
    clearTimeout(state.viewportTimer);
    state.viewportTimer = window.setTimeout(() => {
      updateViewport();
      selectQuality();
    }, 100);
  }

  function closeEmpireHub() {
    const hub = document.querySelector('#empireHub');
    if (hub?.open) hub.open = false;
  }

  function resetCombo() {
    state.combo = 0;
    const output = document.querySelector('#visualCombo');
    if (output) {
      output.textContent = '';
      output.classList.remove('show', 'milestone');
    }
  }

  function tapFeedback(event) {
    const button = document.querySelector('#btnTap');
    if (!button) return;

    const now = performance.now();
    state.combo = now - state.lastTap <= 650 ? state.combo + 1 : 1;
    state.lastTap = now;
    clearTimeout(state.resetTimer);
    state.resetTimer = window.setTimeout(resetCombo, 900);

    button.classList.remove('instant-tap');
    void button.offsetWidth;
    button.classList.add('instant-tap');
    window.setTimeout(() => button.classList.remove('instant-tap'), 120);

    const rect = button.getBoundingClientRect();
    const pulse = document.createElement('i');
    pulse.className = 'tap-pulse';
    pulse.style.left = `${(event?.clientX || rect.left + rect.width / 2) - rect.left}px`;
    pulse.style.top = `${(event?.clientY || rect.top + rect.height / 2) - rect.top}px`;
    button.appendChild(pulse);
    pulse.addEventListener('animationend', () => pulse.remove(), { once: true });

    const output = document.querySelector('#visualCombo');
    if (output && state.combo >= 2) {
      output.textContent = `${state.combo}× COMBO`;
      output.classList.add('show');
      output.classList.toggle('milestone', state.combo % 10 === 0);
    }

    const milestone = state.combo > 0 && state.combo % 10 === 0;
    haptic(milestone ? 'medium' : 'light', milestone);
  }

  function init() {
    updateViewport();
    selectQuality();
    window.addEventListener('resize', refreshViewportProfile, { passive: true });
    window.addEventListener('orientationchange', refreshViewportProfile, { passive: true });
    window.Telegram?.WebApp?.onEvent?.('viewportChanged', refreshViewportProfile);
    window.matchMedia?.('(prefers-reduced-motion: reduce)')
      .addEventListener?.('change', selectQuality);

    const hub = document.querySelector('#empireHub');
    const backdrop = document.querySelector('#empireHubBackdrop');
    hub?.addEventListener('toggle', () => {
      if (backdrop) backdrop.hidden = !hub.open;
    });
    backdrop?.addEventListener('pointerdown', event => {
      event.preventDefault();
      event.stopPropagation();
      closeEmpireHub();
    });
    document.addEventListener('keydown', event => {
      if (event.key === 'Escape' && hub?.open) {
        closeEmpireHub();
        hub.querySelector('summary')?.focus();
      }
    });

    document.querySelector('#btnUpgradeTarget')?.addEventListener('click', () => {
      if (typeof window.showTab === 'function') window.showTab('buildings');
      else document.querySelector('.nav-btn[data-tab="buildings"]')?.click();
    });
  }

  window.MarinoPhase1A = { tapFeedback, updateViewport, selectQuality, haptic, effectiveViewportHeight };
  if (document.readyState === 'loading') document.addEventListener('DOMContentLoaded', init, { once: true });
  else init();
})();
