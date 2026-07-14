(() => {
  'use strict';
  const q = selector => document.querySelector(selector);
  const state = { client: null, session: null };
  const id = () => crypto.randomUUID();
  const message = (text, error = false) => { q('#modMessage').textContent = text; q('#modMessage').style.color = error ? '#ff8291' : ''; };
  async function rpc(action, payload = {}) {
    const { data, error } = await state.client.rpc('marino_social_admin_rpc', { p_action: action, p_payload: payload, p_request_id: id() });
    if (error) throw error; return data;
  }
  function button(label, action, dangerous = false) { const node = document.createElement('button'); node.type = 'button'; node.textContent = label; if (dangerous) node.className = 'danger'; node.addEventListener('click', action); return node; }
  function reportCard(report) {
    const card = document.createElement('article'); card.className = 'mod-card';
    const body = document.createElement('div'); const title = document.createElement('h3'); title.textContent = `${report.public_alias} · #${report.social_code}`;
    const text = document.createElement('p'); text.textContent = report.filtered_body;
    const meta = document.createElement('small'); meta.textContent = `${report.channel_type} · ${report.reason} · ${report.report_count} rapor · ${new Date(report.created_at).toLocaleString('tr-TR')}`;
    body.append(title, text, meta);
    const actions = document.createElement('div'); actions.className = 'mod-actions';
    const run = async (action, payload) => { try { await rpc(action, payload); await load(); } catch { message('İşlem sunucu tarafından reddedildi.', true); } };
    actions.append(
      button('10 dk sustur', () => run('mute', { social_code: report.social_code, seconds: 600 })),
      button('24 saat sustur', () => run('mute', { social_code: report.social_code, seconds: 86400 })),
      button('Mesajı kaldır', () => run('remove_message', { message_id: report.message_id }), true),
      button('Kalıcı sustur', () => run('permanent_mute', { social_code: report.social_code }), true),
      button('Oyundan banla', () => run('game_ban', { social_code: report.social_code }), true),
      button('Raporu kapat', () => run('resolve_report', { report_id: report.report_id, status: 'reviewed' }))
    );
    card.append(body, actions); return card;
  }
  async function load() {
    const queue = await rpc('queue');
    q('#modQueue').replaceChildren(...(queue.length ? queue.map(reportCard) : [Object.assign(document.createElement('div'), { className: 'mod-empty', textContent: 'Açık şikâyet yok.' })]));
    q('#modGate').hidden = true; q('#modWorkspace').hidden = false; q('#modSignOut').hidden = false;
  }
  function bind() {
    q('#modLogin').addEventListener('submit', async event => { event.preventDefault(); try { const { error } = await state.client.auth.signInWithOtp({ email: q('#modEmail').value, options: { emailRedirectTo: location.href.split('#')[0] } }); if (error) throw error; message('Giriş bağlantısı gönderildi.'); } catch { message('Giriş başlatılamadı.', true); } });
    q('#modSignOut').addEventListener('click', () => state.client.auth.signOut()); q('#modRefresh').addEventListener('click', () => load().catch(() => message('Kuyruk okunamadı.', true)));
  }
  async function init() {
    const result = window.MarinoRuntimeConfig?.read(window.MARINO_CONFIG);
    if (!result?.ok) return message('Runtime yapılandırması doğrulanamadı.', true);
    state.client = window.supabase?.createClient(result.config.supabaseUrl, result.config.supabasePublishableKey, { auth: { persistSession: false, autoRefreshToken: true, detectSessionInUrl: true } });
    if (!state.client) return message('Güvenli istemci başlatılamadı.', true);
    bind(); state.client.auth.onAuthStateChange(async (event, session) => { state.session = session; if (event === 'SIGNED_OUT' || !session) { q('#modGate').hidden = false; q('#modWorkspace').hidden = true; q('#modSignOut').hidden = true; return; } try { await load(); } catch { message('Bu hesap için moderasyon yetkisi yok.', true); } });
    const { data } = await state.client.auth.getSession(); if (data.session) try { await load(); } catch { message('Bu hesap için moderasyon yetkisi yok.', true); }
  }
  if (document.readyState === 'loading') document.addEventListener('DOMContentLoaded', init, { once: true }); else init();
})();
