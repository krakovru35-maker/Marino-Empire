(() => {
  'use strict';

  const STATES=Object.freeze({IDLE:'IDLE',BETTING:'BETTING',DEALING:'DEALING',PLAYER_TURN:'PLAYER_TURN',DEALER_TURN:'DEALER_TURN',SETTLING:'SETTLING',PRESENTING_RESULT:'PRESENTING_RESULT',ERROR:'ERROR'});
  const SUITS=['spades','hearts','diamonds','clubs'];
  const RANKS=['A','2','3','4','5','6','7','8','9','10','J','Q','K'];
  const SUIT_GLYPH={spades:'♠',hearts:'♥',diamonds:'♦',clubs:'♣'};
  const cardValue=rank=>rank==='A'?11:['K','Q','J'].includes(rank)?10:Number(rank);

  function createShoe(rng,decks=6){
    const cards=[];
    for(let deck=0;deck<decks;deck++)for(const suit of SUITS)for(const rank of RANKS)cards.push({rank,suit,id:`${deck}-${suit}-${rank}`});
    for(let i=cards.length-1;i>0;i--){const j=rng.int(i+1);[cards[i],cards[j]]=[cards[j],cards[i]];}
    return{cards,index:0,cut:Math.floor(cards.length*.72),decks};
  }
  function handValue(cards){let total=cards.reduce((sum,card)=>sum+cardValue(card.rank),0),aces=cards.filter(card=>card.rank==='A').length;while(total>21&&aces){total-=10;aces--;}return{total,soft:aces>0,blackjack:cards.length===2&&total===21,bust:total>21};}
  const dealerShouldHit=cards=>{const value=handValue(cards);return value.total<17||(value.total===17&&value.soft);};
  const canDouble=hand=>hand.cards.length===2&&!hand.done;
  const canSplit=hand=>hand.cards.length===2&&!hand.done&&(hand.cards[0].rank===hand.cards[1].rank||cardValue(hand.cards[0].rank)===cardValue(hand.cards[1].rank));
  function settleHand(hand,dealerCards){const player=handValue(hand.cards),dealerValue=handValue(dealerCards),stake=hand.bet;if(player.bust)return{result:'BUST',payout:0};if(player.blackjack&&!hand.fromSplit&&!dealerValue.blackjack)return{result:'BLACKJACK',payout:stake*2.5};if(dealerValue.blackjack&&!player.blackjack)return{result:'DEALER',payout:0};if(dealerValue.bust||player.total>dealerValue.total)return{result:'WIN',payout:stake*2};if(player.total===dealerValue.total)return{result:'PUSH',payout:stake};return{result:'DEALER',payout:0};}
  function createEngine(seed='blackjack-demo'){const rng=(typeof window!=='undefined'?window.MarinoRng:globalThis.MarinoRng)?.create(seed);if(!rng)throw Error('RNG adapter unavailable');let shoe=createShoe(rng);return{draw(){if(shoe.index>=shoe.cut)shoe=createShoe(rng);return shoe.cards[shoe.index++];},snapshot:()=>({index:shoe.index,cut:shoe.cut,cards:shoe.cards.map(card=>card.id)}),reshuffle(){shoe=createShoe(rng);}};}

  let root=null,engine=null,phase=STATES.IDLE,bet=25,dealer=[],hands=[],activeHand=0,freeBetArmed=false,history=[],timers=[],paused=false,dealerRevealUntil=0,dealCursor=0;
  const haptic=style=>{try{window.Telegram?.WebApp?.HapticFeedback?.impactOccurred?.(style);}catch(_){}};
  const schedule=(callback,delay)=>{const id=setTimeout(()=>{timers=timers.filter(timer=>timer!==id);if(!paused)callback();},delay);timers.push(id);return id;};
  const clearTimers=()=>{timers.forEach(clearTimeout);timers=[];};
  const active=()=>hands[activeHand];

  function cardMarkup(card,hidden=false,index=0,flip=false){
    if(hidden)return`<article class="blackjack-card card-back" style="--card-index:${index}" aria-label="Kapalı dealer kartı"><div><b>M</b><span>MARINO</span></div></article>`;
    const red=card.suit==='hearts'||card.suit==='diamonds';
    return`<article class="blackjack-card ${red?'red':'black'} ${flip?'card-reveal':''}" style="--card-index:${index}" aria-label="${card.rank} ${card.suit}"><span class="card-corner top"><b>${card.rank}</b><i>${SUIT_GLYPH[card.suit]}</i></span><strong>${SUIT_GLYPH[card.suit]}</strong><span class="card-corner bottom"><b>${card.rank}</b><i>${SUIT_GLYPH[card.suit]}</i></span></article>`;
  }
  function economy(){return window.MarinoEconomyBridge}
  function parseServerCard(code){const value=String(code||'');const rank=value.slice(0,-1).replace('0','10')||'A',suitCode=value.slice(-1);const suit={S:'spades',H:'hearts',D:'diamonds',C:'clubs'}[suitCode]||'spades';return{rank,suit,id:value};}
  function applyServerBlackjack(server){const state=server?.state||server;if(!state)return false;dealer=(state.dealer_hand||[]).map(parseServerCard);hands=[{cards:(state.player_hand||[]).map(parseServerCard),bet:Number(state.bet||bet),done:state.status!=='playing',fromSplit:false,free:false,outcome:state.status}];activeHand=0;if(state.status==='playing')phase=STATES.PLAYER_TURN;else{phase=STATES.PRESENTING_RESULT;const payout=Number(state.win_amount||0),result=root?.querySelector('[data-blackjack-result]');if(result){result.className=`blackjack-result show ${payout?'win':'dealer'}`;result.innerHTML=`<small>SERVER BLACKJACK</small><strong>${String(state.status||'sonuc').toUpperCase()}</strong><span>${payout} CHIP</span>`;}history.unshift(`${String(state.status||'sonuc').toUpperCase()} - ${payout} server`);history=history.slice(0,10);}window.MarinoGameShell?.refreshWallet?.();render();return true;}
  function markup(){
    const el=document.createElement('div');el.className='marino-blackjack';
    el.innerHTML=`<header class="blackjack-title"><span>MARINO CASINO</span><h2>BLACKJACK LOUNGE</h2><small>6 DECK • DEALER HITS SOFT 17 • SERVER</small></header><section class="blackjack-table"><div class="blackjack-rail"><b>M</b><span>BLACKJACK PAYS 3 TO 2</span></div><div class="blackjack-shoe" aria-hidden="true"><i></i><span>6 DECK</span></div><div class="dealer-zone"><label>DEALER <b data-dealer-score>—</b></label><div class="blackjack-cards" data-dealer-cards></div></div><div class="blackjack-emblem">M<small>VIP LOUNGE</small></div><div class="player-zone" data-player-zone><label>PLAYER <b data-player-score>—</b></label><div class="blackjack-hands" data-blackjack-hands></div></div><div class="blackjack-result" data-blackjack-result aria-live="polite"></div></section><section class="blackjack-controls"><div class="blackjack-bet"><button type="button" data-blackjack="minus" aria-label="Bahsi azalt">−</button><span><small>BAHİS</small><b data-blackjack-bet>${bet}</b></span><button type="button" data-blackjack="plus" aria-label="Bahsi artır">+</button></div><button type="button" class="blackjack-free" data-blackjack="free">FREE BET <b>0</b></button><button type="button" class="blackjack-deal" data-blackjack="deal">DAĞIT</button><div class="blackjack-actions"><button type="button" data-blackjack="hit">HIT</button><button type="button" data-blackjack="stand">STAND</button><button type="button" data-blackjack="double">DOUBLE</button><button type="button" data-blackjack="split">SPLIT</button></div><div class="blackjack-secondary"><button type="button" data-blackjack="rules">KURALLAR</button><button type="button" data-blackjack="history">GEÇMİŞ</button></div><p class="blackjack-virtual-notice">Sanal hak, nakit değeri yoktur</p><p data-blackjack-message>Bahsini seç ve kartları dağıt.</p></section>`;
    el.addEventListener('click',onClick);root=el;render();return el;
  }
  function render(){
    if(!root)return;
    root.querySelector('[data-blackjack-bet]').textContent=bet;
    root.querySelector('.blackjack-free b').textContent=window.MarinoDemoWallet?.snapshot?.().freeBets||0;
    const reveal=[STATES.DEALER_TURN,STATES.SETTLING,STATES.PRESENTING_RESULT].includes(phase);
    root.querySelector('[data-dealer-cards]').innerHTML=dealer.map((card,index)=>cardMarkup(card,index===1&&!reveal,index,index===1&&reveal&&Date.now()<dealerRevealUntil)).join('');
    root.querySelector('[data-dealer-score]').textContent=dealer.length?(reveal?handValue(dealer).total:cardValue(dealer[0].rank)):'—';
    root.querySelector('[data-blackjack-hands]').innerHTML=hands.map((hand,index)=>`<div class="blackjack-hand ${index===activeHand?'active':''} ${hand.outcome?'result-'+hand.outcome.toLowerCase():''}" data-hand="${index}"><span>EL ${index+1} • BAHİS ${hand.bet}</span><div class="blackjack-cards">${hand.cards.map((card,cardIndex)=>cardMarkup(card,false,cardIndex)).join('')}</div><b>${handValue(hand.cards).total}</b></div>`).join('')||'<div class="blackjack-empty">Kartlar burada dağıtılır</div>';
    root.querySelector('[data-player-score]').textContent=active()?handValue(active().cards).total:'—';
    const playerTurn=phase===STATES.PLAYER_TURN,hand=active(),dealButton=root.querySelector('[data-blackjack="deal"]');
    dealButton.disabled=![STATES.IDLE,STATES.BETTING].includes(phase);dealButton.textContent=phase===STATES.PRESENTING_RESULT?'YENİ EL':'DAĞIT';
    root.querySelector('[data-blackjack="hit"]').disabled=!playerTurn;root.querySelector('[data-blackjack="stand"]').disabled=!playerTurn;
    const serverMode=!economy()?.preview;
    root.querySelector('[data-blackjack="double"]').disabled=serverMode||!playerTurn||!canDouble(hand);root.querySelector('[data-blackjack="split"]').disabled=serverMode||!playerTurn||!canSplit(hand)||hands.length>=4;
    root.querySelectorAll('[data-blackjack="minus"],[data-blackjack="plus"],[data-blackjack="free"]').forEach(button=>button.disabled=![STATES.IDLE,STATES.BETTING].includes(phase));
    root.classList.toggle('is-paused',paused);
  }
  function message(text){const element=root?.querySelector('[data-blackjack-message]');if(element)element.textContent=text;}
  function drawTo(target){const card=engine.draw();target.push(card);window.MarinoAudio?.play?.('card_deal');return card;}
  function continueDeal(){
    if(phase!==STATES.DEALING||paused)return;
    const targets=[hands[0].cards,dealer,hands[0].cards,dealer];
    if(dealCursor<targets.length){drawTo(targets[dealCursor]);dealCursor+=1;render();schedule(continueDeal,115);return;}
    schedule(beginPlayer,110);
  }
  async function deal(){
    if(![STATES.IDLE,STATES.BETTING].includes(phase))return false;if(paused)return false;
    const bridge=economy();
    if(!bridge?.preview){
      if(!bridge?.ready?.())return message('Guvenli server oturumu hazir degil. Oyunu Telegram uzerinden yeniden ac.');
      clearTimers();phase=STATES.DEALING;render();
      try{return applyServerBlackjack(await bridge.blackjackDeal(bet));}
      catch(error){phase=STATES.IDLE;render();return message(error?.message||'Blackjack islemi sunucu tarafindan onaylanmadi.');}
    }
    const useFree=freeBetArmed&&window.MarinoDemoWallet?.consume?.('bet');
    if(!useFree&&!window.MarinoDemoWallet?.debit?.(bet))return message('Önizleme jetonu yetersiz.');
    clearTimers();phase=STATES.DEALING;dealer=[];hands=[{cards:[],bet,done:false,fromSplit:false,free:Boolean(useFree)}];activeHand=0;freeBetArmed=false;dealerRevealUntil=0;dealCursor=0;haptic('light');render();continueDeal();return true;
  }
  function beginPlayer(){const player=handValue(active().cards),dealerValue=handValue(dealer);if(player.blackjack||dealerValue.blackjack)return dealerTurn();phase=STATES.PLAYER_TURN;message('Kararını ver: Hit, Stand, Double veya Split.');render();}
  async function hit(){if(phase!==STATES.PLAYER_TURN||paused)return false;if(!economy()?.preview){try{return applyServerBlackjack(await economy().blackjackHit());}catch(error){return message(error?.message||'Hit islemi sunucu tarafindan onaylanmadi.');}}window.MarinoAudio?.play?.('hit');drawTo(active().cards);haptic('soft');const value=handValue(active().cards);if(value.bust){active().done=true;window.MarinoAudio?.play?.('bust');haptic('light');return nextHand();}if(value.total===21){active().done=true;return nextHand();}render();return true;}
  async function stand(){if(phase!==STATES.PLAYER_TURN||paused)return false;if(!economy()?.preview){try{return applyServerBlackjack(await economy().blackjackStand());}catch(error){return message(error?.message||'Stand islemi sunucu tarafindan onaylanmadi.');}}window.MarinoAudio?.play?.('stand');active().done=true;return nextHand();}
  function doubleDown(){if(!economy()?.preview)return message('Double icin server kontrati henuz kapali.');const hand=active();if(phase!==STATES.PLAYER_TURN||paused||!canDouble(hand)||!window.MarinoDemoWallet?.debit?.(hand.bet))return false;window.MarinoAudio?.play?.('double');hand.bet*=2;drawTo(hand.cards);hand.done=true;haptic('medium');return nextHand();}
  function split(){if(!economy()?.preview)return message('Split icin server kontrati henuz kapali.');const hand=active();if(phase!==STATES.PLAYER_TURN||paused||!canSplit(hand)||hands.length>=4||!window.MarinoDemoWallet?.debit?.(hand.bet))return false;window.MarinoAudio?.play?.('split');const second={cards:[hand.cards.pop()],bet:hand.bet,done:false,fromSplit:true,free:false};hand.fromSplit=true;hands.splice(activeHand+1,0,second);drawTo(hand.cards);drawTo(second.cards);if(hand.cards[0].rank==='A'){hand.done=true;second.done=true;}haptic('medium');render();if(hand.done)return nextHand();return true;}
  function nextHand(){render();const next=hands.findIndex((hand,index)=>index>activeHand&&!hand.done);if(next>=0){activeHand=next;phase=STATES.PLAYER_TURN;render();return true;}return dealerTurn();}
  function dealerTurn(){phase=STATES.DEALER_TURN;dealerRevealUntil=Date.now()+650;window.MarinoAudio?.play?.('dealer_reveal');window.MarinoAudio?.play?.('card_flip');render();const step=()=>{if(dealerShouldHit(dealer)){drawTo(dealer);render();schedule(step,260);}else settle();};schedule(step,300);return true;}
  function resetRound(){phase=STATES.IDLE;message('Yeni el için bahsini seç.');render();}
  function settle(){
    phase=STATES.SETTLING;let totalPayout=0;
    for(const hand of hands){const outcome=settleHand(hand,dealer);hand.outcome=outcome.result;totalPayout+=outcome.payout;if(outcome.payout)window.MarinoDemoWallet?.credit?.(outcome.payout,'blackjack-lounge');}
    const best=hands.some(hand=>hand.outcome==='BLACKJACK')?'BLACKJACK':hands.some(hand=>hand.outcome==='WIN')?'WIN':hands.every(hand=>hand.outcome==='PUSH')?'PUSH':hands.every(hand=>hand.outcome==='BUST')?'BUST':'DEALER';
    phase=STATES.PRESENTING_RESULT;const labels={BLACKJACK:'BLACKJACK!',WIN:'KAZANDIN',PUSH:'PUSH',BUST:'BUST',DEALER:'DEALER WIN'},result=root.querySelector('[data-blackjack-result]');result.className=`blackjack-result show ${best.toLowerCase()}`;result.innerHTML=`<small>MARINO LOUNGE</small><strong>${labels[best]}</strong><span>${totalPayout} ÖNİZLEME JETON</span>`;
    window.MarinoAudio?.play?.(best==='BLACKJACK'?'blackjack_win':best==='WIN'?'normal_win':best==='PUSH'?'push':best==='BUST'?'bust':'ui_close');haptic(best==='BLACKJACK'?'heavy':best==='WIN'?'medium':'light');history.unshift(`${labels[best]} • ${totalPayout} önizleme`);history=history.slice(0,10);window.MarinoGameShell?.refreshWallet?.();render();schedule(resetRound,900);
  }
  function onClick(event){
    const action=event.target.closest('[data-blackjack]')?.dataset.blackjack;if(!action)return;
    if(action==='minus'&&[STATES.IDLE,STATES.BETTING].includes(phase)){bet=Math.max(5,bet-5);phase=STATES.BETTING;window.MarinoAudio?.play?.('chip_place');}
    if(action==='plus'&&[STATES.IDLE,STATES.BETTING].includes(phase)){bet=Math.min(100,bet+5);phase=STATES.BETTING;window.MarinoAudio?.play?.('chip_place');}
    if(action==='free'&&[STATES.IDLE,STATES.BETTING].includes(phase)){if((window.MarinoDemoWallet?.snapshot?.().freeBets||0)>0){freeBetArmed=true;message('Sanal Free Bet hazır.');}else message('Kullanılabilir önizleme Free Bet yok.');}
    if(action==='deal')deal();if(action==='hit')hit();if(action==='stand')stand();if(action==='double')doubleDown();if(action==='split')split();if(action==='rules')window.MarinoGameShell?.openPanel?.('rules');if(action==='history')window.MarinoGameShell?.openPanel?.('history');if(['minus','plus','free'].includes(action))render();
  }
  function setPaused(value){
    if(paused===Boolean(value))return;paused=Boolean(value);
    if(paused){clearTimers();render();return;}
    if(phase===STATES.DEALING)continueDeal();else if(phase===STATES.DEALER_TURN)dealerTurn();else if(phase===STATES.SETTLING)settle();else if(phase===STATES.PRESENTING_RESULT)schedule(resetRound,300);render();
  }

  const game={name:'Marino Blackjack Lounge',mount:markup,isActive:()=>![STATES.IDLE,STATES.BETTING,STATES.PRESENTING_RESULT].includes(phase),setPaused,onOpen:()=>{engine=createEngine(`blackjack-${Date.now()}`);phase=STATES.IDLE;paused=false;render();},onClose:()=>{clearTimers();paused=false;phase=STATES.IDLE;},history:()=>history.slice(),rules:'<p>6 deste kullanılır. Dealer soft 17’de kart çeker. Natural Blackjack 3:2, normal kazanç 1:1, Push bahis iadesidir.</p><p>Insurance ve surrender yoktur. En fazla üç split ile dört el oynanabilir. Split aslara yalnız bir kart verilir. Tüm jeton ve haklar sanal önizlemedir.</p>'};
  if(typeof window!=='undefined')window.MarinoBlackjack=Object.freeze(game);
  if(typeof module!=='undefined')module.exports={STATES,SUITS,RANKS,cardValue,createShoe,handValue,dealerShouldHit,canDouble,canSplit,settleHand,createEngine};
})();
