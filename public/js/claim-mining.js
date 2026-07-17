(() => {
  'use strict';

  const CLAIM_COSTS = Object.freeze({ free_spin: 30, free_bet: 45 });
  const state = {
    loaded: false,
    loading: false,
    profile: null,
    wallet: { claim_coin: 0, lifetime_mined: 0, mined_today: 0, next_mine_at: null, daily_cap: 18 },
    requests: [],
    costs: CLAIM_COSTS,
    promptShown: false
  };
  const q = selector => document.querySelector(selector);
  const fmt = value => new Intl.NumberFormat('tr-TR').format(Number(value || 0));
  const escape = value => String(value ?? '').replace(/[&<>"']/g, char => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[char]));
  const bridge = () => window.MarinoClaimBridge;
  const uuid = () => crypto.randomUUID();
  const validUsername = value => /^[A-Za-z0-9_.-]{3,32}$/.test(String(value || '').trim());
  const nextText = () => {
    const at = state.wallet?.next_mine_at ? new Date(state.wallet.next_mine_at).getTime() : 0;
    const diff = at - Date.now();
    if (!at || diff <= 0) return 'Hazır';
    return `${Math.ceil(diff / 60000)} dk`;
  };

  window.MarinoClaimMiningPreview = window.MarinoClaimMiningPreview || (() => {
    const preview = {
      profile: null,
      wallet: { claim_coin: 12, lifetime_mined: 88, mined_today: 4, next_mine_at: null, daily_cap: 18 },
      requests: [
        { id: 'preview-1', reward_type: 'free_spin', amount: 1, cost_claim_coin: 30, status: 'pending', site_username: 'kaanbm', created_at: new Date().toISOString() }
      ]
    };
    return {
      player(action, payload = {}) {
        if (action === 'state') return { ok: true, profile: preview.profile, wallet: preview.wallet, requests: preview.requests, costs: CLAIM_COSTS, server_time: new Date().toISOString() };
        if (action === 'bind_site_username') {
          const username = String(payload.site_username || '').trim();
          if (!validUsername(username)) throw Error('invalid_site_username');
          preview.profile = { site_username: username, locked: true, updated_at: new Date().toISOString() };
          return this.player('state');
        }
        if (action === 'mine_claim_coin') {
          if (!preview.profile?.site_username) throw Error('site_username_required');
          preview.wallet.claim_coin += 2; preview.wallet.lifetime_mined += 2; preview.wallet.mined_today += 2;
          return { ok: true, mined: 2, wallet: preview.wallet, message: '+2 Claim Coin' };
        }
        if (action === 'create_reward_claim') {
          const rewardType = payload.reward_type === 'free_bet' ? 'free_bet' : 'free_spin';
          const amount = Math.max(1, Math.min(10, Number(payload.amount || 1)));
          const cost = CLAIM_COSTS[rewardType] * amount;
          if (preview.wallet.claim_coin < cost) throw Error('insufficient_claim_coin');
          preview.wallet.claim_coin -= cost;
          preview.requests.unshift({ id: uuid(), reward_type: rewardType, amount, cost_claim_coin: cost, status: 'pending', site_username: preview.profile.site_username, created_at: new Date().toISOString() });
          return this.player('state');
        }
        return { ok: false };
      },
      admin(action, payload = {}) {
        if (action === 'claims_list') return { ok: true, items: preview.requests };
        if (action === 'claim_set_status') {
          const request = preview.requests.find(item => item.id === payload.request_id);
          if (request) request.status = payload.status || 'approved';
          return { ok: true };
        }
        return { ok: true, items: [] };
      }
    };
  })();

  async function load() {
    if (state.loading || !bridge()?.ready?.()) return false;
    state.loading = true;
    try {
      const data = await bridge().invoke('state', {}, null);
      state.profile = data?.profile || null;
      state.wallet = data?.wallet || state.wallet;
      state.requests = Array.isArray(data?.requests) ? data.requests : [];
      state.costs = data?.costs || CLAIM_COSTS;
      state.loaded = true;
      render();
      maybePromptUsername();
      return true;
    } catch {
      return false;
    } finally {
      state.loading = false;
    }
  }

  async function bindUsername(value) {
    const siteUsername = String(value || '').trim();
    if (!validUsername(siteUsername)) return bridge()?.toast?.('Site kullanıcı adı 3-32 karakter olmalı.');
    try {
      const data = await bridge().invoke('bind_site_username', { site_username: siteUsername }, uuid());
      state.profile = data?.profile || state.profile;
      state.wallet = data?.wallet || state.wallet;
      state.requests = Array.isArray(data?.requests) ? data.requests : state.requests;
      bridge()?.toast?.('Site üyeliği bağlandı.');
      closePrompt();
      render();
    } catch {
      bridge()?.toast?.('Bu kullanıcı adı bağlanamadı. Yazımı veya başka hesaba bağlı olup olmadığını kontrol et.');
    }
  }

  async function mine() {
    try {
      const data = await bridge().invoke('mine_claim_coin', {}, uuid());
      state.wallet = data?.wallet || state.wallet;
      bridge()?.toast?.(data?.message || 'Claim Coin kazıldı.');
      render();
    } catch {
      bridge()?.toast?.('Mining şu an hazır değil. Süreyi veya günlük limiti kontrol et.');
    }
  }

  async function requestReward(rewardType, amount = 1) {
    if (!state.profile?.site_username) return maybePromptUsername(true);
    try {
      const data = await bridge().invoke('create_reward_claim', { reward_type: rewardType, amount: Number(amount || 1) }, uuid());
      state.wallet = data?.wallet || state.wallet;
      state.requests = Array.isArray(data?.requests) ? data.requests : state.requests;
      bridge()?.toast?.('Talep yetkili paneline gönderildi.');
      render();
    } catch {
      bridge()?.toast?.('Talep oluşturulamadı. Claim Coin bakiyeni ve limitleri kontrol et.');
    }
  }

  function requestRows() {
    if (!state.requests.length) return '<p class="claim-empty">Henüz talep yok. Claim Coin kaz ve ilk talebini aç.</p>';
    const labels = { free_spin: 'Free Spin', free_bet: 'Free Bet' };
    return state.requests.slice(0, 4).map(item => `<div class="claim-request-row"><span>${escape(labels[item.reward_type] || item.reward_type)} x${Number(item.amount || 1)}</span><b class="status-${escape(item.status)}">${escape(item.status)}</b></div>`).join('');
  }

  function cardMarkup() {
    const username = state.profile?.site_username;
    const costs = state.costs || CLAIM_COSTS;
    const balance = Number(state.wallet?.claim_coin || 0);
    return `<section class="claim-mining-card">
      <header><div><span>CLAIM MINING</span><h3>FreeSpin / FreeBet Coin</h3></div><strong>${fmt(balance)} CC</strong></header>
      <p>Claim Coin zor kazanılır; Free Spin ve Free Bet talepleri bağlı site kullanıcı adınla yetkili paneline düşer.</p>
      <div class="claim-site-lock ${username ? 'is-bound' : ''}">
        <div><small>Site üyeliği</small><b>${username ? escape(username) : 'Bağlantı gerekli'}</b></div>
        <button type="button" data-claim-bind>${username ? 'Güncelle' : 'Bağla'}</button>
      </div>
      <div class="claim-mining-stats">
        <div><small>Bugün</small><b>${fmt(state.wallet?.mined_today || 0)} / ${fmt(state.wallet?.daily_cap || 18)}</b></div>
        <div><small>Sonraki kazım</small><b>${nextText()}</b></div>
        <div><small>Toplam</small><b>${fmt(state.wallet?.lifetime_mined || 0)}</b></div>
      </div>
      <button type="button" class="claim-mine-button" data-claim-mine ${username ? '' : 'disabled'}>⛏️ Claim Coin Kaz</button>
      <div class="claim-reward-grid">
        <button type="button" data-claim-request="free_spin" ${balance >= Number(costs.free_spin || 30) && username ? '' : 'disabled'}><b>Free Spin Talep</b><small>${fmt(costs.free_spin || 30)} CC / adet</small></button>
        <button type="button" data-claim-request="free_bet" ${balance >= Number(costs.free_bet || 45) && username ? '' : 'disabled'}><b>Free Bet Talep</b><small>${fmt(costs.free_bet || 45)} CC / adet</small></button>
      </div>
      <div class="claim-request-list"><h4>Son Talepler</h4>${requestRows()}</div>
    </section>`;
  }

  function render() {
    const list = q('#listStore');
    if (!list) return;
    const existing = q('#claimMiningMount');
    if (existing) existing.remove();
    const mount = document.createElement('div');
    mount.id = 'claimMiningMount';
    mount.innerHTML = cardMarkup();
    list.prepend(mount);
  }

  function promptMarkup(force = false) {
    const suggested = bridge()?.suggestedUsername?.() || '';
    return `<div class="claim-username-overlay" id="claimUsernameOverlay">
      <section class="claim-username-modal" role="dialog" aria-modal="true" aria-label="Site kullanıcı adı bağla">
        <span>MARINO CLAIM LOCK</span>
        <h3>Site kullanıcı adını bağla</h3>
        <p>FreeSpin / FreeBet talepleri yalnız bu üyelik adına açılır. Başka üyeliklerden talep gelmesini engellemek için kullanıcı adı server’da kilitlenir.</p>
        <input id="claimUsernameInput" maxlength="32" autocomplete="off" placeholder="Sitedeki kullanıcı adın" value="${escape(suggested)}">
        <div><button type="button" data-claim-username-save>Bağla</button>${force ? '' : '<button type="button" data-claim-username-later>Sonra</button>'}</div>
      </section>
    </div>`;
  }

  function maybePromptUsername(force = false) {
    if (state.profile?.site_username || q('#claimUsernameOverlay')) return false;
    if (!force && state.promptShown) return false;
    state.promptShown = true;
    document.body.insertAdjacentHTML('beforeend', promptMarkup(force));
    return true;
  }

  function closePrompt() { q('#claimUsernameOverlay')?.remove(); }

  function bind() {
    document.addEventListener('click', event => {
      if (event.target.closest('[data-claim-bind]')) return maybePromptUsername(true);
      if (event.target.closest('[data-claim-mine]')) return mine();
      const request = event.target.closest('[data-claim-request]');
      if (request) return requestReward(request.dataset.claimRequest, 1);
      if (event.target.closest('[data-claim-username-save]')) return bindUsername(q('#claimUsernameInput')?.value || '');
      if (event.target.closest('[data-claim-username-later]')) return closePrompt();
    });
    document.addEventListener('marino:authenticated', () => setTimeout(load, 250));
    setInterval(() => { if (state.loaded) render(); }, 30000);
  }

  window.MarinoClaimMining = Object.freeze({ load, sync: () => { if (!state.loaded) load(); else render(); }, state: () => ({ ...state, requests: [...state.requests] }) });
  if (document.readyState === 'loading') document.addEventListener('DOMContentLoaded', bind, { once: true }); else bind();
})();
