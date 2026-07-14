(() => {
  'use strict';

  const q = selector => document.querySelector(selector);
  const state = { client: null, session: null, role: null, items: [], audit: [], view: 'list', editing: null };
  const uuid = () => crypto.randomUUID();
  const message = (target, text, error = false) => {
    const el = q(target);
    if (el) {
      el.textContent = text;
      el.style.color = error ? '#ff8291' : '';
    }
  };
  const rpc = async (name, args = {}) => {
    if (!state.client) throw Error('client_unavailable');
    const { data, error } = await state.client.rpc(name, args);
    if (error) throw Object.assign(Error(error.code || 'request_rejected'), { code: error.code });
    return data;
  };
  const allowed = (...roles) => roles.includes(state.role);
  const input = selector => q(selector);
  const setValue = (selector, value) => { const el = input(selector); if (el) el.value = value ?? ''; };
  const getValue = selector => input(selector)?.value ?? '';

  const QUICK_PRESETS = Object.freeze({
    combo: {
      label: 'Daily Combo',
      type: 'daily_combo',
      titleTr: 'Günün Combo’su',
      titleEn: 'Daily Combo',
      descTr: 'Üç kartı doğru sırayla seç ve ödülü al.',
      descEn: 'Pick the three cards in the correct order and claim the reward.',
      rewardType: 'reward_point',
      rewardAmount: 50,
      normalization: 'json_exact',
      durationHours: 24,
    },
    cipher: {
      label: 'Daily Şifre',
      type: 'daily_cipher',
      titleTr: 'Günün Şifresi',
      titleEn: 'Daily Cipher',
      descTr: 'Şifreyi çöz ve ödülü al.',
      descEn: 'Decode the cipher and claim the reward.',
      rewardType: 'reward_point',
      rewardAmount: 40,
      normalization: 'nfkc_upper_trim',
      durationHours: 24,
    },
    code: {
      label: 'Kod Paylaş',
      type: 'daily_cipher',
      titleTr: 'Günün Kodu',
      titleEn: 'Daily Code',
      descTr: 'Ekrandaki kodu gir ve ödülü al.',
      descEn: 'Enter the displayed code and claim the reward.',
      rewardType: 'reward_point',
      rewardAmount: 25,
      normalization: 'nfkc_upper_trim',
      durationHours: 24,
    },
    event: {
      label: 'Etkinlik',
      type: 'special_event',
      titleTr: 'Özel Etkinlik',
      titleEn: 'Special Event',
      descTr: 'Sınırlı süreli etkinlik yayında.',
      descEn: 'A limited-time event is live.',
      rewardType: 'reward_point',
      rewardAmount: 100,
      normalization: 'nfkc_lower_trim',
      durationHours: 72,
    },
  });

  function isoInput(value) {
    if (!value) return '';
    const date = new Date(value);
    return new Date(date.getTime() - date.getTimezoneOffset() * 60000).toISOString().slice(0, 16);
  }

  function addHours(hours) {
    return isoInput(new Date(Date.now() + Number(hours || 0) * 3600000));
  }

  function parsePayload() {
    let payload;
    try {
      payload = JSON.parse(q('#contentPayload').value || '{}');
    } catch (_) {
      throw Error('Payload geçerli JSON olmalı.');
    }
    if (!payload || Array.isArray(payload) || typeof payload !== 'object') throw Error('Payload JSON nesnesi olmalı.');
    const text = JSON.stringify(payload);
    if (/"(answer|solution|correct_answer|combo_order|cipher_answer)"\s*:/i.test(text)) throw Error('Doğru cevap public payload içinde bulunamaz.');
    return payload;
  }

  function documentFromForm() {
    const rewardType = q('#rewardType').value;
    const rewardAmount = Number(q('#rewardAmount').value || 0);
    return {
      content_type: q('#contentType').value,
      status: q('#contentStatus').value,
      title_tr: q('#titleTr').value.trim(),
      title_en: q('#titleEn').value.trim(),
      description_tr: q('#descriptionTr').value.trim(),
      description_en: q('#descriptionEn').value.trim(),
      starts_at: new Date(q('#startsAt').value).toISOString(),
      ends_at: new Date(q('#endsAt').value).toISOString(),
      reward_type: rewardType,
      reward_amount: rewardType === 'none' ? 0 : rewardAmount,
      answer_normalization: q('#answerNormalization').value,
      payload: parsePayload(),
    };
  }

  function setWorkspace(enabled) {
    q('#adminGate').hidden = enabled;
    q('#adminWorkspace').hidden = !enabled;
    q('#adminSignOut').hidden = !enabled;
  }

  function renderStats() {
    const attempts = state.items.reduce((sum, item) => sum + Number(item.attempt_count || 0), 0);
    const correct = state.items.reduce((sum, item) => sum + Number(item.correct_count || 0), 0);
    const claims = state.items.reduce((sum, item) => sum + Number(item.claim_count || 0), 0);
    q('#statContent').textContent = state.items.length;
    q('#statAttempts').textContent = attempts;
    q('#statSuccess').textContent = attempts ? `${Math.round(correct / attempts * 100)}%` : '0%';
    q('#statClaims').textContent = claims;
  }

  function escapeHtml(value) {
    return String(value ?? '').replace(/[&<>"']/g, char => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[char]));
  }

  function card(item) {
    const edit = allowed('editor', 'publisher', 'super_admin');
    return `<article class="ops-card"><div><span class="ops-status ${item.status}">${item.status.toUpperCase()}</span><h3>${escapeHtml(item.title_tr)}</h3><p>${escapeHtml(item.content_type)} • ${new Date(item.starts_at).toLocaleString('tr-TR')} → ${new Date(item.ends_at).toLocaleString('tr-TR')}</p><small>${item.reward_type}: ${item.reward_amount} • v${item.version} • ${item.attempt_count || 0} deneme • ${item.claim_count || 0} claim</small></div><div class="ops-card-actions"><button type="button" data-edit-content="${item.id}" ${edit ? '' : 'disabled'}>Düzenle</button><button type="button" data-copy-content="${item.id}" ${edit ? '' : 'disabled'}>Kopyala</button></div></article>`;
  }

  function renderList() {
    q('#adminList').innerHTML = state.items.length ? state.items.map(card).join('') : '<article class="ops-card">Henüz içerik yok.</article>';
  }

  function renderCalendar() {
    const groups = new Map();
    for (const item of state.items) {
      const key = new Date(item.starts_at).toISOString().slice(0, 10);
      if (!groups.has(key)) groups.set(key, []);
      groups.get(key).push(item);
    }
    q('#adminCalendar').innerHTML = [...groups.entries()].slice(0, 35).map(([day, items]) => `<article class="ops-day"><b>${day}</b>${items.map(item => `<button type="button" data-edit-content="${item.id}">${escapeHtml(item.title_tr)}<small>${item.status}</small></button>`).join('')}</article>`).join('') || '<article class="ops-day">Plan yok</article>';
  }

  function renderAudit() {
    q('#adminAudit').innerHTML = state.audit.map(item => `<article class="ops-card"><div><span class="ops-status">${escapeHtml(item.action)}</span><h3>${escapeHtml(item.entity_type)}</h3><small>${new Date(item.created_at).toLocaleString('tr-TR')} • ${escapeHtml(item.entity_id || '')}</small></div></article>`).join('') || '<article class="ops-card">Audit kaydı yok.</article>';
  }

  function switchView(view) {
    state.view = view;
    for (const id of ['list', 'calendar', 'audit']) q(`#admin${id[0].toUpperCase() + id.slice(1)}`).hidden = id !== view;
    document.querySelectorAll('[data-admin-view]').forEach(button => button.classList.toggle('active', button.dataset.adminView === view));
    if (view === 'audit') loadAudit();
  }

  async function load() {
    const result = await rpc('admin_get_daily_content');
    state.role = result.role;
    state.items = result.items || [];
    q('#adminRole').textContent = state.role.replace('_', ' ').toUpperCase();
    setWorkspace(true);
    renderStats();
    renderList();
    renderCalendar();
  }

  async function loadAudit() {
    try {
      state.audit = await rpc('admin_get_content_audit', { p_limit: 100 }) || [];
      renderAudit();
    } catch (_) {
      q('#adminAudit').innerHTML = '<article class="ops-card">Audit okunamadı.</article>';
    }
  }

  function quickPanel() {
    let panel = q('#quickContentPanel');
    if (panel) return panel;
    panel = document.createElement('section');
    panel.id = 'quickContentPanel';
    panel.className = 'ops-quick-panel';
    panel.innerHTML = `<header><div><span>HIZLI YAYIN</span><h3>Yazmak yok, seç ve paylaş</h3></div><button type="button" data-quick-apply>Şablonu Doldur</button></header><div class="ops-quick-grid"><label>Şablon<select id="quickPreset">${Object.entries(QUICK_PRESETS).map(([key, item]) => `<option value="${key}">${item.label}</option>`).join('')}</select></label><label>Kod / Cevap<input id="quickCode" maxlength="64" placeholder="Örn: MARINO2026"></label><label>İpucu<input id="quickHint" maxlength="140" placeholder="Oyuncuya görünecek kısa ipucu"></label><label>Ödül<select id="quickReward"><option value="reward_point">MRP</option><option value="none">Ödülsüz</option><option value="cosmetic">Kozmetik</option></select></label><label>Miktar<input id="quickAmount" type="number" min="0" max="1000000" value="25"></label><label>Süre<select id="quickDuration"><option value="6">6 saat</option><option value="24" selected>24 saat</option><option value="48">48 saat</option><option value="72">72 saat</option><option value="168">1 hafta</option></select></label></div><p>Combo/Cipher doğru cevabı server’da hashlenir. Public payload içinde cevap anahtarı tutulmaz.</p>`;
    q('.ops-form-grid')?.before(panel);
    panel.addEventListener('change', event => { if (event.target.closest('#quickPreset')) syncQuickDefaults(); });
    panel.querySelector('[data-quick-apply]').addEventListener('click', applyQuickPreset);
    return panel;
  }

  function syncQuickDefaults() {
    const preset = QUICK_PRESETS[getValue('#quickPreset')] || QUICK_PRESETS.combo;
    setValue('#quickReward', preset.rewardType);
    setValue('#quickAmount', preset.rewardAmount);
    setValue('#quickDuration', preset.durationHours);
    if (!getValue('#quickCode')) setValue('#quickCode', preset.type === 'daily_combo' ? 'hotel-bank-casino' : preset.type === 'special_event' ? 'weekend_empire' : 'MARINO');
    if (!getValue('#quickHint')) setValue('#quickHint', preset.type === 'daily_combo' ? 'Gelir, güvenlik ve şans üçlüsü' : preset.type === 'daily_cipher' ? 'Bugünün özel kodu' : 'Sınırlı süreli etkinlik');
  }

  function comboCardsFrom(value) {
    return String(value || '').split(/[\s,>|\-]+/).map(item => item.trim()).filter(Boolean).slice(0, 3);
  }

  function applyQuickPreset() {
    const presetKey = getValue('#quickPreset');
    const preset = QUICK_PRESETS[presetKey] || QUICK_PRESETS.combo;
    const code = getValue('#quickCode').trim();
    const hint = getValue('#quickHint').trim();
    const rewardType = getValue('#quickReward') || preset.rewardType;
    const rewardAmount = rewardType === 'none' ? 0 : Number(getValue('#quickAmount') || preset.rewardAmount);
    const duration = Number(getValue('#quickDuration') || preset.durationHours);
    const now = new Date();
    const answer = preset.type === 'daily_combo' ? JSON.stringify(comboCardsFrom(code)) : code;
    const payload = buildQuickPayload(presetKey, preset, code, hint);

    setValue('#contentType', preset.type);
    setValue('#contentStatus', 'draft');
    setValue('#titleTr', preset.titleTr);
    setValue('#titleEn', preset.titleEn);
    setValue('#descriptionTr', preset.descTr);
    setValue('#descriptionEn', preset.descEn);
    setValue('#startsAt', isoInput(now));
    setValue('#endsAt', addHours(duration));
    setValue('#rewardType', rewardType);
    setValue('#rewardAmount', rewardAmount);
    setValue('#answerNormalization', preset.normalization);
    setValue('#contentAnswer', answer);
    setValue('#contentPayload', JSON.stringify(payload, null, 2));
    message('#editorMessage', 'Şablon dolduruldu. Kontrol edip Kaydet, sonra Yayınla.');
  }

  function buildQuickPayload(presetKey, preset, code, hint) {
    if (presetKey === 'combo') return { quick_template: 'daily_combo_cards', cards: comboCardsFrom(code), hint, display: 'cards' };
    if (presetKey === 'code') return { quick_template: 'visible_daily_code', display_code: code.toUpperCase(), hint, keyboard: 'alphanumeric', word_length: code.length };
    if (presetKey === 'cipher') return { quick_template: 'daily_cipher_text', morse: code.toUpperCase().split('').join(' '), word_length: code.length, hint, keyboard: /[0-9]/.test(code) ? 'alphanumeric' : 'letters' };
    return { quick_template: 'special_event', event_key: code.toLowerCase().replace(/[^a-z0-9_]+/g, '_').replace(/^_+|_+$/g, '') || 'special_event', banner: hint, theme: 'gold' };
  }

  function openEditor(item = null, copy = false) {
    if (!allowed('editor', 'publisher', 'super_admin')) return;
    state.editing = copy ? null : item;
    q('#contentEditor').hidden = false;
    q('#contentEditorTitle').textContent = item ? (copy ? 'İçeriği kopyala' : 'İçeriği düzenle') : 'Yeni içerik';
    q('#contentId').value = copy ? '' : item?.id || '';
    q('#contentVersion').value = copy ? '' : item?.version || '';
    setValue('#contentType', item?.content_type || 'daily_combo');
    setValue('#contentStatus', ['draft', 'scheduled'].includes(item?.status) ? item.status : 'draft');
    setValue('#titleTr', item?.title_tr || '');
    setValue('#titleEn', item?.title_en || '');
    setValue('#descriptionTr', item?.description_tr || '');
    setValue('#descriptionEn', item?.description_en || '');
    setValue('#startsAt', isoInput(item?.starts_at || new Date(Date.now() + 3600000)));
    setValue('#endsAt', isoInput(item?.ends_at || new Date(Date.now() + 90000000)));
    setValue('#rewardType', item?.reward_type || 'none');
    setValue('#rewardAmount', item?.reward_amount || 0);
    setValue('#answerNormalization', item?.answer_normalization || 'nfkc_lower_trim');
    setValue('#contentAnswer', '');
    setValue('#contentPayload', JSON.stringify(item?.payload || {}, null, 2));
    q('[data-editor-publish]').disabled = !allowed('publisher', 'super_admin') || !item;
    q('[data-editor-cancel]').disabled = !allowed('publisher', 'super_admin') || !item;
    message('#editorMessage', '');
    quickPanel();
    syncQuickDefaults();
  }

  function closeEditor() {
    q('#contentEditor').hidden = true;
    state.editing = null;
  }

  async function save(event) {
    event.preventDefault();
    try {
      const data = await rpc('admin_upsert_daily_content', {
        p_content_id: q('#contentId').value || null,
        p_document: documentFromForm(),
        p_answer: q('#contentAnswer').value || null,
        p_expected_version: Number(q('#contentVersion').value) || null,
        p_request_id: uuid(),
      });
      message('#editorMessage', `Kaydedildi • v${data.version}`);
      await load();
      openEditor(state.items.find(item => item.id === data.id) || data);
    } catch (error) {
      message('#editorMessage', error.message, true);
    }
  }

  async function publish() {
    if (!state.editing) return;
    try {
      await rpc('admin_publish_daily_content', { p_content_id: state.editing.id, p_expected_version: state.editing.version, p_request_id: uuid() });
      closeEditor();
      await load();
    } catch (error) {
      message('#editorMessage', error.message, true);
    }
  }

  async function cancel() {
    if (!state.editing) return;
    try {
      await rpc('admin_cancel_daily_content', { p_content_id: state.editing.id, p_expected_version: state.editing.version, p_request_id: uuid() });
      closeEditor();
      await load();
    } catch (error) {
      message('#editorMessage', error.message, true);
    }
  }

  function bind() {
    q('#adminLoginForm').addEventListener('submit', async event => {
      event.preventDefault();
      try {
        const { error } = await state.client.auth.signInWithOtp({ email: q('#adminEmail').value, options: { emailRedirectTo: location.href.split('#')[0] } });
        if (error) throw error;
        message('#adminGateMessage', 'Giriş bağlantısı gönderildi.');
      } catch (_) {
        message('#adminGateMessage', 'Giriş başlatılamadı.', true);
      }
    });
    q('#adminSignOut').addEventListener('click', () => state.client.auth.signOut());
    q('#adminNewContent').addEventListener('click', () => openEditor());
    q('#contentForm').addEventListener('submit', save);
    document.addEventListener('click', event => {
      const edit = event.target.closest('[data-edit-content]');
      if (edit) return openEditor(state.items.find(item => item.id === edit.dataset.editContent));
      const copy = event.target.closest('[data-copy-content]');
      if (copy) return openEditor(state.items.find(item => item.id === copy.dataset.copyContent), true);
      if (event.target.closest('[data-editor-close]')) return closeEditor();
      if (event.target.closest('[data-editor-copy]')) return openEditor(state.editing, true);
      if (event.target.closest('[data-editor-preview]')) return message('#editorMessage', 'Önizleme: ' + documentFromForm().title_tr);
      if (event.target.closest('[data-editor-publish]')) return publish();
      if (event.target.closest('[data-editor-cancel]')) return cancel();
      const view = event.target.closest('[data-admin-view]');
      if (view) switchView(view.dataset.adminView);
    });
  }

  async function init() {
    const result = window.MarinoRuntimeConfig?.read(window.MARINO_CONFIG);
    if (!result?.ok || result.config.targetEnvironment!=='staging') {
      message('#adminGateMessage', 'STAGING runtime yapılandırması doğrulanamadı.', true);
      return;
    }
    state.client = window.supabase?.createClient(result.config.supabaseUrl, result.config.supabasePublishableKey, { auth: { persistSession: false, autoRefreshToken: true, detectSessionInUrl: true } });
    if (!state.client) {
      message('#adminGateMessage', 'Güvenli istemci başlatılamadı.', true);
      return;
    }
    bind();
    state.client.auth.onAuthStateChange(async (event, session) => {
      state.session = session;
      if (event === 'SIGNED_OUT' || !session) {
        state.role = null;
        setWorkspace(false);
        q('#adminRole').textContent = 'Oturum gerekli';
        return;
      }
      try {
        await load();
      } catch (error) {
        setWorkspace(false);
        message('#adminGateMessage', error.code === '42501' ? 'Bu hesap için içerik yönetimi yetkisi yok.' : 'Yetki doğrulanamadı.', true);
      }
    });
    const { data } = await state.client.auth.getSession();
    if (data.session) {
      state.session = data.session;
      try {
        await load();
      } catch (_) {
        message('#adminGateMessage', 'İçerik yönetimi yetkisi yok.', true);
      }
    }
  }

  if (document.readyState === 'loading') document.addEventListener('DOMContentLoaded', init, { once: true });
  else init();
})();
