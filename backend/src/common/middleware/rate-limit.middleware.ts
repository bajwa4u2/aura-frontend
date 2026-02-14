type Bucket = { resetAt: number; count: number }

// Very simple fixed-window in-memory limiter.
// Good enough for v1 hardening; for multi-instance later we can move to Redis.
const buckets = new Map<string, Bucket>()

function getClientIp(req: any): string {
  const xf = req.headers?.['x-forwarded-for']
  if (typeof xf === 'string' && xf.length > 0) return xf.split(',')[0].trim()
  return req.ip || req.connection?.remoteAddress || 'unknown'
}

function clampInt(v: any, def: number, min: number, max: number) {
  const n = Number(v)
  if (!Number.isFinite(n)) return def
  return Math.min(Math.max(Math.floor(n), min), max)
}

export function rateLimitMiddleware() {
  const windowMs = clampInt(process.env.RATE_LIMIT_WINDOW_MS, 5 * 60_000, 10_000, 60 * 60_000)
  const max = clampInt(process.env.RATE_LIMIT_MAX, 300, 10, 50_000)

  // Stricter for auth endpoints
  const authMax = clampInt(process.env.RATE_LIMIT_AUTH_MAX, 30, 5, 5_000)

  return (req: any, res: any, next: any) => {
    const ip = getClientIp(req)
    const url = String(req.originalUrl || req.url || '')

    const isAuth =
      url.startsWith('/v1/auth') ||
      url.startsWith('/v1/sessions') ||
      url.includes('/password/') ||
      url.includes('/verify/')

    const limit = isAuth ? authMax : max
    const key = `${ip}:${isAuth ? 'auth' : 'all'}`

    const now = Date.now()
    const b = buckets.get(key)

    if (!b || now >= b.resetAt) {
      buckets.set(key, { resetAt: now + windowMs, count: 1 })
    } else {
      b.count += 1
      if (b.count > limit) {
        const retryAfter = Math.max(0, Math.ceil((b.resetAt - now) / 1000))
        res.setHeader('retry-after', String(retryAfter))
        return res.status(429).json({
          error: {
            code: 'RATE_LIMITED',
            message: 'Too many requests',
            details: { retryAfterSeconds: retryAfter },
            requestId: req.requestId ?? null,
            timestamp: new Date().toISOString(),
            path: req?.originalUrl ?? null,
          },
        })
      }
    }

    next()
  }
}
