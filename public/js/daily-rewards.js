(() => {
  'use strict';
  const REWARDS=[
    {day:1,type:'coin',amount:'500',name:'Marino Coin'},
    {day:2,type:'energy',amount:'250',name:'Enerji'},
    {day:3,type:'point',amount:'25',name:'Reward Point'},
    {day:4,type:'tapBoost',amount:'10 dk',name:'Tap Boost'},
    {day:5,type:'incomeBoost',amount:'30 dk',name:'Saatlik Gelir Boost'},
    {day:6,type:'cosmetic',amount:'1',name:'Kozmetik Rozet'},
    {day:7,type:'freeSpin',amount:'1',name:'Sanal Free Spin',disclaimer:'Sanal hak, nakit değeri yoktur'}
  ];
  const ICONS={
    coin:'<circle cx="12" cy="12" r="8"/><path d="M9 8.5h5a2 2 0 0 1 0 4H10a2 2 0 0 0 0 4h5M12 6v12"/>',
    energy:'<path d="m13 2-7 11h6l-1 9 7-12h-6z"/>',point:'<path d="m12 3 2.7 5.5 6.1.9-4.4 4.3 1 6.1-5.4-2.9-5.4 2.9 1-6.1-4.4-4.3 6.1-.9L12 3Z"/>',
    tapBoost:'<path d="M8 12V7a2 2 0 0 1 4 0v4-2a2 2 0 0 1 4 0v5c0 4-2.3 7-6.5 7-3 0-5-1.8-6-4.5L3 15a2 2 0 0 1 3.5-1.8L8 15"/><path d="m17 3 1 2 2 .5-1.5 1.5.5 2"/>',
    incomeBoost:'<path d="M4 19V9m5 10v-6m5 6V8m5 11V4M2 21h20"/><path d="m15 5 4-2 2 4"/>',cosmetic:'<path d="m12 3 3 3 4 .5-.5 4 2 3.5-3.5 2-1.5 4-3.5-1.5L8.5 20 7 16l-3.5-2 2-3.5-.5-4L9 6l3-3Z"/><path d="m9 12 2 2 4-5"/>',
    freeSpin:'<circle cx="12" cy="12" r="8"/><path d="M12 4v3m0 10v3M4 12h3m10 0h3m-5.7-5.7-2.3 2.3-2.3-2.3M9.7 17.7l2.3-2.3 2.3 2.3"/>',freeBet:'<path d="M5 6h14v12H5z"/><path d="M8 10h8M8 14h5"/><circle cx="18" cy="18" r="3"/>',
    streak:'<path d="M12 3c3 4 5 6 5 10a5 5 0 0 1-10 0c0-2 1-4 3-6 0 3 1 4 2 5 1-3 1-6 0-9Z"/>',lock:'<rect x="5" y="10" width="14" height="10" rx="2"/><path d="M8 10V7a4 4 0 0 1 8 0v3"/>',complete:'<circle cx="12" cy="12" r="9"/><path d="m8 12 2.5 2.5L16 9"/>'
  };
  const state={streak:0,canClaim:false,preview:false,backBound:false,lastFocus:null,closeTimer:0};
  const svg=(type,label='')=>`<svg class="daily-reward-icon" viewBox="0 0 24 24" ${label?`aria-label="${label}" role="img"`:'aria-hidden="true"'}>${ICONS[type]||ICONS.coin}</svg>`;
  const overlay=()=>document.querySelector('#fsDaily');
  const claimButton=()=>document.querySelector('#btnClaimDaily');

  function card(reward){
    const claimed=reward.day<=state.streak,today=reward.day===state.streak+1&&state.canClaim,locked=!claimed&&!today;
    const status=claimed?'Alındı':today?'Bugün':'Kilitli';
    return `<article class="daily-reward-card ${claimed?'is-claimed':''} ${today?'is-today':''} ${locked?'is-locked':''} ${reward.day===7?'is-premium':''}" data-day="${reward.day}"><div class="daily-day"><span>GÜN</span><b>${reward.day}</b></div><div class="daily-icon-shell">${svg(reward.type,reward.name)}<span class="daily-status-icon">${svg(claimed?'complete':locked?'lock':'streak')}</span></div><div class="daily-card-copy"><strong>${reward.amount}</strong><span>${reward.name}</span>${reward.disclaimer?`<small>${reward.disclaimer}</small>`:''}</div><em>${status}</em></article>`;
  }
  function render(){
    const grid=document.querySelector('#calGrid'),button=claimButton(),body=document.querySelector('.daily-reward-body');if(!grid||!button||!body)return;
    body.appendChild(button);grid.innerHTML=REWARDS.map(card).join('');const today=grid.querySelector('.is-today');
    if(today){today.appendChild(button);button.hidden=false;button.disabled=false;button.textContent=state.preview?'ÖNİZLEME AL':'AL'}else{button.hidden=true;button.disabled=true}
  }
  function bindBack(){const back=window.Telegram?.WebApp?.BackButton;if(!back||state.backBound)return;back.onClick(close);back.show();state.backBound=true}
  function unbindBack(){const back=window.Telegram?.WebApp?.BackButton;if(!back||!state.backBound)return;back.offClick?.(close);back.hide();state.backBound=false}
  function open(options={}){state.streak=Math.max(0,Math.min(7,Number(options.streak||0)));state.canClaim=Boolean(options.canClaim);state.preview=Boolean(options.preview);state.lastFocus=document.activeElement;render();overlay()?.classList.add('show');document.documentElement.classList.add('daily-reward-open');bindBack();window.MarinoAudio?.play?.('ui_open');window.setTimeout(()=>document.querySelector('#closeDaily')?.focus(),60)}
  function close(){const target=overlay();if(!target?.classList.contains('show'))return;target.classList.remove('show');document.documentElement.classList.remove('daily-reward-open');unbindBack();window.MarinoAudio?.play?.('ui_close');window.showTab?.('tasks');document.querySelector('.nav-btn[data-tab="tasks"]')?.focus();state.lastFocus=null}
  function successHaptic(){const feedback=window.Telegram?.WebApp?.HapticFeedback;try{feedback?.notificationOccurred?.('success')}catch(_){}}
  function emitTrail(card){if(!card||document.documentElement.dataset.quality==='lite'||window.matchMedia?.('(prefers-reduced-motion: reduce)').matches)return;for(let index=0;index<4;index+=1){const particle=document.createElement('i');particle.className='daily-reward-trail';particle.style.setProperty('--trail-x',`${(index-1.5)*18}px`);particle.style.setProperty('--trail-delay',`${index*45}ms`);card.appendChild(particle);particle.addEventListener('animationend',()=>particle.remove(),{once:true})}}
  function claimSuccess(result={}){const card=document.querySelector('.daily-reward-card.is-today');if(!card)return;card.classList.add('claim-success','is-claimed');card.classList.remove('is-today');card.querySelector('em').textContent='Alındı';card.querySelector('.daily-status-icon').innerHTML=svg('complete');claimButton().disabled=true;emitTrail(card);successHaptic();window.MarinoAudio?.play?.('daily_reward');let notice=document.querySelector('#dailyRewardNotice');if(!notice){notice=document.createElement('div');notice.id='dailyRewardNotice';notice.className='daily-reward-notice';document.querySelector('#app')?.appendChild(notice)}notice.textContent='Günlük ödül alındı';notice.classList.add('show');clearTimeout(state.closeTimer);state.closeTimer=setTimeout(()=>{notice.classList.remove('show');state.streak=Math.max(state.streak,Number(result.streak||state.streak+1));state.canClaim=false;render()},900)}
  function claimFailure(){const button=claimButton();if(button)button.disabled=false;window.MarinoAudio?.play?.('ui_error')}
  function init(){document.querySelector('#closeDaily')?.addEventListener('click',close);overlay()?.addEventListener('pointerdown',event=>{if(event.target===overlay()){event.preventDefault();event.stopPropagation();close()}},{capture:true});document.addEventListener('keydown',event=>{if(event.key==='Escape'&&overlay()?.classList.contains('show')){event.preventDefault();close()}});const localPreview=window.MarinoLocalPreview?.detect?.(window.location,window.Telegram?.WebApp)===true;if(localPreview&&new URLSearchParams(window.location.search).get('daily')==='1')window.setTimeout(()=>window.openDaily?.(),120)}
  window.MarinoDailyRewards=Object.freeze({open,close,claimSuccess,claimFailure,REWARDS,ICONS});
  if(document.readyState==='loading')document.addEventListener('DOMContentLoaded',init,{once:true});else init();
})();
