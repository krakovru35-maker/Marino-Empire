(() => {
  'use strict';

  const ASSETS = {
    ui_open:{file:'./assets/audio/sfx/ui_open.ogg',available:false,fallback:[460,.06,'triangle']},
    ui_close:{file:'./assets/audio/sfx/ui_close.ogg',available:false,fallback:[320,.07,'sine']},
    ui_confirm:{file:'./assets/audio/sfx/ui_confirm.ogg',available:false,fallback:[680,.09,'triangle']},
    ui_error:{file:'./assets/audio/sfx/ui_error.ogg',available:false,fallback:[190,.14,'sawtooth']},
    tap_light:{file:'./assets/audio/sfx/tap_light.ogg',available:false,fallback:[520,.035,'sine'],rateLimit:45},
    tap_combo:{file:'./assets/audio/sfx/tap_combo.ogg',available:false,fallback:[720,.06,'triangle'],rateLimit:70},
    collect_vault:{file:'./assets/audio/sfx/collect_vault.ogg',available:false,fallback:[760,.13,'triangle']},
    building_upgrade:{file:'./assets/audio/sfx/building_upgrade.ogg',available:false,fallback:[620,.16,'triangle']},
    task_complete:{file:'./assets/audio/sfx/task_complete.ogg',available:false,fallback:[840,.14,'triangle']},
    daily_reward:{file:'./assets/audio/sfx/daily_reward.ogg',available:false,fallback:[920,.2,'triangle']},
    reward_purchase:{file:'./assets/audio/sfx/reward_purchase.ogg',available:false,fallback:[780,.14,'triangle']},
    free_spin_unlock:{file:'./assets/audio/sfx/free_spin_unlock.ogg',available:false,fallback:[1040,.18,'sine']},
    free_bet_unlock:{file:'./assets/audio/sfx/free_bet_unlock.ogg',available:false,fallback:[880,.18,'triangle']},
    league_up:{file:'./assets/audio/sfx/league_up.ogg',available:false,fallback:[980,.22,'triangle']},
    empire_rush:{file:'./assets/audio/sfx/empire_rush.ogg',available:false,fallback:[1160,.2,'sawtooth']},
    reel_start:{file:'./assets/audio/sfx/reel_start.ogg',available:false,fallback:[180,.12,'sawtooth'],layer:[1.5,.01,.38],sweep:1.7,rateLimit:120},reel_loop:{file:'./assets/audio/sfx/reel_loop.ogg',available:false,fallback:[135,.22,'sawtooth'],layer:[2.02,.025,.2],sweep:.82,rateLimit:180},anticipation_ping:{file:'./assets/audio/sfx/anticipation_ping.ogg',available:false,fallback:[920,.16,'sine'],layer:[1.5,.04,.32]},free_spin_trigger:{file:'./assets/audio/sfx/free_spin_trigger.ogg',available:false,fallback:[760,.28,'triangle'],layer:[1.5,.05,.42],sweep:1.35},
    reel_stop_1:{file:'./assets/audio/sfx/reel_stop_1.ogg',available:false,fallback:[320,.045,'triangle']},reel_stop_2:{file:'./assets/audio/sfx/reel_stop_2.ogg',available:false,fallback:[360,.045,'triangle']},reel_stop_3:{file:'./assets/audio/sfx/reel_stop_3.ogg',available:false,fallback:[400,.045,'triangle']},reel_stop_4:{file:'./assets/audio/sfx/reel_stop_4.ogg',available:false,fallback:[440,.045,'triangle']},reel_stop_5:{file:'./assets/audio/sfx/reel_stop_5.ogg',available:false,fallback:[480,.045,'triangle']},
    symbol_match:{file:'./assets/audio/sfx/symbol_match.ogg',available:false,fallback:[720,.08,'triangle']},scatter_anticipation:{file:'./assets/audio/sfx/scatter_anticipation.ogg',available:false,fallback:[880,.12,'sine']},small_win:{file:'./assets/audio/sfx/small_win.ogg',available:false,fallback:[760,.15,'triangle']},big_win:{file:'./assets/audio/sfx/big_win.ogg',available:false,fallback:[1040,.24,'sawtooth']},free_spin_start:{file:'./assets/audio/sfx/free_spin_start.ogg',available:false,fallback:[940,.18,'triangle']},free_spin_end:{file:'./assets/audio/sfx/free_spin_end.ogg',available:false,fallback:[560,.14,'sine']},
    chip_place:{file:'./assets/audio/sfx/chip_place.ogg',available:false,fallback:[520,.04,'triangle'],layer:[1.35,0,.25],rateLimit:45},chip_remove:{file:'./assets/audio/sfx/chip_remove.ogg',available:false,fallback:[330,.04,'sine'],rateLimit:45},wheel_start:{file:'./assets/audio/sfx/wheel_start.ogg',available:false,fallback:[210,.16,'sawtooth'],layer:[1.48,.02,.24],sweep:.72},ball_roll:{file:'./assets/audio/sfx/ball_roll.ogg',available:false,fallback:[680,.24,'triangle'],layer:[1.18,.018,.18],sweep:.62,rateLimit:180},ball_tick:{file:'./assets/audio/sfx/ball_tick.ogg',available:false,fallback:[760,.025,'triangle'],rateLimit:55},ball_drop:{file:'./assets/audio/sfx/ball_drop.ogg',available:false,fallback:[420,.11,'triangle'],layer:[.5,.025,.28]},roulette_win:{file:'./assets/audio/sfx/roulette_win.ogg',available:false,fallback:[880,.2,'triangle'],layer:[1.5,.045,.4]},roulette_lose:{file:'./assets/audio/sfx/roulette_lose.ogg',available:false,fallback:[260,.09,'sine']},
    card_deal:{file:'./assets/audio/sfx/card_deal.ogg',available:false,fallback:[480,.055,'triangle'],layer:[.72,.012,.18],rateLimit:45},card_flip:{file:'./assets/audio/sfx/card_flip.ogg',available:false,fallback:[620,.07,'sine'],sweep:.68},hit:{file:'./assets/audio/sfx/blackjack_hit.ogg',available:false,fallback:[540,.06,'triangle'],sweep:.82,rateLimit:65},stand:{file:'./assets/audio/sfx/blackjack_stand.ogg',available:false,fallback:[330,.08,'sine'],layer:[.5,.018,.2]},double:{file:'./assets/audio/sfx/blackjack_double.ogg',available:false,fallback:[460,.11,'triangle'],layer:[1.5,.025,.3]},split:{file:'./assets/audio/sfx/blackjack_split.ogg',available:false,fallback:[690,.13,'sine'],layer:[.75,.025,.28]},blackjack_win:{file:'./assets/audio/sfx/blackjack_win.ogg',available:false,fallback:[920,.25,'triangle'],layer:[1.5,.04,.42],sweep:1.28},normal_win:{file:'./assets/audio/sfx/normal_win.ogg',available:false,fallback:[760,.18,'triangle'],layer:[1.25,.035,.3]},push:{file:'./assets/audio/sfx/push.ogg',available:false,fallback:[430,.12,'sine'],layer:[1.01,.03,.18]},bust:{file:'./assets/audio/sfx/bust.ogg',available:false,fallback:[220,.13,'triangle'],sweep:.55},dealer_reveal:{file:'./assets/audio/sfx/dealer_reveal.ogg',available:false,fallback:[570,.1,'sine'],layer:[.5,.03,.2]}
  };
  const state={context:null,unlocked:false,voices:0,maxVoices:6,lastPlayed:new Map(),buffers:new Map(),failed:new Set(),missingReported:false,musicEnabled:false,musicWasPlaying:false};
  const sfxEnabled=()=>document.querySelector('#swSfx')?.classList.contains('on')===true;
  const lite=()=>document.documentElement.dataset.quality==='lite';

  function context(){
    if(!state.unlocked||!sfxEnabled())return null;
    const Ctor=window.AudioContext||window.webkitAudioContext;if(!Ctor)return null;
    if(!state.context)state.context=new Ctor();
    if(state.context.state==='suspended')state.context.resume().catch(()=>{});
    return state.context;
  }
  function unlock(){
    if(state.unlocked)return;state.unlocked=true;
    if(sfxEnabled())context();
    setMusicEnabled(document.querySelector('#swMus')?.classList.contains('on')===true);
  }
  function procedural(definition){
    const ctx=context();if(!ctx||state.voices>=(lite()?3:state.maxVoices))return false;
    const [frequency,duration,wave]=definition.fallback;const oscillator=ctx.createOscillator(),gain=ctx.createGain();state.voices+=1;
    oscillator.type=wave;oscillator.frequency.setValueAtTime(frequency,ctx.currentTime);if(definition.sweep)oscillator.frequency.exponentialRampToValueAtTime(Math.max(20,frequency*definition.sweep),ctx.currentTime+duration);gain.gain.setValueAtTime(lite()?.018:.032,ctx.currentTime);gain.gain.exponentialRampToValueAtTime(.001,ctx.currentTime+duration);oscillator.connect(gain);gain.connect(ctx.destination);oscillator.onended=()=>{state.voices=Math.max(0,state.voices-1)};oscillator.start();oscillator.stop(ctx.currentTime+duration+.02);if(definition.layer&&!lite()){const [ratio,delay,mix]=definition.layer,layer=ctx.createOscillator(),layerGain=ctx.createGain(),start=ctx.currentTime+delay;layer.type=wave==='sawtooth'?'triangle':'sine';layer.frequency.setValueAtTime(frequency*ratio,start);layerGain.gain.setValueAtTime(.032*mix,start);layerGain.gain.exponentialRampToValueAtTime(.001,start+duration*.8);layer.connect(layerGain);layerGain.connect(ctx.destination);layer.start(start);layer.stop(start+duration*.82)}return true;
  }
  async function loadBuffer(id,definition){
    if(!definition.available||state.failed.has(id))return null;
    if(state.buffers.has(id))return state.buffers.get(id);
    try{const response=await fetch(definition.file,{cache:'force-cache'});if(!response.ok)throw new Error(`HTTP ${response.status}`);const decoded=await context().decodeAudioData(await response.arrayBuffer());state.buffers.set(id,decoded);return decoded}catch(_){state.failed.add(id);return null}
  }
  async function play(id){
    const definition=ASSETS[id];if(!definition||!state.unlocked||!sfxEnabled())return false;
    const now=performance.now(),last=state.lastPlayed.get(id)||-Infinity;if(now-last<(definition.rateLimit||0))return false;state.lastPlayed.set(id,now);
    const ctx=context();if(!ctx)return false;const buffer=await loadBuffer(id,definition);
    if(buffer&&state.voices<(lite()?3:state.maxVoices)){const source=ctx.createBufferSource();const gain=ctx.createGain();source.buffer=buffer;gain.gain.value=lite()?.35:.62;source.connect(gain);gain.connect(ctx.destination);state.voices+=1;source.onended=()=>{state.voices=Math.max(0,state.voices-1)};source.start();return true}
    return procedural(definition);
  }
  function setMusicEnabled(enabled){
    state.musicEnabled=Boolean(enabled);const music=document.querySelector('#bgMusic');if(!music)return;
    if(!state.musicEnabled||document.hidden){music.pause();return}
    if(state.unlocked)music.play().catch(()=>{});
  }
  function reportMissing(){
    if(state.missingReported)return;state.missingReported=true;const missing=Object.entries(ASSETS).filter(([,asset])=>!asset.available).map(([id,asset])=>`${id}: ${asset.file}`);
    if(missing.length)console.info(`[MarinoAudio] Profesyonel SFX bekleniyor (${missing.length}):\n${missing.join('\n')}`);
  }
  function init(){
    document.addEventListener('pointerdown',unlock,{capture:true,once:true});document.addEventListener('keydown',unlock,{capture:true,once:true});
    document.addEventListener('visibilitychange',()=>{const music=document.querySelector('#bgMusic');if(!music)return;if(document.hidden){state.musicWasPlaying=!music.paused;music.pause()}else if(state.musicWasPlaying&&state.musicEnabled&&state.unlocked)music.play().catch(()=>{})});reportMissing();
  }
  window.MarinoAudio=Object.freeze({play,unlock,setMusicEnabled,ASSETS,MAX_VOICES:6});
  if(document.readyState==='loading')document.addEventListener('DOMContentLoaded',init,{once:true});else init();
})();
