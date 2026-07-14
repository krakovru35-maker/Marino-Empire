(() => {
  'use strict';

  const BUILDINGS = [
    ['casino_lobby','Slot Salonu','slot-hall','Gelir',1,1200,180],
    ['roulette_table','Rulet Masası','roulette-table','Eğlence',2,2400,260],
    ['blackjack_lounge','Blackjack Lounge','blackjack-lounge','VIP',4,4200,390],
    ['vip_hall','VIP Salon','vip-hall','VIP',7,7200,620],
    ['casino_bar','Casino Bar','casino-bar','Eğlence',3,3100,310],
    ['security_center','Güvenlik Merkezi','security-center','Güvenlik',6,5400,460],
    ['hotel_floor','Otel Katı','hotel','Prestij',10,9800,760],
    ['marina','Marina','marina','Prestij',15,14500,980],
    ['private_vault','Özel Kasa','private-vault','Güvenlik',20,21000,1320],
    ['marino_penthouse','Marino Penthouse','penthouse','VIP',30,32000,1900]
  ].map(([key,name,icon,category,unlock,cost,income]) => ({ key,name,icon,category,unlock,cost,income,max:12 }));
  const TASKS = [
    ['tap_100','daily','Marino Ritmi','Marino’ya 100 kez dokun.',100,25,'taps'],
    ['energy_500','weekly','Enerji Operasyonu','Toplam 500 enerji harca.',500,90,'energy'],
    ['collect_3','daily','Kasa Turu','Kasayı 3 kez başarıyla topla.',3,30,'collects'],
    ['upgrade_1','daily','İlk Yatırım','Bir binayı yükselt.',1,35,'upgrades'],
    ['own_5','progress','Beş Yıldızlı Portföy','5 farklı binayı aç.',5,120,'owned'],
    ['level_10','progress','Lounge Lisansı','Casino seviye 10’a ulaş.',10,150,'level'],
    ['combo_open','daily','Combo Masası','Daily Combo ekranını aç.',1,20,'combo'],
    ['cipher_open','daily','Şifre Odası','Daily Cipher ekranını aç.',1,20,'cipher'],
    ['casino_try','weekly','Masa Deneyimi','Bir casino mini oyununu dene.',1,55,'casino'],
    ['friends_visit','social','Empire Ağı','Arkadaşlar sayfasını ziyaret et.',1,25,'friends'],
    ['streak_3','weekly','Üç Günlük Ritim','3 günlük giriş serisine ulaş.',3,80,'streak']
  ].map(([id,category,title,description,goal,points,metric]) => ({ id,category,title,description,goal,points,metric }));
  const CATEGORY_LABELS = { daily:'Günlük', weekly:'Haftalık', progress:'İlerleme', social:'Sosyal' };
  const REWARDS = [
    ['spin_1','1 Sanal Free Spin','spin',25,1,'Bu oturum'],['spin_3','3 Sanal Free Spin','spin',65,3,'Bu oturum'],['spin_5','5 Sanal Free Spin','spin',95,5,'Bu oturum'],
    ['bet_1','1 Sanal Free Bet','bet',30,1,'Bu oturum'],['bet_3','3 Sanal Free Bet','bet',75,3,'Bu oturum'],
    ['energy_pack','Enerji Paketi','energy',40,1,'Sunucu aktivasyonu gerekir'],['tap_boost','Tap Boost','boost',55,1,'Sunucu aktivasyonu gerekir'],
    ['income_boost','Geçici Saatlik Gelir Boost','income',80,1,'Sunucu aktivasyonu gerekir'],['badge','Marino Kozmetik Rozeti','cosmetic',70,1,'Bu oturum'],['decor','Casino Sahne Dekoru','decor',110,1,'Bu oturum']
  ].map(([id,name,type,cost,amount,expiry])=>({id,name,type,cost,amount,expiry}));
  const state = {
    snapshot:null, category:'daily', metrics:{ taps:0,energy:0,collects:0,upgrades:0,combo:0,cipher:0,casino:0,friends:0 },
    claimed:new Set(), rewardPoints:0, previewLevels:new Map(), serverTasksMarkup:'', startedAt:Date.now(), regenTimer:0,
    entitlements:{ spin:0,bet:0,energy:0,boost:0,income:0,cosmetic:0,decor:0 }, pendingReward:null
  };
  const SPRITES={buildings:'./assets/ui/buildings/marino-building-icons.svg',tasks:'./assets/ui/tasks/marino-task-icons.svg',casino:'./assets/ui/casino/marino-casino-icons.svg'};
  const PREFIX={buildings:'building',tasks:'task',casino:'casino'};
  const fallbackPaths={building:'<path d="M4 21V9l8-6 8 6v12M2 21h20M9 13h6M9 17h6"/>',task:'<circle cx="12" cy="12" r="9"/><path d="m8 12 2.5 2.5L16 9"/>',casino:'<rect x="4" y="4" width="16" height="16" rx="3"/><path d="M8 9h.01M12 9h.01M16 9h.01M8 15h.01M12 15h.01M16 15h.01"/>'};
  const preview = () => window.MarinoPhase2BBridge?.isPreview?.() === true;
  const fmt = value => new Intl.NumberFormat('tr-TR').format(Number(value || 0));
  const escape = value => String(value ?? '').replace(/[&<>"']/g, char => ({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[char]));
  const spriteIcon=(scope,id,label='')=>`<svg class="marino-sprite-icon" viewBox="0 0 24 24" ${label?`role="img" aria-label="${escape(label)}"`:'aria-hidden="true"'}><g class="sprite-fallback">${fallbackPaths[scope==='buildings'?'building':scope==='tasks'?'task':'casino']}</g><use href="${SPRITES[scope]}#${PREFIX[scope]}-${id}"></use></svg>`;
  const TASK_ICONS={taps:'tap',energy:'energy',collects:'vault-collect',upgrades:'building-upgrade',owned:'building-upgrade',level:'league',combo:'daily',cipher:'weekly',casino:'progress',friends:'social',streak:'login-streak'};
  const CATEGORY_ICONS={daily:'daily',weekly:'weekly',progress:'progress',social:'social'};
  const REWARD_ICONS={spin:'free-spin',bet:'free-bet',energy:'chip',boost:'vip',income:'win',cosmetic:'vip',decor:'jackpot'};

  function metricValue(task) {
    if (!state.snapshot) return 0;
    if (task.metric === 'level') return state.snapshot.level;
    if (task.metric === 'streak') return state.snapshot.streak;
    if (task.metric === 'owned') return preview()
      ? [...state.previewLevels.values()].filter(level => level > 0).length
      : state.snapshot.upgrades.filter(item => Number(item.level || 0) > 0).length;
    return state.metrics[task.metric] || 0;
  }
  const taskReady = task => metricValue(task) >= task.goal && !state.claimed.has(task.id);

  function buildingCard(definition, index) {
    const server = state.snapshot?.upgrades?.find(item => item.building_key === definition.key) || state.snapshot?.upgrades?.[index];
    const isPreview = preview();
    const supported = true;
    const serverUpgradeKey = server?.building_key || definition.key;
    const level = isPreview ? (state.previewLevels.get(definition.key) || (index === 0 ? 3 : 0)) : Number(server?.level || 0);
    const unlock = Number(server?.unlock_level || definition.unlock);
    const locked = Number(state.snapshot?.level || 1) < unlock;
    const maxed = level >= definition.max;
    const cost = isPreview ? definition.cost + level * definition.cost : Number(server?.next_cost_coin || 0);
    const income = isPreview ? level * definition.income : Number(server?.current_income_per_hour || 0);
    const frame = ['bronze','silver','gold','platinum','diamond'][Math.min(4, Math.floor((state.snapshot?.level || 1) / 10))];
    return `<article class="empire-building-card frame-${frame} ${locked?'is-locked':''} ${!supported?'is-demo':''}" data-building="${definition.key}">
      <div class="building-icon">${spriteIcon('buildings',definition.icon,definition.name)}</div><div class="building-copy">
        <div class="building-heading"><span>${escape(definition.name)}</span><em>${escape(definition.category)}</em></div>
        <div class="building-level">Seviye <b>${level}</b> <i>→</i> <b>${Math.min(definition.max,level+1)}</b></div>
        <div class="building-income">Saatlik etki <strong>+${fmt(income)}</strong></div>
        ${!server&&!isPreview?'<small class="demo-label">Sunucu anahtarıyla yükseltilebilir</small>':''}
        ${locked?`<small class="lock-label">Seviye ${unlock} gerekli</small>`:''}
      </div><button type="button" class="building-upgrade" data-upgrade="${definition.key}" data-server-upgrade="${escape(serverUpgradeKey)}" data-cost="${cost}" data-income="${definition.income}" ${locked||maxed||!supported?'disabled':''}>
        <span>${maxed?'MAKSİMUM':'YÜKSELT'}</span><small>${maxed?'Tamamlandı':fmt(cost)+' coin'}</small></button></article>`;
  }

  function renderBuildings() {
    const list = document.querySelector('#listBuildings');
    if (!list || !state.snapshot) return;
    list.innerHTML = `<div class="empire-view-intro"><div><span>CASINO PORTFÖYÜ</span><h3>İmparatorluğunu kat kat büyüt</h3></div><div class="income-chip">+${fmt(state.snapshot.hourlyIncome)}/saat</div></div>
      <div class="building-category-row">${['Gelir','Prestij','Güvenlik','Eğlence','VIP'].map(label=>`<span>${label}</span>`).join('')}</div>
      <div class="empire-building-grid">${BUILDINGS.map(buildingCard).join('')}</div>
      <p class="authority-note">Fiyat, gelir ve yükseltme sonucu gerçek oyunda yalnız sunucu yanıtından gelir.</p>`;
  }

  function renderCasinoIcons(){
    const mappings=[[/Casino Çipi|Çip Satın/i,'chip'],[/Klasik Slot|Slot/i,'slot'],[/Rulet|Çark/i,'roulette'],[/Blackjack/i,'blackjack'],[/Poker|Kart/i,'card'],[/At Yarışı|Zar/i,'dice'],[/İddaa|Spor/i,'free-bet'],[/Kasa Aç|Ödül/i,'jackpot']];
    document.querySelectorAll('#listStore .item-row').forEach(row=>{const title=row.querySelector('.item-title')?.textContent||'';const match=mappings.find(([pattern])=>pattern.test(title));const shell=row.querySelector('.item-ico');if(!match||!shell||shell.querySelector('.marino-sprite-icon'))return;shell.classList.add('casino-sprite-shell');shell.innerHTML=spriteIcon('casino',match[1],title)});
  }

  function taskCard(task) {
    const progress = Math.min(task.goal, metricValue(task));
    const percent = Math.round(progress / task.goal * 100);
    const claimed = state.claimed.has(task.id);
    const ready = taskReady(task);
    const disabled = !ready;
    return `<article class="empire-task-card ${claimed?'is-complete':''}"><div class="task-point">${spriteIcon('tasks',claimed?'complete':TASK_ICONS[task.metric]||'daily',task.title)}<small>${task.points} MRP</small></div><div class="task-copy"><h4>${escape(task.title)}</h4><p>${escape(task.description)}</p><div class="task-progress"><i style="width:${percent}%"></i></div><span>${fmt(progress)} / ${fmt(task.goal)}</span></div><button type="button" data-claim-task="${task.id}" ${disabled?'disabled':''}>${claimed?'ALINDI':ready?'AL':'DEVAM'}</button></article>`;
  }

  function dailyCalendar() {
    const items = [['Coin','Sunucu sonucu'],['Enerji','Sunucu sonucu'],['MRP','Sunucu sonucu'],['Tap Boost','Sunucu sonucu'],['MRP','Sunucu sonucu'],['Kozmetik','Sunucu sonucu'],['Free Spin','Sunucu sonucu']];
    const streak = Number(state.snapshot?.streak || 0);
    return `<section class="retention-card"><header><div><span>7 GÜNLÜK RİTİM</span><h3>Empire Check-in</h3></div><button type="button" data-open-daily>Takvimi aç</button></header><div class="retention-days">${items.map((item,index)=>`<div class="${index<streak?'done':index===streak?'today':'missed'}"><b>${index+1}</b><span>${item[0]}</span><small>${item[1]}</small></div>`).join('')}</div><p>Kalıcı ödüller yalnız sunucu onayıyla verilir. Kaçırılan günler otomatik tamamlanmaz.</p></section>`;
  }

  function renderTasks() {
    const list = document.querySelector('#listTasks');
    if (!list || !state.snapshot) return;
    const tasks = TASKS.filter(task => task.category === state.category);
    list.innerHTML = `<div class="phase2b-task-root"><div class="task-summary"><div><span>MARINO REWARD POINT</span><strong>${fmt(state.rewardPoints)}</strong><small>Sunucu onaylı görev puanı</small></div><div><span>OTURUM</span><strong id="sessionDuration">0 dk</strong><small>Uzun oturumlarda mola ver.</small></div></div>
      ${dailyCalendar()}<div class="task-tabs" role="tablist">${Object.entries(CATEGORY_LABELS).map(([key,label])=>`<button type="button" role="tab" data-task-category="${key}" aria-selected="${key===state.category}">${spriteIcon('tasks',CATEGORY_ICONS[key])}<span>${label}</span></button>`).join('')}</div>
      <div class="empire-task-list">${tasks.map(taskCard).join('')}</div>
      ${state.serverTasksMarkup?`<details class="server-task-archive"><summary>Mevcut sunucu görevleri</summary>${state.serverTasksMarkup}</details>`:''}</div>`;
  }

  function installHomePulse() {
    if (document.querySelector('#empireLoopPulse')) return;
    const hub = document.querySelector('#btnEmpireHub');
    if (!hub) return;
    const pulse = document.createElement('button');
    pulse.type='button'; pulse.id='empireLoopPulse'; pulse.className='empire-loop-pulse';
    pulse.setAttribute('aria-label','Casino empire ilerlemesini aç');
    hub.insertAdjacentElement('afterend', pulse);
    pulse.addEventListener('click', () => document.querySelector('.nav-btn[data-tab="tasks"]')?.click());
    const rewardButton=document.createElement('button');rewardButton.type='button';rewardButton.id='btnRewardVault';rewardButton.className='reward-vault-trigger';rewardButton.setAttribute('aria-label','Ödül Kasasını aç');rewardButton.innerHTML='<span>ÖDÜL KASASI</span><small id="homeEntitlementSummary">Sanal haklar • nakit değeri yoktur</small><i>›</i>';pulse.insertAdjacentElement('afterend',rewardButton);rewardButton.addEventListener('click',openRewardStore);
  }

  function renderHomePulse() {
    installHomePulse();
    const pulse = document.querySelector('#empireLoopPulse');
    if (!pulse || !state.snapshot) return;
    const ready = TASKS.filter(taskReady).length;
    pulse.innerHTML = `<span><small>SAATLİK</small><b>+${fmt(state.snapshot.hourlyIncome)}</b></span><span><small>GÖREV</small><b>${ready} hazır</b></span><span><small>MRP</small><b>${fmt(state.rewardPoints)}</b></span><i aria-hidden="true">›</i>`;
    const summary=document.querySelector('#homeEntitlementSummary');if(summary)summary.textContent=`${state.entitlements.spin} Spin • ${state.entitlements.bet} Bet • Hak`;
  }

  function rewardCard(reward){
    const enough=state.rewardPoints>=reward.cost, canBuy=enough;
    const count=state.entitlements[reward.type]||0;
    return `<article class="reward-card"><div class="reward-symbol ${reward.type}">${spriteIcon('casino',REWARD_ICONS[reward.type]||'chip',reward.name)}</div><div class="reward-copy"><h4>${escape(reward.name)}</h4><p>Oyun hakkı • nakit değeri yoktur • transfer edilemez</p><span>Kalan kullanım: <b>${count}</b></span><small>Koşul / süre: ${escape(reward.expiry)}</small></div><button type="button" data-buy-reward="${reward.id}" ${canBuy?'':'disabled'}><b>${fmt(reward.cost)} MRP</b><small>${enough?'SATIN AL':'PUAN YETERSİZ'}</small></button></article>`;
  }

  function walletMarkup(){return `<section class="virtual-wallet"><header><div><span>HAK CÜZDANI</span><h3>Casino avantajların</h3></div><b>AKTİF</b></header><div class="wallet-grid"><div><strong>${state.entitlements.spin}</strong><span>Free Spin</span><small>Aktif hak</small></div><div><strong>${state.entitlements.bet}</strong><span>Free Bet</span><small>Nakit yok</small></div><div><strong>${state.entitlements.energy}</strong><span>Enerji Paketi</span><small>${state.entitlements.energy?'Kullanılmadı':'Yok'}</small></div><div><strong>${state.entitlements.boost+state.entitlements.income}</strong><span>Aktif Boost</span><small>Server aktivasyonu</small></div></div></section>`}

  function installRewardUi(){
    if(document.querySelector('#sheetRewardVault'))return;
    const overlay=document.createElement('div');overlay.id='sheetRewardVault';overlay.className='sheet-overlay reward-vault-overlay';overlay.innerHTML=`<div class="sheet reward-vault-sheet"><div class="sheet-handle"></div><button type="button" class="sheet-close reward-close" aria-label="Ödül Kasasını kapat">✕</button><div class="reward-vault-title"><span>MARINO EMPIRE</span><h2>Ödül Kasası</h2><p>Görev puanlarını yalnız sanal, nakit değeri olmayan oyun haklarına dönüştür.</p></div><div id="rewardVaultBody"></div><div class="responsible-note"><b>18+ görsel alanı</b><span>Garanti kazanç yoktur. Para yatırma, çekim ve transfer bulunmaz. Oturumuna ara vermeyi unutma.</span></div></div>`;
    const confirm=document.createElement('div');confirm.id='rewardConfirm';confirm.className='reward-confirm';confirm.hidden=true;confirm.innerHTML='<div role="dialog" aria-modal="true" aria-labelledby="rewardConfirmTitle"><span>SANAL ÖDÜL ONAYI</span><h3 id="rewardConfirmTitle">Ödülü aç</h3><p id="rewardConfirmText"></p><small>Nakit değeri yoktur; çekilemez ve transfer edilemez.</small><div><button type="button" data-cancel-reward>Vazgeç</button><button type="button" data-confirm-reward>Onayla</button></div></div>';
    document.querySelector('#app')?.append(overlay,confirm);
    overlay.addEventListener('pointerdown',event=>{if(event.target===overlay)closeRewardStore()});overlay.querySelector('.reward-close').addEventListener('click',closeRewardStore);
    confirm.addEventListener('pointerdown',event=>{if(event.target===confirm)cancelReward()});confirm.querySelector('[data-cancel-reward]').addEventListener('click',cancelReward);confirm.querySelector('[data-confirm-reward]').addEventListener('click',confirmReward);
  }

  function renderRewardStore(){
    installRewardUi();const body=document.querySelector('#rewardVaultBody');if(!body)return;
    body.innerHTML=`<div class="reward-point-balance"><span>MARINO REWARD POINT</span><strong>${fmt(state.rewardPoints)}</strong><small>Haklar server onayı ile kullanılır</small></div>${walletMarkup()}<div class="reward-store-grid">${REWARDS.map(rewardCard).join('')}</div>`;
  }
  function openRewardStore(){renderRewardStore();document.querySelector('#sheetRewardVault')?.classList.add('show')}
  function closeRewardStore(){document.querySelector('#sheetRewardVault')?.classList.remove('show')}
  function requestReward(id){const reward=REWARDS.find(item=>item.id===id);if(!reward)return;state.pendingReward=reward;document.querySelector('#rewardConfirmTitle').textContent=reward.name;document.querySelector('#rewardConfirmText').textContent=`${reward.cost} MRP karşılığında ${reward.amount} hak açılacak.`;document.querySelector('#rewardConfirm').hidden=false}
  function cancelReward(){state.pendingReward=null;const modal=document.querySelector('#rewardConfirm');if(modal)modal.hidden=true}
  function confirmReward(){
    const reward=state.pendingReward;if(!reward)return cancelReward();
    if(!preview()&&!window.MarinoPhase2BBridge?.buyReward){cancelReward();return showRewardNotice('Ödül mağazası server aktivasyonu bekliyor','failed')}
    if(state.rewardPoints<reward.cost){cancelReward();window.MarinoAudio?.play?.('ui_error');return showRewardNotice('Puan yetersiz','failed')}
    state.rewardPoints-=reward.cost;state.entitlements[reward.type]=(state.entitlements[reward.type]||0)+reward.amount;cancelReward();renderRewardStore();renderHomePulse();window.MarinoAudio?.play?.('reward_purchase');if(reward.type==='spin')window.MarinoAudio?.play?.('free_spin_unlock');if(reward.type==='bet')window.MarinoAudio?.play?.('free_bet_unlock');showRewardNotice(`${reward.name} cüzdana eklendi`,'success');
  }
  function showRewardNotice(message,status){let notice=document.querySelector('#rewardNotice');if(!notice){notice=document.createElement('div');notice.id='rewardNotice';notice.className='reward-notice';document.querySelector('#app')?.appendChild(notice)}notice.textContent=message;notice.dataset.status=status;notice.classList.add('show');clearTimeout(notice.timer);notice.timer=setTimeout(()=>notice.classList.remove('show'),2400)}

  function injectDemoEntitlement(id){
    if(!preview()||(id!=='slot'&&id!=='sports'))return;const body=document.querySelector('#miniBody');if(!body)return;const type=id==='slot'?'spin':'bet',label=id==='slot'?'Sanal Free Spin Kullan':'Sanal Free Bet Kuponu';
    const panel=document.createElement('section');panel.className='demo-entitlement-panel';panel.innerHTML=`<div><b>${label}</b><span>Nakit değeri yoktur • gerçek bahis gönderilmez</span></div><button type="button" ${state.entitlements[type]>0?'':'disabled'}>${state.entitlements[type]} hak</button><p aria-live="polite"></p>`;body.prepend(panel);panel.querySelector('button').addEventListener('click',()=>useDemoEntitlement(type,panel));
  }
  function useDemoEntitlement(type,panel){if(!preview()||state.entitlements[type]<=0)return;state.entitlements[type]-=1;const isSpin=type==='spin';panel.querySelector('button').textContent=`${state.entitlements[type]} hak`;panel.querySelector('button').disabled=state.entitlements[type]<=0;panel.querySelector('p').textContent=isSpin?'Sanal sonuç: Marino yıldızı • bakiye veya coin ödülü yoktur.':'Demo kupon işaretlendi • hiçbir bahis gönderilmedi, kazanç oluşturulmadı.';renderHomePulse();renderRewardStore()}

  function wrapMiniGames(){
    if(!preview()||window.openMini?.__phase2bWrapped)return;const original=window.openMini;if(typeof original!=='function')return;
    const wrapped=function(id,title){original(id,title);window.setTimeout(()=>injectDemoEntitlement(id),0)};wrapped.__phase2bWrapped=true;window.openMini=wrapped;
  }

  async function upgradeBuilding(button) {
    if (!state.snapshot) return;
    const definition = BUILDINGS.find(item => item.key === button.dataset.upgrade);
    if (!definition) return;
    button.disabled = true;
    const serverKey = button.dataset.serverUpgrade || definition.key;
    const result = await window.MarinoPhase2BBridge?.upgradeBuilding?.(serverKey, Number(button.dataset.cost), Number(button.dataset.income));
    if (preview() && result?.ok) {
      state.previewLevels.set(definition.key, (state.previewLevels.get(definition.key) || (definition.key==='casino_lobby'?3:0)) + 1);
      state.metrics.upgrades += 1;
      window.MarinoAudio?.play?.('building_upgrade');
      state.snapshot = window.MarinoPhase2BBridge.snapshot();
      renderBuildings(); renderTasks(); renderHomePulse();
      window.MarinoPhase2A?.syncScene?.({ level: state.snapshot.level, buildingLevel: Math.max(...state.previewLevels.values()) });
    } else if (!preview() && result?.ok === false) {
      button.disabled = false;
    } else if (preview()) {
      button.disabled = false;
      document.querySelector('#toast') && (document.querySelector('#toast').textContent='Demo coin bakiyesi yetersiz.');
    }
  }

  async function claimTask(id) {
    const task = TASKS.find(item => item.id === id);
    if (!task || !taskReady(task)) return;
    if(!preview()){
      const result=await window.MarinoPhase2BBridge?.claimTask?.(task.id,1);
      if(result?.ok===false)return;
    }
    state.claimed.add(id); state.rewardPoints += task.points;
    window.MarinoAudio?.play?.('task_complete');
    renderTasks(); renderHomePulse();
    document.dispatchEvent(new CustomEvent('marino:reward-points', { detail:{ balance:state.rewardPoints } }));
  }

  function track(metric, amount=1) {
    if (!(metric in state.metrics)) return;
    state.metrics[metric] += amount;
    if (document.querySelector('#view-tasks')?.classList.contains('active')) renderTasks();
    renderHomePulse();
  }

  function bindEvents() {
    document.addEventListener('pointerdown', event => { if (event.target.closest('#btnTap')) { track('taps'); track('energy'); } }, { capture:true });
    document.addEventListener('marino:collect-success', () => track('collects'));
    document.addEventListener('click', event => {
      const upgrade = event.target.closest('[data-upgrade]'); if (upgrade) return void upgradeBuilding(upgrade);
      const claim = event.target.closest('[data-claim-task]'); if (claim) return claimTask(claim.dataset.claimTask);
      const category = event.target.closest('[data-task-category]'); if (category) { state.category=category.dataset.taskCategory; return renderTasks(); }
      const reward=event.target.closest('[data-buy-reward]');if(reward)return requestReward(reward.dataset.buyReward);
      if (event.target.closest('[data-open-daily]')) return window.openDaily?.();
      if (event.target.closest('#btnDailyCombo')) track('combo');
      if (event.target.closest('#btnDailyCipher')) track('cipher');
      const nav = event.target.closest('.nav-btn');
      if (nav?.dataset.tab === 'casino' || nav?.dataset.tab === 'store') { track('casino'); window.setTimeout(renderCasinoIcons,0); }
      if (nav?.dataset.tab === 'friends') track('friends');
      if (nav?.dataset.tab === 'buildings') window.setTimeout(renderBuildings,0);
      if (nav?.dataset.tab === 'tasks') window.setTimeout(renderTasks,0);
    });
  }

  function sync(snapshot) {
    if (!snapshot) return;
    state.snapshot = snapshot;
    TASKS.forEach(task => { if (snapshot.completedTasks?.includes(task.id)) state.claimed.add(task.id); });
    renderBuildings(); renderTasks(); renderHomePulse(); renderCasinoIcons();
  }

  function init() {
    bindEvents(); installHomePulse(); installRewardUi(); wrapMiniGames(); sync(window.MarinoPhase2BBridge?.snapshot?.());
    window.setInterval(() => { const el=document.querySelector('#sessionDuration'); if(el) el.textContent=`${Math.floor((Date.now()-state.startedAt)/60000)} dk`; },30000);
    if (preview()) state.regenTimer=window.setInterval(()=>window.MarinoPhase2BBridge?.regeneratePreviewEnergy?.(),3000);
  }

  function consumeDemoEntitlement(type){if(!preview()||!['spin','bet'].includes(type)||state.entitlements[type]<=0)return false;state.entitlements[type]-=1;renderHomePulse();renderRewardStore();return true;}
  function grantDemoRewardPoints(amount){amount=Number(amount);if(!preview()||!Number.isFinite(amount)||amount<=0)return false;state.rewardPoints+=amount;renderHomePulse();renderRewardStore();document.dispatchEvent(new CustomEvent('marino:reward-points',{detail:{balance:state.rewardPoints}}));return true;}
  function grantDemoEntitlement(type,amount=1){amount=Number(amount);if(!preview()||!['spin','bet'].includes(type)||!Number.isInteger(amount)||amount<=0)return false;state.entitlements[type]+=amount;renderHomePulse();renderRewardStore();return true;}
  window.MarinoPhase2B = Object.freeze({ sync, BUILDINGS, TASKS, REWARDS, openRewardStore, consumeDemoEntitlement, grantDemoRewardPoints, grantDemoEntitlement, getDemoState:() => ({ rewardPoints:state.rewardPoints, claimed:[...state.claimed], metrics:{...state.metrics}, entitlements:{...state.entitlements} }) });
  if (document.readyState==='loading') document.addEventListener('DOMContentLoaded',init,{once:true}); else init();
})();
