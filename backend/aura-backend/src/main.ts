import { NestFactory } from '@nestjs/core'
import { ValidationPipe } from '@nestjs/common'
import { AppModule } from './app.module'
import * as express from 'express'
import * as path from 'path'

import { AuraHttpExceptionFilter } from './common/http/aura-http-exception.filter'
import { requestIdMiddleware } from './common/middleware/request-id.middleware'
import { rateLimitMiddleware } from './common/middleware/rate-limit.middleware'

async function bootstrap() {
  const app = await NestFactory.create(AppModule)

  // Serve uploaded files (NOT under /v1). This keeps URLs like /uploads/xxx.jpg.
  app.use('/uploads', express.static(path.join(process.cwd(), 'uploads')))

  // Request ID first (for consistent error shape + logs)
  app.use(requestIdMiddleware())

  // Basic rate limiting (global + stricter for auth)
  app.use(rateLimitMiddleware())

  // All API routes under /v1 (matches Flutter dio_provider normalization)
  app.setGlobalPrefix('v1')

  // DTO validation hardening
  app.useGlobalPipes(
    new ValidationPipe({
      whitelist: true,
      forbidNonWhitelisted: true,
      transform: true,
      transformOptions: { enableImplicitConversion: true },
    }),
  )

  // Consistent error shape across the whole API
  app.useGlobalFilters(new AuraHttpExceptionFilter())

  // Minimal cookie parsing (avoids external dependency).
  app.use((req: any, _res: any, next: any) => {
    const raw = req.headers?.cookie as string | undefined
    const cookies: Record<string, string> = {}
    if (raw) {
      for (const part of raw.split(';')) {
        const i = part.indexOf('=')
        if (i <= 0) continue
        const k = part.slice(0, i).trim()
        const v = part.slice(i + 1).trim()
        if (k) cookies[k] = decodeURIComponent(v)
      }
    }
    req.cookies = cookies
    next()
  })

  // CORS: allow credentials for cookies, but do NOT be wide-open in production.
  const origins = (process.env.CORS_ORIGINS ?? '')
    .split(',')
    .map((s) => s.trim())
    .filter(Boolean)

  const isProd = (process.env.NODE_ENV ?? '').toLowerCase() === 'production'

  app.enableCors({
    origin: (origin, cb) => {
      // Non-browser / same-origin requests may have no origin.
      if (!origin) return cb(null, true)

      // In dev: if not configured, allow all (keeps momentum locally).
      if (!isProd && origins.length === 0) return cb(null, true)

      // In prod: require allowlist.
      if (origins.includes(origin)) return cb(null, true)

      return cb(new Error('CORS blocked'), false)
    },
    credentials: true,
    methods: ['GET', 'POST', 'PUT', 'PATCH', 'DELETE', 'OPTIONS'],
    allowedHeaders: ['Content-Type', 'Authorization', 'x-token-transport', 'x-request-id'],
  })

  const port = Number(process.env.PORT ?? 3000)

  // Bind on all interfaces so WSL IP + localhost both work.
  await app.listen(port, '0.0.0.0')
}
bootstrap()
