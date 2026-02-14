import {
  Body,
  Controller,
  Get,
  Headers,
  Post,
  Req,
  Res,
  UnauthorizedException,
  UseGuards,
} from '@nestjs/common'
import type { Request, Response } from 'express'

import { AuthService } from './auth.service'
import { LoginDto } from './dto/login.dto'
import { RegisterDto } from './dto/register.dto'
import { RefreshDto } from './dto/refresh.dto'
import { VerifyEmailDto } from './dto/verify-email.dto'
import { ResendVerificationDto } from './dto/resend-verification.dto'
import { ForgotPasswordDto } from './dto/forgot-password.dto'
import { ResetPasswordDto } from './dto/reset-password.dto'

import { JwtAuthGuard } from '../common/guards/jwt-auth.guard'
import { CurrentUserId } from '../common/decorators/current-user.decorator'

const RT_COOKIE = 'rt'

function refreshCookieOptions() {
  return {
    httpOnly: true,
    sameSite: 'lax' as const,
    secure: false, // set true behind https/proxy in prod
    path: '/v1/auth/refresh',
  }
}

function getIp(req: Request) {
  const xf = req.headers['x-forwarded-for']
  if (typeof xf === 'string' && xf.length) return xf.split(',')[0].trim()
  return (req.socket as any)?.remoteAddress
}

type LogoutBody = {
  userId?: string
  refreshToken?: string
}

@Controller('auth') // global prefix already sets /v1, so routes become /v1/auth/*
export class AuthController {
  constructor(private readonly auth: AuthService) {}

  private meta(req: Request) {
    return {
      ip: getIp(req) ?? null,
      userAgent: (req.headers['user-agent'] as string | undefined) ?? null,
    }
  }

  // Token transport:
  // - default: cookie transport (web) => set cookie, DO NOT return refreshToken in body
  // - if header 'x-token-transport: body' => return refreshToken in JSON (mobile-friendly)

  @Post('register')
  async register(
    @Req() req: Request,
    @Res({ passthrough: true }) res: Response,
    @Body() dto: RegisterDto,
    @Headers('x-token-transport') transport?: string,
  ) {
    const email = (dto as any).email as string
    const password = (dto as any).password as string
    const displayName = (dto as any).displayName as string | undefined

    let handle = ((dto as any).handle as string | undefined)?.trim()
    if (!handle) {
      handle = email?.split('@')[0]?.trim() || 'user'
    }

    const out = await this.auth.register(email, password, handle, displayName, this.meta(req))

    res.cookie(RT_COOKIE, out.refreshToken, refreshCookieOptions())

    if ((transport ?? '').toLowerCase() === 'body') {
      return out // includes refreshToken
    }

    return { user: out.user, accessToken: out.accessToken }
  }

  @Post('login')
  async login(
    @Req() req: Request,
    @Res({ passthrough: true }) res: Response,
    @Body() dto: LoginDto,
    @Headers('x-token-transport') transport?: string,
  ) {
    const out = await this.auth.login(dto.email, dto.password, this.meta(req))

    res.cookie(RT_COOKIE, out.refreshToken, refreshCookieOptions())

    if ((transport ?? '').toLowerCase() === 'body') {
      return out // includes refreshToken
    }

    return { user: out.user, accessToken: out.accessToken }
  }

  @Post('refresh')
  async refresh(
    @Req() req: Request,
    @Res({ passthrough: true }) res: Response,
    @Body() dto: RefreshDto,
    @Headers('x-token-transport') transport?: string,
  ) {
    const headerTransport = (transport ?? '').toLowerCase() === 'body'

    const cookieRt = (req as any).cookies?.[RT_COOKIE] as string | undefined
    const bodyRt = dto.refreshToken
    const rt = cookieRt || bodyRt

    if (!rt) throw new UnauthorizedException('Missing refresh token')

    const tokens = await this.auth.refresh(rt, this.meta(req))

    res.cookie(RT_COOKIE, tokens.refreshToken, refreshCookieOptions())

    if (headerTransport) {
      return tokens // includes refreshToken
    }

    return { accessToken: tokens.accessToken }
  }

  @Post('logout')
  async logout(@Req() req: Request, @Res({ passthrough: true }) res: Response, @Body() body: LogoutBody) {
    const cookieRt = (req as any).cookies?.[RT_COOKIE] as string | undefined
    const rt = cookieRt || body.refreshToken
    if (!rt) throw new UnauthorizedException('Missing refresh token')

    const userId = (body.userId ?? '').trim()
    if (!userId) throw new UnauthorizedException('Missing userId')

    await this.auth.logout(userId, rt)

    res.clearCookie(RT_COOKIE, { path: refreshCookieOptions().path })
    return { ok: true }
  }

  @Post('logout-all')
  async logoutAll(@Body() body: { userId?: string }) {
    const userId = (body.userId ?? '').trim()
    if (!userId) throw new UnauthorizedException('Missing userId')

    await this.auth.logoutAll(userId)
    return { ok: true }
  }

  // ✅ GET /v1/auth/me (fixes Profile v1 "who am I" 404)
  @UseGuards(JwtAuthGuard)
  @Get('me')
  async me(@CurrentUserId() userId: string) {
    const data = await this.auth.getMe(userId)
    return { data }
  }

  // --------------------------------------
  // A) Identity hardening: email verification
  // --------------------------------------

  @Post('verify-email')
  async verifyEmail(@Body() dto: VerifyEmailDto) {
    await this.auth.verifyEmail(dto.token)
    return { ok: true }
  }

  @Post('resend-verification')
  async resendVerification(@Req() req: Request, @Body() dto: ResendVerificationDto) {
    // Always respond ok (avoid email enumeration)
    await this.auth.resendEmailVerification(dto.email, this.meta(req))
    return { ok: true }
  }

  // --------------------------------------
  // A) Identity hardening: password reset
  // --------------------------------------

  @Post('forgot-password')
  async forgotPassword(@Req() req: Request, @Body() dto: ForgotPasswordDto) {
    // Always respond ok (avoid email enumeration)
    await this.auth.requestPasswordReset(dto.email, this.meta(req))
    return { ok: true }
  }

  @Post('reset-password')
  async resetPassword(@Req() req: Request, @Body() dto: ResetPasswordDto) {
    await this.auth.resetPassword(dto.token, dto.newPassword, this.meta(req))
    return { ok: true }
  }
}
