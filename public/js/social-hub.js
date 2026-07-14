(() => {
  'use strict';

  const state = {
    open: false, ready: false, loading: false, tab: 'general', recipientCode: null,
    profile: null, messages: new Map(), oldest: null, pollTimer: null, failures: 0,
    friends: [], requests: [], catalog: [], inventory: null
  };
  const q = selector => document.querySelector(selector);
  const bridge = () => window.MarinoSocialBridge;
  const invoke = (action, payload = {}, requestId = null) => bridge().invoke(action, payload, requestId);
  const notify = message => bridge()?.toast?.(message);
  const safeCode = value => String(value || '').trim().toUpperCase().replace(/[^A-F0-9]/g, '').slice(0, 3);
  const requestId = () => crypto.randomUUID();

  function setStatus(message, kind = '') {
    const node = q('#socialStatus');
    if (!node) return;
    node.textContent = message;
    node.className = `social-status ${kind}`.trim();
  }

  function formatTime(value) {
    const date = new Date(value);
    return Number.isNaN(date.getTime()) ? '' : date.toLocaleTimeString('tr-TR', { hour: '2-digit', minute: '2-digit' });
  }

  function emptyNode(message) {
    const node = document.createElement('div');
    node.className = 'social-empty';
    node.textContent = message;
    return node;
  }

  function messageNode(message) {
    const article = document.createElement('article');
    article.className = `social-message${message.own ? ' own' : ''}${message.kind === 'gift' ? ' gift' : ''}`;
    article.dataset.messageId = String(message.id);
    const head = document.createElement('div'); head.className = 'social-message-head';
    const alias = document.createElement('span'); alias.className = 'social-message-alias'; alias.textContent = String(message.alias || 'Oyuncu');
    const time = document.createElement('time'); time.className = 'social-message-time'; time.dateTime = String(message.created_at || ''); time.textContent = formatTime(message.created_at);
    const body = document.createElement('div'); body.className = 'social-message-body'; body.textContent = String(message.body || '');
    const menu = document.createElement('button'); menu.type = 'button'; menu.className = 'social-message-menu'; menu.textContent = '⋯'; menu.setAttribute('aria-label', 'Mesaj işlemleri');
    menu.addEventListener('click', () => openMessageMenu(message));
    head.append(alias, time); article.append(head, body, menu);
    return article;
  }

  function renderMessages({ preserveBottom = false } = {}) {
    const list = q('#socialMessageList');
    if (!list) return;
    const nearBottom = preserveBottom || list.scrollHeight - list.scrollTop - list.clientHeight < 72;
    const sorted = [...state.messages.values()].sort((a, b) => new Date(a.created_at) - new Date(b.created_at));
    list.replaceChildren(...(sorted.length ? sorted.map(messageNode) : [emptyNode('Henüz mesaj yok. İlk güvenli mesajı sen gönder.') ]));
    if (nearBottom) list.scrollTop = list.scrollHeight;
    else q('#socialNewMessages').hidden = false;
    state.oldest = sorted[0]?.created_at || null;
  }

  function mergeMessages(items, older = false) {
    let added = 0;
    for (const message of Array.isArray(items) ? items : []) {
      if (!message?.id || state.messages.has(message.id)) continue;
      state.messages.set(message.id, message); added += 1;
    }
    if (added) renderMessages({ preserveBottom: older });
    return added;
  }

  async function loadHistory({ older = false, quiet = false } = {}) {
    if (state.loading || !['general', 'league'].includes(state.tab) && !state.recipientCode) return;
    state.loading = true;
    try {
      const payload = { channel: state.tab === 'friends' ? 'private' : state.tab, limit: older ? 50 : 100 };
      if (state.tab === 'friends') payload.recipient_code = state.recipientCode;
      if (older && state.oldest) payload.before = state.oldest;
      const rows = await invoke('history', payload);
      const count = mergeMessages(rows, older);
      state.failures = 0;
      setStatus(state.tab === 'league' ? `● ${state.profile.league.toUpperCase()} ligi · güvenli` : '● Güvenli bağlantı', 'online');
      if (older && !count) notify('Daha eski mesaj yok.');
    } catch (error) {
      state.failures += 1;
      setStatus('Bağlantı kesildi · yeniden deneniyor', 'error');
      if (!quiet) notify('Sohbet yüklenemedi.');
    } finally { state.loading = false; }
  }

  function schedulePoll() {
    clearTimeout(state.pollTimer);
    if (!state.open) return;
    const delay = Math.min(15000, 3000 * Math.max(1, state.failures));
    state.pollTimer = setTimeout(async () => {
      if (document.visibilityState === 'visible' && ['general', 'league', 'friends'].includes(state.tab)) await loadHistory({ quiet: true });
      schedulePoll();
    }, delay);
  }

  async function sendMessage(event) {
    event.preventDefault();
    const input = q('#socialMessageInput'); const button = q('#socialSend');
    const body = input.value.trim();
    if (!body) return;
    if (state.tab === 'friends' && !state.recipientCode) return notify('Önce bir arkadaşla sohbet aç.');
    button.disabled = true;
    try {
      const result = await invoke('send', { channel: state.tab === 'friends' ? 'private' : state.tab, body, recipient_code: state.recipientCode });
      if (!result?.ok) return notify(result?.error === 'rate_limited' ? 'Çok hızlı gönderim yaptın. Geçici olarak susturuldun.' : 'Mesaj reddedildi.');
      input.value = ''; updateCounter();
      mergeMessages([{ id: result.message_id, alias: result.alias, social_code: state.profile.social_code, body: result.body, channel: result.channel, kind: 'text', created_at: result.created_at, own: true }]);
    } catch (error) { notify(friendlyError(error)); }
    finally { button.disabled = false; }
  }

  function friendlyError(error) {
    const text = String(error?.message || '');
    if (text.includes('new_account_read_only')) return 'Yeni hesaplar ilk 10 dakika yalnız okuyabilir.';
    if (text.includes('chat_muted')) return 'Sohbet hesabın geçici olarak susturulmuş.';
    if (text.includes('chat_banned')) return 'Sohbet erişimin kapalı.';
    if (text.includes('insufficient_coin')) return 'Yeterli Marino Coin yok.';
    if (text.includes('daily_gift_limit')) return 'Günlük hediye limitine ulaştın.';
    if (text.includes('recipient_daily_gift_limit')) return 'Bu oyuncuya günlük hediye limitine ulaştın.';
    if (text.includes('authentication_required')) return 'Oturum yenilenemedi. Oyunu Telegram üzerinden yeniden aç.';
    return 'İşlem sunucu tarafından onaylanmadı.';
  }

  function updateCounter() {
    const input = q('#socialMessageInput');
    q('#socialCharCount').textContent = `${input.value.length}/160`;
    input.style.height = 'auto'; input.style.height = `${Math.min(84, input.scrollHeight)}px`;
  }

  function addMenuButton(card, label, handler) {
    const button = document.createElement('button'); button.type = 'button'; button.textContent = label;
    button.addEventListener('click', async () => { card.parentElement?.remove(); await handler(); });
    card.append(button);
  }

  function openMessageMenu(message) {
    const overlay = document.createElement('div'); overlay.className = 'social-menu';
    const card = document.createElement('div'); card.className = 'social-menu-card'; overlay.append(card);
    if (message.own) addMenuButton(card, 'Mesajı sil', async () => { await invoke('delete_own', { message_id: message.id }); state.messages.delete(message.id); renderMessages(); });
    else {
      addMenuButton(card, 'Hediye gönder', () => openGifts(message.social_code));
      addMenuButton(card, 'Oyuncuyu engelle', async () => { if (!confirm('Bu oyuncuyu engellemek istiyor musun?')) return; await invoke('block', { social_code: message.social_code }); state.messages.delete(message.id); renderMessages(); notify('Oyuncu engellendi.'); });
      addMenuButton(card, 'Mesajı şikâyet et', () => reportMessage(message.id));
    }
    addMenuButton(card, 'Kapat', async () => {});
    overlay.addEventListener('click', event => { if (event.target === overlay) overlay.remove(); });
    document.body.append(overlay);
  }

  async function reportMessage(messageId) {
    const reason = prompt('Neden: contact_info, insult, harassment, spam, fraud, inappropriate, other', 'spam');
    if (!reason) return;
    try { await invoke('report', { message_id: messageId, reason }); notify('Şikâyetin güvenli biçimde alındı.'); }
    catch { notify('Şikâyet gönderilemedi veya daha önce gönderildi.'); }
  }

  function cardNode(title, subtitle, actions = []) {
    const card = document.createElement('div'); card.className = 'social-card';
    const main = document.createElement('div'); main.className = 'social-card-main';
    const t = document.createElement('div'); t.className = 'social-card-title'; t.textContent = title;
    const s = document.createElement('div'); s.className = 'social-card-sub'; s.textContent = subtitle;
    main.append(t, s); card.append(main);
    const area = document.createElement('div'); area.className = 'social-card-actions';
    actions.forEach(({ label, run, secondary }) => { const b = document.createElement('button'); b.type = 'button'; b.textContent = label; if (secondary) b.className = 'secondary'; b.addEventListener('click', run); area.append(b); });
    card.append(area); return card;
  }

  async function loadFriends() {
    try {
      const data = await invoke('friends'); state.friends = data.friends || []; state.requests = data.requests || [];
      const requests = q('#socialFriendRequests'); const friends = q('#socialFriendList');
      const requestTitle = document.createElement('h3'); requestTitle.className = 'social-section-title'; requestTitle.textContent = 'Bekleyen istekler';
      requests.replaceChildren(requestTitle, ...(state.requests.length ? state.requests.map(item => cardNode(item.alias, `#${item.social_code}`, [
        { label: 'Kabul', run: () => resolveFriend('friend_accept', item.request_id) }, { label: 'Reddet', secondary: true, run: () => resolveFriend('friend_reject', item.request_id) }
      ])) : [emptyNode('Bekleyen istek yok.') ]));
      const friendTitle = document.createElement('h3'); friendTitle.className = 'social-section-title'; friendTitle.textContent = 'Arkadaşlarım';
      friends.replaceChildren(friendTitle, ...(state.friends.length ? state.friends.map(item => cardNode(item.alias, `#${item.social_code}`, [
        { label: 'Sohbet', run: () => openPrivate(item.social_code, item.alias) }, { label: 'Kaldır', secondary: true, run: () => removeFriend(item.social_code) }
      ])) : [emptyNode('Henüz arkadaşın yok.') ]));
      const badge = q('#socialRequestBadge'); badge.hidden = !state.requests.length; badge.textContent = String(state.requests.length);
    } catch { notify('Arkadaş listesi yüklenemedi.'); }
  }

  async function resolveFriend(action, id) { try { await invoke(action, { request_id: id }); await loadFriends(); } catch { notify('İstek güncellenemedi.'); } }
  async function removeFriend(code) { if (!confirm('Arkadaşlığı kaldırmak istiyor musun?')) return; try { await invoke('friend_remove', { social_code: code }); await loadFriends(); } catch { notify('Arkadaşlık kaldırılamadı.'); } }
  function openPrivate(code, alias) { state.recipientCode = safeCode(code); switchTab('friends'); state.messages.clear(); renderMessages(); setStatus(`${alias} ile özel sohbet`, 'online'); loadHistory(); }

  function giftNode(gift, targetCode) {
    const card = document.createElement('div'); card.className = 'social-gift';
    const emoji = document.createElement('div'); emoji.className = 'social-gift-emoji'; emoji.textContent = gift.emoji;
    const name = document.createElement('div'); name.className = 'social-gift-name'; name.textContent = gift.name;
    const price = document.createElement('div'); price.className = 'social-gift-price'; price.textContent = `${Number(gift.price).toLocaleString('tr-TR')} Coin`;
    const button = document.createElement('button'); button.type = 'button'; button.textContent = 'Gönder'; button.addEventListener('click', () => sendGift(gift, targetCode));
    card.append(emoji, name, price, button); return card;
  }

  async function openGifts(targetCode = null) {
    if (targetCode) state.recipientCode = safeCode(targetCode);
    switchTab('gifts');
    try {
      const [catalog, inventory] = await Promise.all([invoke('gift_catalog'), invoke('gift_inventory')]);
      state.catalog = catalog.items || []; state.inventory = inventory;
      const summary = q('#socialGiftSummary'); summary.className = 'social-gift-summary';
      summary.textContent = `Bakiye: ${bridge().coinBalance().toLocaleString('tr-TR')} Coin · Kalan günlük gönderim: ${Math.max(0, catalog.daily_limit - catalog.sent_today)} · Alınan: ${inventory.gifts_received} · Sosyal prestij: ${inventory.prestige_points}`;
      q('#socialGiftCatalog').replaceChildren(...state.catalog.map(gift => giftNode(gift, state.recipientCode)));
    } catch { notify('Hediye kataloğu yüklenemedi.'); }
  }

  async function sendGift(gift, presetCode) {
    const code = safeCode(presetCode || prompt('Hediyeyi göndereceğin sosyal kod', state.recipientCode || ''));
    if (code.length !== 3) return notify('Geçerli 3 haneli sosyal kod gir.');
    if (!confirm(`${gift.name} hediyesi için ${Number(gift.price).toLocaleString('tr-TR')} Coin harcansın mı?`)) return;
    try {
      const result = await invoke('gift_send', { recipient_code: code, gift_key: gift.key }, requestId());
      if (result?.coin_balance !== undefined) bridge().applyCoinBalance(result.coin_balance);
      notify(result?.idempotent ? 'Bu hediye daha önce işlendi.' : 'Hediye gönderildi.'); await openGifts(code);
    } catch (error) { notify(friendlyError(error)); }
  }

  function switchTab(tab) {
    state.tab = tab;
    document.querySelectorAll('[data-social-tab]').forEach(button => button.classList.toggle('active', button.dataset.socialTab === tab));
    q('#socialChatPanel').hidden = !['general', 'league'].includes(tab) && !(tab === 'friends' && state.recipientCode);
    q('#socialFriendsPanel').hidden = tab !== 'friends' || Boolean(state.recipientCode);
    q('#socialGiftsPanel').hidden = tab !== 'gifts';
    if (['general', 'league'].includes(tab)) { state.recipientCode = null; state.messages.clear(); renderMessages(); loadHistory(); }
    if (tab === 'friends' && !state.recipientCode) loadFriends();
  }

  async function bootstrap() {
    if (state.ready) return true;
    try {
      state.profile = await invoke('bootstrap'); state.ready = true;
      q('#socialMuteToggle').textContent = state.profile.notifications_enabled ? '🔔' : '🔕';
      setStatus(`● ${state.profile.alias} · #${state.profile.social_code}`, 'online');
      return true;
    } catch { setStatus('Sosyal merkez doğrulanamadı', 'error'); return false; }
  }

  async function open() { state.open = true; if (await bootstrap()) { switchTab(state.tab); schedulePoll(); } }
  function close() { state.open = false; clearTimeout(state.pollTimer); }

  function bind() {
    q('#socialComposer')?.addEventListener('submit', sendMessage);
    q('#socialMessageInput')?.addEventListener('input', updateCounter);
    q('#socialLoadOlder')?.addEventListener('click', () => loadHistory({ older: true }));
    q('#socialNewMessages')?.addEventListener('click', () => { const list = q('#socialMessageList'); list.scrollTop = list.scrollHeight; q('#socialNewMessages').hidden = true; });
    q('#socialGiftShortcut')?.addEventListener('click', () => openGifts(state.recipientCode));
    document.querySelectorAll('[data-social-tab]').forEach(button => button.addEventListener('click', () => {
      state.recipientCode = null;
      if (button.dataset.socialTab === 'gifts') openGifts();
      else switchTab(button.dataset.socialTab);
    }));
    q('#socialFriendForm')?.addEventListener('submit', async event => { event.preventDefault(); const code = safeCode(q('#socialCodeInput').value); if (code.length !== 3) return notify('Geçerli sosyal kod gir.'); try { await invoke('friend_request', { social_code: code }); q('#socialCodeInput').value = ''; notify('Arkadaşlık isteği gönderildi.'); } catch { notify('Arkadaşlık isteği gönderilemedi.'); } });
    q('#socialMuteToggle')?.addEventListener('click', async () => { const enabled = !state.profile.notifications_enabled; try { await invoke('set_notifications', { enabled }); state.profile.notifications_enabled = enabled; q('#socialMuteToggle').textContent = enabled ? '🔔' : '🔕'; } catch { notify('Bildirim tercihi kaydedilemedi.'); } });
    document.addEventListener('visibilitychange', () => { if (document.visibilityState === 'visible' && state.open) { loadHistory({ quiet: true }); schedulePoll(); } });
  }

  window.MarinoSocialPreview = {
    invoke: async action => {
      if (action === 'bootstrap') return { alias: 'M*** #4F2', social_code: '4F2', league: 'emperor', notifications_enabled: true };
      if (action === 'history') return [{ id: 'preview-1', alias: 'A*** #8C1', social_code: '8C1', body: 'Marino sosyal merkezine hoş geldin!', kind: 'text', created_at: new Date().toISOString(), own: false }];
      if (action === 'friends') return { friends: [{ alias: 'A*** #8C1', social_code: '8C1' }], requests: [] };
      if (action === 'gift_catalog') return { items: [{ key: 'coffee', name: 'Kahve', emoji: '☕', price: 10000, prestige: 10 }], sent_today: 0, daily_limit: 10 };
      if (action === 'gift_inventory') return { gifts_received: 3, prestige_points: 30 };
      return { ok: true };
    }
  };

  window.MarinoSocial = { open, close };
  if (document.readyState === 'loading') document.addEventListener('DOMContentLoaded', bind, { once: true }); else bind();
})();
