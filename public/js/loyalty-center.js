(() => {
  'use strict';

  const CLAIM_COSTS = Object.freeze({ free_spin: 30, free_bet: 45 });
  const REWARD_CATALOG = Object.freeze([
    { catalog_code: 'free_spin_1', reward_type: 'free_spin', display_name: '1 Free Spin', amount: 1, cost_claim_coin: 30, active: true },
    { catalog_code: 'free_spin_3', reward_type: 'free_spin', display_name: '3 Free Spin', amount: 3, cost_claim_coin: 84, active: true },
    { catalog_code: 'free_spin_5', reward_type: 'free_spin', display_name: '5 Free Spin', amount: 5, cost_claim_coin: 135, active: true },
    { catalog_code: 'free_bet_1', reward_type: 'free_bet', display_name: '1 Free Bet', amount: 1, cost_claim_coin: 45, active: true },
    { catalog_code: 'free_bet_3', reward_type: 'free_bet', display_name: '3 Free Bet', amount: 3, cost_claim_coin: 126, active: true }
  ]);
  const EQUIPMENT_CATALOG = Object.freeze([
    { item_key: 'steel_pickaxe', item_name: 'Çelik Kazma', description: 'Kazım başına +1 CC potansiyeli', icon: '⛏', cost_claim_coin: 40, required_lifetime_mined: 60, owned: false },
    { item_key: 'deep_scanner', item_name: 'Derin Tarayıcı', description: 'Bekleme süresini 2 dakika azaltır', icon: '⌁', cost_claim_coin: 90, required_lifetime_mined: 180, owned: false },
    { item_key: 'diamond_drill', item_name: 'Elmas Matkap', description: 'Kazım başına +2 CC potansiyeli', icon: '◆', cost_claim_coin: 220, required_lifetime_mined: 500, owned: false },
    { item_key: 'quantum_rig', item_name: 'Kuantum Sondajı', description: '+3 CC ve 4 dakika hız', icon: '⚙', cost_claim_coin: 600, required_lifetime_mined: 1200, owned: false }
  ]);
  const ACTIVITY_TASKS = Object.freeze([
    { task_key: 'agent_connection', task_name: 'Ajan Bağlantısı', description: 'Telegram botunu başlat ve hesabını eşleştir.', task_type: 'onboarding', reward_claim_coin: 3, goal: 1, progress: 0 },
    { task_key: 'account_2fa', task_name: 'Kasayı Sağlama Al', description: 'SMS 2FA özelliğini etkinleştir.', task_type: 'security', reward_claim_coin: 5, goal: 1, progress: 0 },
    { task_key: 'daily_safe_checkin', task_name: 'Günün İlk Kontrolü', description: 'Günlük hesap güvenliği kontrolünü tamamla.', task_type: 'daily', reward_claim_coin: 1, goal: 1, progress: 0 },
    { task_key: 'seven_day_checkin', task_name: '7 Günlük İstikrar', description: 'Yedi günlük güvenli giriş kontrolünü tamamla.', task_type: 'weekly', reward_claim_coin: 10, goal: 7, progress: 0 }
  ]);
  const state = {
    loaded: false,
    loading: false,
    profile: null,
    wallet: { claim_coin: 0, lifetime_mined: 0, mined_today: 0, next_mine_at: null, daily_cap: 18 },
    requests: [], rewardCatalog: REWARD_CATALOG, equipmentCatalog: EQUIPMENT_CATALOG, activityTasks: ACTIVITY_TASKS,
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
      rewardCatalog: REWARD_CATALOG.map(item => ({ ...item })), equipmentCatalog: EQUIPMENT_CATALOG.map(item => ({ ...item })), activityTasks: ACTIVITY_TASKS.map(item => ({ ...item })),
      requests: [
        { id: 'preview-1', reward_type: 'free_spin', amount: 1, cost_claim_coin: 30, status: 'pending', site_username: 'kaanbm', created_at: new Date().toISOString() }
      ]
    };
    return {
      player(action, payload = {}) {
        if (action === 'state') return { ok: true, profile: preview.profile, wallet: preview.wallet, requests: preview.requests, reward_catalog: preview.rewardCatalog, equipment_catalog: preview.equipmentCatalog, activity_tasks: preview.activityTasks, server_time: new Date().toISOString() };
        if (action === 'bind_site_username') {
          if (preview.profile?.site_username) throw Error('site_username_admin_only');
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
        if (action === 'buy_mining_item') {
          const item = preview.equipmentCatalog.find(entry => entry.item_key === payload.item_key);
          if (!item || item.owned || preview.wallet.lifetime_mined < item.required_lifetime_mined || preview.wallet.claim_coin < item.cost_claim_coin) throw Error('item_locked');
          preview.wallet.claim_coin -= item.cost_claim_coin; item.owned = true; return this.player('state');
        }
        if (action === 'claim_activity_reward') {
          const task = preview.activityTasks.find(entry => entry.task_key === payload.task_key);
          if (!task?.verified || task.claimed) throw Error('task_not_verified');
          task.claimed = true; preview.wallet.claim_coin += task.reward_claim_coin; return this.player('state');
        }
        if (action === 'create_reward_claim') {
          const item = preview.rewardCatalog.find(entry => entry.catalog_code === payload.catalog_code && entry.active);
          if (!item) throw Error('reward_not_found');
          const { reward_type: rewardType, amount, cost_claim_coin: cost } = item;
          if (preview.wallet.claim_coin < cost) throw Error('insufficient_claim_coin');
          preview.wallet.claim_coin -= cost;
          preview.requests.unshift({ id: uuid(), reward_type: rewardType, amount, cost_claim_coin: cost, status: 'pending', site_username: preview.profile.site_username, created_at: new Date().toISOString() });
          return this.player('state');
        }
        return { ok: false };
      },
      admin(action, payload = {}) {
        if (action === 'claims_list') return { ok: true, items: preview.requests };
        if (action === 'catalog_list') return { ok: true, rewards: preview.rewardCatalog, tasks: preview.activityTasks };
        if (action === 'reward_catalog_update') { const item=preview.rewardCatalog.find(entry=>entry.catalog_code===payload.catalog_code);if(item){item.cost_claim_coin=Number(payload.cost_claim_coin);item.active=payload.active!==false}return {ok:true,item} }
        if (action === 'site_account_update') { if(preview.profile?.site_username===payload.current_site_username)preview.profile.site_username=payload.new_site_username;preview.requests.forEach(item=>{if(item.site_username===payload.current_site_username)item.site_username=payload.new_site_username});return {ok:true} }
        if (action === 'activity_task_verify') { const task=preview.activityTasks.find(entry=>entry.task_key===payload.task_key);if(task){task.progress=Math.min(task.goal,Number(payload.progress));task.verified=task.progress>=task.goal}return {ok:true} }
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
      state.rewardCatalog = Array.isArray(data?.reward_catalog) ? data.reward_catalog : REWARD_CATALOG;
      state.equipmentCatalog = Array.isArray(data?.equipment_catalog) ? data.equipment_catalog : EQUIPMENT_CATALOG;
      state.activityTasks = Array.isArray(data?.activity_tasks) ? data.activity_tasks : ACTIVITY_TASKS;
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
      const data = await bridge().invoke('create_reward_claim', { catalog_code: rewardType }, uuid());
      state.wallet = data?.wallet || state.wallet;
      state.requests = Array.isArray(data?.requests) ? data.requests : state.requests;
      bridge()?.toast?.('Talep yetkili paneline gönderildi.');
      render();
    } catch {
      bridge()?.toast?.('Talep oluşturulamadı. Claim Coin bakiyeni ve limitleri kontrol et.');
    }
  }

  async function buyEquipment(itemKey) {
    try { const data=await bridge().invoke('buy_mining_item',{item_key:itemKey},uuid());syncData(data);bridge()?.toast?.('Mining ekipmanı satın alındı.');render() }
    catch { bridge()?.toast?.('Ekipman açılamadı. Claim Coin ve toplam kazım şartını kontrol et.') }
  }

  async function claimActivity(taskKey) {
    try { const data=await bridge().invoke('claim_activity_reward',{task_key:taskKey},uuid());syncData(data);bridge()?.toast?.('Doğrulanmış görev ödülü alındı.');render() }
    catch { bridge()?.toast?.('Görev henüz site veya yönetici tarafından doğrulanmadı.') }
  }

  function syncData(data) {
    state.profile=data?.profile||state.profile; state.wallet=data?.wallet||state.wallet;
    state.requests=Array.isArray(data?.requests)?data.requests:state.requests;
    state.rewardCatalog=Array.isArray(data?.reward_catalog)?data.reward_catalog:state.rewardCatalog;
    state.equipmentCatalog=Array.isArray(data?.equipment_catalog)?data.equipment_catalog:state.equipmentCatalog;
    state.activityTasks=Array.isArray(data?.activity_tasks)?data.activity_tasks:state.activityTasks;
  }

  function requestRows() {
    if (!state.requests.length) return '<p class="claim-empty">Henüz talep yok. Claim Coin kaz ve ilk talebini aç.</p>';
    const labels = { free_spin: 'Free Spin', free_bet: 'Free Bet' };
    return state.requests.slice(0, 4).map(item => `<div class="claim-request-row"><span>${escape(labels[item.reward_type] || item.reward_type)} x${Number(item.amount || 1)}</span><b class="status-${escape(item.status)}">${escape(item.status)}</b></div>`).join('');
  }

  function goalRows() {
    const goals = [
      ['Site üyeliğini bağla', Boolean(state.profile?.site_username)],
      ['İlk Claim Coin kazımını tamamla', Number(state.wallet?.lifetime_mined || 0) > 0],
      ['Toplam 10 Claim Coin kaz', Number(state.wallet?.lifetime_mined || 0) >= 10],
      ['Free Spin veya Free Bet talebi aç', state.requests.length > 0]
    ];
    return goals.map(([label, done]) => `<div class="claim-goal-row ${done ? 'is-done' : ''}"><span>${done ? '&#10003;' : '&#9675;'}</span><b>${escape(label)}</b></div>`).join('');
  }

  function equipmentRows() {
    const balance=Number(state.wallet?.claim_coin||0),lifetime=Number(state.wallet?.lifetime_mined||0);
    return state.equipmentCatalog.map(item=>{const locked=lifetime<Number(item.required_lifetime_mined||0),disabled=item.owned||locked||balance<Number(item.cost_claim_coin||0);return `<article class="claim-equipment ${item.owned?'is-owned':''}"><i>${escape(item.icon||'⛏')}</i><div><b>${escape(item.item_name)}</b><small>${escape(item.description)}</small><em>${locked?`${fmt(item.required_lifetime_mined)} toplam kazım gerekli`:`${fmt(item.cost_claim_coin)} CC`}</em></div><button type="button" data-claim-equipment="${escape(item.item_key)}" ${disabled?'disabled':''}>${item.owned?'ALINDI':locked?'KİLİTLİ':'SATIN AL'}</button></article>`}).join('');
  }

  function activityRows() {
    return state.activityTasks.map(task=>{const progress=Math.min(Number(task.progress||0),Number(task.goal||1)),ready=Boolean(task.verified)&&!task.claimed;return `<article class="claim-activity ${task.claimed?'is-done':''}"><div><span>${escape(task.task_type)}</span><b>${escape(task.task_name)}</b><p>${escape(task.description)}</p><div class="claim-activity-progress"><i style="width:${Math.min(100,progress/Number(task.goal||1)*100)}%"></i></div><small>${progress}/${Number(task.goal||1)} · +${fmt(task.reward_claim_coin)} CC</small></div><button type="button" data-claim-activity="${escape(task.task_key)}" ${ready?'':'disabled'}>${task.claimed?'ALINDI':ready?'ÖDÜLÜ AL':'DOĞRULAMA'}</button></article>`}).join('');
  }

  function rewardRows(username,balance) {
    return state.rewardCatalog.filter(item=>item.active!==false).map(item=>`<button type="button" data-claim-request="${escape(item.catalog_code)}" ${balance>=Number(item.cost_claim_coin)&&username?'':'disabled'}><b>${escape(item.display_name)}</b><small>${fmt(item.cost_claim_coin)} CC</small></button>`).join('');
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
        ${username?'<span class="claim-admin-lock">Yalnız yönetici düzeltebilir</span>':'<button type="button" data-claim-bind>Bağla</button>'}
      </div>
      <div class="claim-mining-stats">
        <div><small>Bugün</small><b>${fmt(state.wallet?.mined_today || 0)} / ${fmt(state.wallet?.daily_cap || 18)}</b></div>
        <div><small>Sonraki kazım</small><b>${nextText()}</b></div>
        <div><small>Toplam</small><b>${fmt(state.wallet?.lifetime_mined || 0)}</b></div>
      </div>
      <button type="button" class="claim-mine-button" data-claim-mine ${username ? '' : 'disabled'}>⛏️ Claim Coin Kaz</button>
      <div class="claim-goals"><h4>Mining Hedefleri</h4>${goalRows()}</div>
      <section class="claim-section"><h4>Mining Ekipmanları</h4><p>Geliştirmeler Claim Coin ve toplam kazım şartı ister.</p><div class="claim-equipment-list">${equipmentRows()}</div></section>
      <section class="claim-section"><h4>Doğrulanan Görevler</h4><p>Ödül yalnız site veya yönetici doğrulamasından sonra açılır.</p><div class="claim-activity-list">${activityRows()}</div></section>
      <section class="claim-section"><h4>Free Spin / Free Bet Fiyatları</h4><div class="claim-reward-grid">${rewardRows(username,balance)}</div></section>
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
      if (event.target.closest('#btnOpenClaimMining')) {
        q('.nav-btn[data-tab="store"]')?.click();
        setTimeout(() => { if (state.loaded) render(); else load(); q('#claimMiningMount')?.scrollIntoView({ behavior: 'smooth', block: 'start' }); }, 80);
        return;
      }
      if (event.target.closest('[data-claim-bind]')) return maybePromptUsername(true);
      if (event.target.closest('[data-claim-mine]')) return mine();
      const request = event.target.closest('[data-claim-request]');
      if (request) return requestReward(request.dataset.claimRequest);
      const equipment=event.target.closest('[data-claim-equipment]');if(equipment)return buyEquipment(equipment.dataset.claimEquipment);
      const activity=event.target.closest('[data-claim-activity]');if(activity)return claimActivity(activity.dataset.claimActivity);
      if (event.target.closest('[data-claim-username-save]')) return bindUsername(q('#claimUsernameInput')?.value || '');
      if (event.target.closest('[data-claim-username-later]')) return closePrompt();
    });
    document.addEventListener('marino:authenticated', () => setTimeout(load, 250));
    document.addEventListener('marino:app-ready', () => setTimeout(load, 0));
    if (bridge()?.preview) setTimeout(load, 0);
    setInterval(() => { if (state.loaded) render(); }, 30000);
  }

  window.MarinoClaimMining = Object.freeze({ load, sync: () => { if (!state.loaded) load(); else render(); }, state: () => ({ ...state, requests: [...state.requests] }) });
  if (document.readyState === 'loading') document.addEventListener('DOMContentLoaded', bind, { once: true }); else bind();
})();
