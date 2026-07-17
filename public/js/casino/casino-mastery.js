(() => {
  'use strict';

  const LEVELS=[
    {level:1,name:'Acemi',min:0},{level:2,name:'Oyuncu',min:20},{level:3,name:'Krupiye Dostu',min:50},{level:4,name:'VIP',min:90},{level:5,name:'Marino Ustası',min:140}
  ];
  const BADGES=[
    ['first-spin','İlk Spin','slot_spin'],['first-roulette','İlk Rulet','roulette_spin'],['first-blackjack','İlk Blackjack','blackjack_hand'],
    ['split-master','Split Ustası','blackjack_split'],['double-down','Double Down','blackjack_double'],['triple-casino','Üçlü Casino','triple_visit'],
    ['seven-day','7 Gün Serisi','seven_day'],['slots-master','Slot Ustası','slots_master'],['roulette-master','Rulet Ustası','roulette_master'],
    ['blackjack-master','Blackjack Ustası','blackjack_master'],['casino-champion','Casino Şampiyonu','casino_champion']
  ].map(([id,title,event])=>({id,title,event}));
  const GAME_EVENTS={slots:new Set(['slot_spin','slot_payline_win','free_spin_used']),roulette:new Set(['roulette_bet','roulette_spin','roulette_win']),blackjack:new Set(['blackjack_hand','blackjack_hit','blackjack_stand','blackjack_double','blackjack_split','blackjack_win'])};
  const EVENT_POINTS={slot_spin:2,slot_payline_win:4,free_spin_used:3,roulette_bet:1,roulette_spin:3,roulette_win:5,blackjack_hand:3,blackjack_hit:1,blackjack_stand:1,blackjack_double:4,blackjack_split:5,blackjack_win:5,chain_complete:8};
  function createMasteryState(){return{points:{slots:0,roulette:0,blackjack:0},badges:new Map(),selectedBadge:null,visited:new Set()};}
  function gameFor(event,payload={}){if(event==='chain_complete'&&payload.game)return payload.game==='slot'?'slots':payload.game;return Object.keys(GAME_EVENTS).find(game=>GAME_EVENTS[game].has(event))||null;}
  function levelFor(points){let result=LEVELS[0];for(const level of LEVELS)if(points>=level.min)result=level;return result;}
  function awardBadge(state,event,now=Date.now()){for(const badge of BADGES)if(badge.event===event&&!state.badges.has(badge.id))state.badges.set(badge.id,now);}
  function applyMasteryEvent(state,event,payload={}){const game=gameFor(event,payload),points=EVENT_POINTS[event]||0;if(game&&points)state.points[game]+=points;if(event==='casino_visit')state.visited.add(payload.game);awardBadge(state,event);for(const id of ['slots','roulette','blackjack'])if(levelFor(state.points[id]).level===5)awardBadge(state,`${id}_master`);if(state.visited.size===3)awardBadge(state,'triple_visit');if(Object.values(state.points).every(value=>levelFor(value).level===5))awardBadge(state,'casino_champion');return{game,points,level:game?levelFor(state.points[game]):null};}

  const preview=()=>window.MarinoLocalPreview?.detect?.(window.location,window.Telegram?.WebApp)===true;
  const state=createMasteryState();
  const total=()=>Object.values(state.points).reduce((sum,value)=>sum+value,0);
  function summaryMarkup(){const strongest=Object.entries(state.points).sort((a,b)=>b[1]-a[1])[0],level=levelFor(strongest[1]);return`<button type="button" data-casino-progress="missions"><span>CASINO MASTERY</span><strong>${level.name}</strong><small>${total()} kozmetik XP</small></button>`;}
  function sheetMarkup(){return`<section class="casino-mastery"><header><span>CASINO MASTERY</span><h3>Oyun Ustalığı</h3><p>Yalnız kozmetik başarı ve kozmetik ilerlemedir; ekonomik değeri yoktur.</p></header><div class="casino-mastery-games">${Object.entries(state.points).map(([game,points])=>{const level=levelFor(points),next=LEVELS[level.level]||level,max=next.min||level.min||1,percent=level.level===5?100:Math.min(100,Math.round(points/max*100));return`<article><b>${game.toUpperCase()}</b><strong>${level.name}</strong><div class="casino-progress"><i style="width:${percent}%"></i></div><small>${points} XP • Seviye ${level.level}/5</small></article>`;}).join('')}</div><div class="casino-badges">${BADGES.map(badge=>{const unlocked=state.badges.has(badge.id);return`<button type="button" data-show-casino-badge="${badge.id}" class="${unlocked?'unlocked':'locked'}" ${unlocked?'':'disabled'}><i>${unlocked?'M':'◆'}</i><b>${badge.title}</b><small>${unlocked?new Date(state.badges.get(badge.id)).toLocaleDateString('tr-TR'):'Kilitli'}</small></button>`;}).join('')}</div></section>`;}
  function selectBadge(id){if(!state.badges.has(id))return false;state.selectedBadge=id;const profile=document.querySelector('#btnProfile');if(profile){let mark=profile.querySelector('.casino-profile-badge');if(!mark){mark=document.createElement('span');mark.className='casino-profile-badge';profile.append(mark);}mark.textContent=BADGES.find(item=>item.id===id)?.title||'Casino Rozeti';}return true;}
  function enhanceBadges(root=document){root.querySelectorAll('[data-show-casino-badge] i:not([data-svg-ready])').forEach(icon=>{const id=icon.closest('[data-show-casino-badge]').dataset.showCasinoBadge;icon.dataset.svgReady='true';icon.innerHTML=`<svg viewBox="0 0 24 24" aria-hidden="true"><use href="./assets/ui/casino/marino-casino-badges.svg#badge-${id}"></use></svg>`;});}
  function refresh(){const open=document.querySelector('.casino-progression-overlay:not([hidden])');if(open)window.MarinoCasinoProgression?.open?.();}
  function bind(){document.addEventListener('marino:casino-event',event=>{if(!event.detail?.preview||!preview())return;applyMasteryEvent(state,event.detail.event,event.detail.payload);});document.addEventListener('click',event=>{const badge=event.target.closest('[data-show-casino-badge]');if(badge)selectBadge(badge.dataset.showCasinoBadge);});}
  if(typeof window!=='undefined'){window.MarinoCasinoMastery=Object.freeze({summaryMarkup,sheetMarkup,refresh,enhanceBadges,snapshot:()=>({points:{...state.points},badges:[...state.badges.keys()],selectedBadge:state.selectedBadge})});const observer=new MutationObserver(records=>records.some(record=>record.addedNodes.length)&&enhanceBadges(document));observer.observe(document.documentElement,{childList:true,subtree:true});if(document.readyState==='loading')document.addEventListener('DOMContentLoaded',bind,{once:true});else bind();}
  if(typeof module!=='undefined')module.exports={LEVELS,BADGES,EVENT_POINTS,createMasteryState,levelFor,applyMasteryEvent};
})();
