(() => {
  'use strict';
  const state={balance:5000,history:[]};
  const preview=()=>window.MarinoPhase2BBridge?.isPreview?.()===true;
  const phaseState=()=>window.MarinoPhase2B?.getDemoState?.()||{entitlements:{spin:0,bet:0}};
  function snapshot(){const rights=phaseState().entitlements;return Object.freeze({balance:state.balance,freeSpins:Number(rights.spin||0),freeBets:Number(rights.bet||0)});}
  function debit(amount){amount=Number(amount);if(!Number.isFinite(amount)||amount<=0||amount>state.balance)return false;state.balance-=amount;return true;}
  function credit(amount,reason='demo'){amount=Number(amount);if(!Number.isFinite(amount)||amount<=0)return false;state.balance+=amount;state.history.unshift({amount,reason,at:Date.now()});state.history=state.history.slice(0,10);return true;}
  function consume(type){if(!preview()||!['spin','bet'].includes(type))return false;return window.MarinoPhase2B?.consumeDemoEntitlement?.(type)===true;}
  window.MarinoDemoWallet=Object.freeze({snapshot,debit,credit,consume,isPreview:preview,history:()=>state.history.slice(),authority:'memory-only-demo'});
})();
