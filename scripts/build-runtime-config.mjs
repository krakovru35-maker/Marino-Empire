import path from 'node:path';
import { buildArtifact } from './runtime-config-lib.mjs';

const rootDir = process.cwd();
const manifest = buildArtifact({
  rootDir,
  publicDir: path.join(rootDir, 'public'),
  distDir: path.join(rootDir, 'dist'),
  input: {
    targetEnvironment: process.env.MARINO_TARGET_ENV,
    supabaseUrl: process.env.MARINO_SUPABASE_URL,
    supabasePublishableKey: process.env.MARINO_SUPABASE_PUBLISHABLE_KEY,
    expectedProjectRef: process.env.MARINO_EXPECTED_PROJECT_REF,
    productionProjectRef: process.env.MARINO_PRODUCTION_PROJECT_REF,
    stagingProjectRef: process.env.MARINO_STAGING_PROJECT_REF,
    commitSha: process.env.MARINO_COMMIT_SHA,
    buildTime: process.env.MARINO_BUILD_TIME,
  },
});

console.log(`runtime artifact: environment=${manifest.targetEnvironment} projectRef=${manifest.projectRef} config=${manifest.configFile}`);
