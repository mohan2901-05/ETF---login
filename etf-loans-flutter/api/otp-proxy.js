const ALLOWED_ORIGINS = (process.env.CORS_ALLOWED_ORIGINS || '').split(',').map(s => s.trim()).filter(Boolean);
const API_KEY = process.env.ETF_DEMO_API_KEY;
const RENDER_API_URL = process.env.RENDER_API_URL;

const PROXIED_PATHS = [
  '/api/auth/otp/send',
  '/api/auth/otp/verify',
  '/api/auth/me',
  '/api/auth/logout',
];

function isProxiedPath(path) {
  return PROXIED_PATHS.some(p => path === p || path.startsWith(p + '/'));
}

function corsHeaders(origin) {
  const allowed = ALLOWED_ORIGINS.includes('*') || ALLOWED_ORIGINS.includes(origin);
  return {
    'Access-Control-Allow-Origin': allowed ? origin : (ALLOWED_ORIGINS[0] || ''),
    'Access-Control-Allow-Methods': 'POST, GET, OPTIONS',
    'Access-Control-Allow-Headers': 'Content-Type, Authorization',
    'Access-Control-Allow-Credentials': 'false',
    'Vary': 'Origin',
  };
}

function errorResponse(message, status = 500, headers = {}) {
  return new Response(JSON.stringify({ success: false, message }), {
    status,
    headers: { 'Content-Type': 'application/json', ...headers },
  });
}

export default async function handler(req, res) {
  const origin = req.headers.get('origin') || '';
  const method = req.method;
  const url = new URL(req.url);
  const path = url.pathname;

  const cors = corsHeaders(origin);

  if (!isProxiedPath(path)) {
    return errorResponse('Not found', 404, cors);
  }

  if (method === 'OPTIONS') {
    return new Response(null, { status: 204, headers: cors });
  }

  if (!API_KEY) {
    console.error('ETF_DEMO_API_KEY not configured');
    return errorResponse('Server configuration error', 500, cors);
  }

  if (!RENDER_API_URL) {
    console.error('RENDER_API_URL not configured');
    return errorResponse('Server configuration error', 500, cors);
  }

  const forwardHeaders = {
    'Content-Type': 'application/json',
    'X-API-Key': API_KEY,
  };

  if (req.headers.get('authorization')) {
    forwardHeaders['Authorization'] = req.headers.get('authorization');
  }

  let body;
  if (['POST', 'PUT', 'PATCH'].includes(method)) {
    try {
      body = await req.text();
      if (body && body.length > 1024 * 1024) {
        return errorResponse('Request too large', 413, cors);
      }
    } catch {
      body = '';
    }
  }

  const targetUrl = `${RENDER_API_URL.replace(/\/$/, '')}${path}${url.search}`;

  const controller = new AbortController();
  const timeout = setTimeout(() => controller.abort(), 30000);

  try {
    const response = await fetch(targetUrl, {
      method,
      headers: forwardHeaders,
      body: ['GET', 'HEAD'].includes(method) ? undefined : body,
      signal: controller.signal,
    });

    clearTimeout(timeout);

    const responseHeaders = { ...cors };
    response.headers.forEach((value, key) => {
      if (!key.toLowerCase().startsWith('access-control-')) {
        responseHeaders[key] = value;
      }
    });

    const data = await response.text();

    return new Response(data, {
      status: response.status,
      headers: responseHeaders,
    });
  } catch (err) {
    clearTimeout(timeout);
    if (err.name === 'AbortError') {
      return errorResponse('Upstream timeout', 504, cors);
    }
    console.error('Proxy error:', err.message);
    return errorResponse('Upstream error', 502, cors);
  }
}

export const config = {
  api: {
    bodyParser: false,
    responseLimit: '1mb',
  },
};