import { Injectable, UnauthorizedException, BadRequestException, NotFoundException } from '@nestjs/common'
import { JwtService } from '@nestjs/jwt'
import * as bcrypt from 'bcrypt'
import { PrismaService } from '../prisma/prisma.service'
import { randomBytes, createHash } from 'crypto'

const ACCESS_TOKEN_TTL = '15m'
const REFRESH_TOKEN_TTL = '30d'
const BCRYPT_ROUNDS = 12
const MAX_SESSIONS_PER_USER = 10

// Final-grade token TTLs (adjust later if you want)
const EMAIL_VERIFY_TTL_MINUTES = 60 * 24 // 24h
const PASSWORD_RESET_TTL_MINUTES = 30 // 30m

type JwtPayload = { sub: string }

export type SessionMeta = {
  userAgent?: string | null
  ip?: string | null
}

@Injectable()
export class AuthService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly jwt: JwtService,
  ) {}

  // ---------------------------
  // Current user (Profile v1)
  // ---------------------------
  async getMe(userId: string) {
    const u = await this.prisma.user.findUnique({
      where: { id: userId },
      select: {
        id: true,
        handle: true,
        displayName: true,
        bio: true,
        avatarUrl: true,
        createdAt: true,
        emailVerifiedAt: true,
      },
    })
    if (!u) throw new NotFoundException('User not found')
    return u
  }

  // ---------------------------
  // Registration
  // ---------------------------
  async register(email: string, password: string, handle: string, displayName?: string, meta?: SessionMeta) {
    const existing = await this.prisma.user.findFirst({
      where: { OR: [{ email }, { handle }] },
      select: { id: true },
    })
    if (existing) throw new BadRequestException('User already exists')

    const passwordHash = await bcrypt.hash(password, BCRYPT_ROUNDS)

    const user = await this.prisma.user.create({
      data: {
        email,
        handle,
        displayName: displayName ?? handle,
        passwordHash,
      },
      select: { id: true, email: true, handle: true, displayName: true, avatarUrl: true, bio: true, createdAt: true },
    })

    // Create verification token (stored hashed) + enqueue email
    await this.issueEmailVerification(user.id, user.email)

    const tokens = await this.issueTokens(user.id)
    await this.storeRefreshToken(user.id, tokens.refreshToken, meta)

    return { user: this.publicUser(user), ...tokens }
  }

  // ---------------------------
  // Login
  // ---------------------------
  async login(email: string, password: string, meta?: SessionMeta) {
    const user = await this.prisma.user.findUnique({ where: { email } })
    if (!user) throw new UnauthorizedException('Invalid credentials')

    const ok = await bcrypt.compare(password, user.passwordHash)
    if (!ok) throw new UnauthorizedException('Invalid credentials')

    const tokens = await this.issueTokens(user.id)
    await this.storeRefreshToken(user.id, tokens.refreshToken, meta)

    return { user: this.publicUser(user), ...tokens }
  }

  // ---------------------------
  // Refresh (refreshToken-only, replay-detect)
  // ---------------------------
  async refresh(refreshToken: string, meta?: SessionMeta) {
    const userId = this.verifyRefreshAndGetUserId(refreshToken)

    const sessions = await this.prisma.userSession.findMany({
      where: { userId, revokedAt: null },
      orderBy: { createdAt: 'desc' },
    })

    // 1) normal match (current token)
    const match = await this.matchAgainstHash(refreshToken, sessions, 'refreshTokenHash')
    if (match) {
      const tokens = await this.issueTokens(userId)
      const newHash = await bcrypt.hash(tokens.refreshToken, BCRYPT_ROUNDS)

      await this.prisma.userSession.update({
        where: { id: match.id },
        data: {
          prevRefreshTokenHash: match.refreshTokenHash,
          refreshTokenHash: newHash,
          userAgent: match.userAgent ?? meta?.userAgent ?? null,
          ip: match.ip ?? meta?.ip ?? null,
        },
      })

      return tokens
    }

    // 2) replay detection
    const replay = await this.matchAgainstHash(refreshToken, sessions, 'prevRefreshTokenHash')
    if (replay) {
      await this.prisma.userSession.updateMany({
        where: { userId, revokedAt: null },
        data: { revokedAt: new Date() },
      })
      throw new UnauthorizedException('Session replay detected')
    }

    throw new UnauthorizedException('Invalid session')
  }

  // ---------------------------
  // Logout (single session)
  // ---------------------------
  async logout(userId: string, refreshToken: string) {
    const sub = this.verifyRefreshAndGetUserId(refreshToken)
    if (sub !== userId) throw new UnauthorizedException('Invalid session')

    const sessions = await this.prisma.userSession.findMany({
      where: { userId, revokedAt: null },
      orderBy: { createdAt: 'desc' },
    })

    const match = await this.matchAgainstHash(refreshToken, sessions, 'refreshTokenHash')
    if (!match) return { ok: true }

    await this.prisma.userSession.update({
      where: { id: match.id },
      data: { revokedAt: new Date() },
    })

    return { ok: true }
  }

  // ---------------------------
  // Logout everywhere
  // ---------------------------
  async logoutAll(userId: string) {
    await this.prisma.userSession.updateMany({
      where: { userId, revokedAt: null },
      data: { revokedAt: new Date() },
    })
    return { ok: true }
  }

  // ---------------------------
  // A) Email verification
  // ---------------------------
  async resendEmailVerification(email: string, _meta?: SessionMeta) {
    // Always behave the same (no enumeration).
    const user = await this.prisma.user.findUnique({
      where: { email },
      select: { id: true, email: true, emailVerifiedAt: true },
    })
    if (!user) return
    if (user.emailVerifiedAt) return

    await this.issueEmailVerification(user.id, user.email)
  }

  async verifyEmail(token: string) {
    const tokenHash = this.hashToken(token)

    const t = await this.prisma.authToken.findFirst({
      where: {
        type: 'EMAIL_VERIFY',
        tokenHash,
        consumedAt: null,
        expiresAt: { gt: new Date() },
      },
      select: { id: true, userId: true },
    })

    if (!t) throw new BadRequestException('Invalid or expired token')

    await this.prisma.$transaction([
      this.prisma.authToken.update({
        where: { id: t.id },
        data: { consumedAt: new Date() },
      }),
      this.prisma.user.update({
        where: { id: t.userId },
        data: { emailVerifiedAt: new Date() },
      }),
    ])
  }

  // ---------------------------
  // A) Password reset
  // ---------------------------
  async requestPasswordReset(email: string, _meta?: SessionMeta) {
    // Always behave the same (no enumeration).
    const user = await this.prisma.user.findUnique({
      where: { email },
      select: { id: true, email: true },
    })
    if (!user) return

    const rawToken = this.newRawToken()
    const tokenHash = this.hashToken(rawToken)
    const expiresAt = this.minutesFromNow(PASSWORD_RESET_TTL_MINUTES)

    await this.prisma.$transaction([
      // Invalidate older reset tokens (optional, but keeps system clean)
      this.prisma.authToken.updateMany({
        where: { userId: user.id, type: 'PASSWORD_RESET', consumedAt: null },
        data: { consumedAt: new Date() },
      }),
      this.prisma.authToken.create({
        data: {
          type: 'PASSWORD_RESET',
          userId: user.id,
          tokenHash,
          expiresAt,
        },
      }),
      this.prisma.emailOutbox.create({
        data: {
          toEmail: user.email,
          subject: 'Reset your password',
          body: `Use this token to reset your password:\n\n${rawToken}\n\nThis token expires in ${PASSWORD_RESET_TTL_MINUTES} minutes.`,
          meta: { kind: 'PASSWORD_RESET' },
        },
      }),
    ])
  }

  async resetPassword(token: string, newPassword: string, _meta?: SessionMeta) {
    if (!newPassword || newPassword.length < 8 || newPassword.length > 72) {
      throw new BadRequestException('Invalid password')
    }

    const tokenHash = this.hashToken(token)

    const t = await this.prisma.authToken.findFirst({
      where: {
        type: 'PASSWORD_RESET',
        tokenHash,
        consumedAt: null,
        expiresAt: { gt: new Date() },
      },
      select: { id: true, userId: true },
    })

    if (!t) throw new BadRequestException('Invalid or expired token')

    const passwordHash = await bcrypt.hash(newPassword, BCRYPT_ROUNDS)

    await this.prisma.$transaction([
      this.prisma.authToken.update({
        where: { id: t.id },
        data: { consumedAt: new Date() },
      }),
      this.prisma.user.update({
        where: { id: t.userId },
        data: { passwordHash },
      }),
      // Final-grade security: revoke active sessions after password reset
      this.prisma.userSession.updateMany({
        where: { userId: t.userId, revokedAt: null },
        data: { revokedAt: new Date() },
      }),
    ])
  }

  // ---------------------------
  // Token issuance
  // ---------------------------
  private async issueTokens(userId: string) {
    const payload: JwtPayload = { sub: userId }

    const accessToken = await this.jwt.signAsync(payload, { expiresIn: ACCESS_TOKEN_TTL })
    const refreshToken = await this.jwt.signAsync(payload, { expiresIn: REFRESH_TOKEN_TTL })

    return { accessToken, refreshToken }
  }

  // ---------------------------
  // Session storage + limits
  // ---------------------------
  private async storeRefreshToken(userId: string, refreshToken: string, meta?: SessionMeta) {
    const hash = await bcrypt.hash(refreshToken, BCRYPT_ROUNDS)

    await this.prisma.userSession.create({
      data: {
        userId,
        refreshTokenHash: hash,
        prevRefreshTokenHash: null,
        userAgent: meta?.userAgent ?? null,
        ip: meta?.ip ?? null,
      },
    })

    const sessions = await this.prisma.userSession.findMany({
      where: { userId, revokedAt: null },
      orderBy: { createdAt: 'desc' },
      select: { id: true },
    })

    if (sessions.length > MAX_SESSIONS_PER_USER) {
      const overflow = sessions.slice(MAX_SESSIONS_PER_USER)
      await this.prisma.userSession.updateMany({
        where: { id: { in: overflow.map((s) => s.id) } },
        data: { revokedAt: new Date() },
      })
    }
  }

  private async matchAgainstHash(
    token: string,
    sessions: any[],
    field: 'refreshTokenHash' | 'prevRefreshTokenHash',
  ) {
    for (const s of sessions) {
      const hash = s[field]
      if (!hash) continue
      const ok = await bcrypt.compare(token, hash)
      if (ok) return s
    }
    return null
  }

  private verifyRefreshAndGetUserId(refreshToken: string): string {
    try {
      const payload = this.jwt.verify(refreshToken, {
        secret: process.env.JWT_SECRET,
      }) as JwtPayload

      if (!payload?.sub) throw new UnauthorizedException('Invalid token')
      return payload.sub
    } catch {
      throw new UnauthorizedException('Invalid token')
    }
  }

  // ---------------------------
  // Email verification helper
  // ---------------------------
  private async issueEmailVerification(userId: string, email: string) {
    const rawToken = this.newRawToken()
    const tokenHash = this.hashToken(rawToken)
    const expiresAt = this.minutesFromNow(EMAIL_VERIFY_TTL_MINUTES)

    await this.prisma.$transaction([
      // Invalidate older verification tokens
      this.prisma.authToken.updateMany({
        where: { userId, type: 'EMAIL_VERIFY', consumedAt: null },
        data: { consumedAt: new Date() },
      }),
      this.prisma.authToken.create({
        data: {
          type: 'EMAIL_VERIFY',
          userId,
          tokenHash,
          expiresAt,
        },
      }),
      this.prisma.emailOutbox.create({
        data: {
          toEmail: email,
          subject: 'Verify your email',
          body: `Use this token to verify your email:\n\n${rawToken}\n\nThis token expires in 24 hours.`,
          meta: { kind: 'EMAIL_VERIFY' },
        },
      }),
    ])
  }

  private newRawToken(): string {
    // URL-safe-ish token
    return randomBytes(32).toString('hex')
  }

  private hashToken(raw: string): string {
    return createHash('sha256').update(raw).digest('hex')
  }

  private minutesFromNow(minutes: number): Date {
    return new Date(Date.now() + minutes * 60 * 1000)
  }

  // ---------------------------
  // Helpers
  // ---------------------------
  private publicUser(user: any) {
    return {
      id: user.id,
      email: user.email,
      handle: user.handle,
      displayName: user.displayName,
      bio: user.bio ?? null,
      avatarUrl: user.avatarUrl ?? null,
      createdAt: user.createdAt ?? null,
    }
  }
}
