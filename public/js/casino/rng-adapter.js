(() => {
  'use strict';
  function hash(seed){let h=2166136261;for(const char of String(seed)){h^=char.charCodeAt(0);h=Math.imul(h,16777619)}return h>>>0;}
  function create(seed){let value=hash(seed)||0x9e3779b9;return Object.freeze({next(){value+=0x6d2b79f5;let t=value;t=Math.imul(t^t>>>15,t|1);t^=t+Math.imul(t^t>>>7,t|61);return((t^t>>>14)>>>0)/4294967296;},int(max){return Math.floor(this.next()*max);},seed:String(seed)});}
  if(typeof window!=='undefined')window.MarinoRng=Object.freeze({create,hash});
  if(typeof module!=='undefined')module.exports={create,hash};
})();
