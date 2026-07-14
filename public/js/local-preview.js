(() => {
  'use strict';
  const loopbackHosts = new Set(['localhost', '127.0.0.1', '::1']);
  function detect(locationLike, telegramWebApp) {
    const hasFlag = new URLSearchParams(locationLike?.search || '').get('testmode') === '1';
    const isLoopback = loopbackHosts.has(locationLike?.hostname || '');
    const hasTelegramSession = Boolean(telegramWebApp?.initData);
    return hasFlag && isLoopback && !hasTelegramSession;
  }
  window.MarinoLocalPreview = Object.freeze({ detect });
})();
