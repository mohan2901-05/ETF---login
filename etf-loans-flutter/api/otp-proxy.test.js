const { TextEncoder, TextDecoder } = require('util');
global.TextEncoder = TextEncoder;
global.TextDecoder = TextDecoder;

const PROXIED_PATHS = [
  '/api/auth/otp/send',
  '/api/auth/otp/verify',
  '/api/auth/me',
  '/api/auth/logout',
];

function isProxiedPath(path) {
  return PROXIED_PATHS.some(p => path === p || path.startsWith(p + '/'));
}

function corsHeaders(origin, allowedOrigins) {
  const allowed = allowedOrigins.includes('*') || allowedOrigins.includes(origin);
  return {
    'Access-Control-Allow-Origin': allowed ? origin : (allowedOrigins[0] || ''),
    'Access-Control-Allow-Methods': 'POST, GET, OPTIONS',
    'Access-Control-Allow-Headers': 'Content-Type, Authorization',
    'Access-Control-Allow-Credentials': 'false',
    'Vary': 'Origin',
  };
}

function runTests() {
  let passed = 0;
  let failed = 0;

  function assert(condition, message) {
    if (condition) {
      console.log(`✓ ${message}`);
      passed++;
    } else {
      console.error(`✗ ${message}`);
      failed++;
    }
  }

  console.log('\n=== isProxiedPath tests ===');
  assert(isProxiedPath('/api/auth/otp/send'), 'matches exact send path');
  assert(isProxiedPath('/api/auth/otp/verify'), 'matches exact verify path');
  assert(isProxiedPath('/api/auth/me'), 'matches exact me path');
  assert(isProxiedPath('/api/auth/logout'), 'matches exact logout path');
  assert(!isProxiedPath('/api/auth/unknown'), 'rejects unknown path');
  assert(!isProxiedPath('/api/other'), 'rejects different prefix');

  console.log('\n=== corsHeaders tests ===');
  const origins = ['https://app.vercel.app', 'https://other.vercel.app'];
  
  const cors1 = corsHeaders('https://app.vercel.app', origins);
  assert(cors1['Access-Control-Allow-Origin'] === 'https://app.vercel.app', 'allows configured origin');
  
  const cors2 = corsHeaders('https://evil.com', origins);
  assert(cors2['Access-Control-Allow-Origin'] === 'https://app.vercel.app', 'rejects unknown origin (returns first allowed)');
  
  const cors3 = corsHeaders('https://app.vercel.app', ['*']);
  assert(cors3['Access-Control-Allow-Origin'] === 'https://app.vercel.app', 'allows any origin when wildcard configured');

  console.log(`\n=== Results: ${passed} passed, ${failed} failed ===`);
  
  if (failed > 0) {
    process.exit(1);
  }
}

runTests();