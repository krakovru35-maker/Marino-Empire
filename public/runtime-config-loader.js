(function initializeRuntimeConfig(global) {
  'use strict';

  const PROJECT_REF_PATTERN = /^[a-z0-9]{20}$/;
  const PUBLISHABLE_KEY_PATTERN = /^sb_publishable_[A-Za-z0-9_-]{8,}$/;

  function projectRefFromUrl(value) {
    try {
      const url = new URL(value);
      if (url.protocol !== 'https:') return null;
      const match = url.hostname.match(/^([a-z0-9]{20})\.supabase\.co$/);
      return match ? match[1] : null;
    } catch (_) {
      return null;
    }
  }

  function read(input) {
    if (!input || typeof input !== 'object') return { ok: false, error: 'runtime_config_missing' };
    const targetEnvironment = input.targetEnvironment;
    const projectRef = input.projectRef;
    const urlProjectRef = projectRefFromUrl(input.supabaseUrl);
    if (!['staging', 'production'].includes(targetEnvironment)) return { ok: false, error: 'runtime_environment_invalid' };
    if (!PROJECT_REF_PATTERN.test(projectRef || '')) return { ok: false, error: 'runtime_project_ref_invalid' };
    if (!urlProjectRef || urlProjectRef !== projectRef) return { ok: false, error: 'runtime_project_ref_mismatch' };
    if (!PUBLISHABLE_KEY_PATTERN.test(input.supabasePublishableKey || '')) return { ok: false, error: 'runtime_publishable_key_invalid' };
    if (!/^[0-9a-f]{7,40}$/i.test(input.commitSha || '')) return { ok: false, error: 'runtime_commit_sha_invalid' };
    if (!Number.isFinite(Date.parse(input.buildTime || ''))) return { ok: false, error: 'runtime_build_time_invalid' };
    // Freeze only prevents accidental mutation; validation is the security boundary.
    return { ok: true, config: Object.freeze({ ...input }) };
  }

  function maskProjectRef(projectRef) {
    return `${projectRef.slice(0, 4)}…${projectRef.slice(-4)}`;
  }

  function showStagingDiagnostic(config) {
    const badge = document.createElement('div');
    badge.id = 'stagingEnvironmentBadge';
    badge.textContent = `Environment: STAGING • ${maskProjectRef(config.projectRef)}`;
    badge.style.cssText = 'position:fixed;top:4px;right:4px;z-index:100000;background:#8b1e1e;color:#fff;padding:4px 8px;border-radius:6px;font:700 10px sans-serif;pointer-events:none';
    document.body.appendChild(badge);
  }

  global.MarinoRuntimeConfig = Object.freeze({ read, projectRefFromUrl, maskProjectRef, showStagingDiagnostic });
})(window);
