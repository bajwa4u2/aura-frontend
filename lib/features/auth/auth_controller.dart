import {
  BadRequestException,
  Body,
  Controller,
  Get,
  Post,
  Req,
  Res,
  UseGuards,
  UnauthorizedException,
} from '@nestjs/common'
import type { Request } from 'express'

import { PrismaService } from '../prisma/prisma.service'
import { JwtAuthGuard } from '../common/guards/jwt-auth.guard'
import { CurrentUserId } from '../common/decorators/current-user.decorator'

import { AuthService } from './auth.service'
import { LoginDto } from './dto/login.dto'
import { RegisterDto } from './dto/register.dto'
import { ForgotPasswordDto } from './dto/forgot-password.dto'
import { ResetPasswordDto } from './dto/reset-password.dto'
import { ResendVerificationDto } from './dto/resend-verification.dto'
import { VerifyEmailDto } from './dto/verify-email.dto'

@Controller('auth')
export class AuthController {
  constructor(
    private readonly auth: AuthService,
    private readonly prisma: PrismaService,
  ) {}

  private meta(req: any) {
    const forwardedFor = (req.headers?.['x-forwarded-for'] as string | undefined) ?? ''
    const ip = forwardedFor.split(',')[0]?.trim() || req.ip || null
    const userAgent = (req.headers?.['user-agent'] as string | undefined) ?? null
    const origin = (req.headers?.origin as string | undefined) ?? null
    return { ip, userAgent, origin }
  }

  @Post('register')
  async register(@Req() req: Request, @Body() dto: RegisterDto) {
    const email = (dto.email ?? '').trim()
    const password = dto.password ?? ''
    const firstName = (dto.firstName ?? '').trim()
    const lastName = (dto.lastName ?? '').trim()
    const handle = (dto.handle ?? '').trim()
    const displayName = (dto.displayName ?? '').trim()

    if (!email) throw new BadRequestException('Email is required')
    if (!password) throw new BadRequestException('Password is required')
    if (!firstName || !lastName) throw new BadRequestException('First and last name required')

    return this.auth.register(
      email,
      password,
      { firstName, lastName, handle: handle || undefined, displayName: displayName || undefined },
      this.meta(req),
    )
  }

  @Post('login')
  async login(@Req() req: Request, @Body() dto: LoginDto) {
    const email = (dto.email ?? '').trim()
    const password = dto.password ?? ''
    if (!email) throw new BadRequestException('Email is required')
    if (!password) throw new BadRequestException('Password is required')
    return this.auth.login(email, password, this.meta(req))
  }

  @Post('refresh')
  async refresh(@Req() req: Request, @Body() dto: any) {
    const refreshToken = (dto.refreshToken ?? '').trim()
    if (!refreshToken) throw new BadRequestException('Refresh token is required')
    return this.auth.refresh(refreshToken, this.meta(req))
  }

  @Post('logout')
  async logout(@Body() dto: any) {
    const refreshToken = (dto.refreshToken ?? '').trim()
    if (!refreshToken) throw new BadRequestException('Refresh token is required')
    return this.auth.logout(refreshToken)
  }

  @UseGuards(JwtAuthGuard)
  @Post('logout-all')
  async logoutAll(@CurrentUserId() userId: string) {
    return this.auth.logoutAll(userId)
  }

  @Post('forgot-password')
  async forgotPassword(@Body() dto: ForgotPasswordDto) {
    const email = (dto.email ?? '').trim().toLowerCase()
    if (!email) throw new BadRequestException('Email is required')
    return this.auth.forgotPassword(email)
  }

  @Post('reset-password')
  async resetPassword(@Body() dto: ResetPasswordDto) {
    const token = (dto.token ?? '').trim()
    const password = dto.password ?? ''
    if (!token) throw new BadRequestException('Token is required')
    if (!password) throw new BadRequestException('Password is required')
    return this.auth.resetPassword(token, password)
  }

  @Post('resend-verification')
  async resendVerification(@Body() dto: ResendVerificationDto) {
    const email = (dto.email ?? '').trim().toLowerCase()
    if (!email) throw new BadRequestException('Email is required')
    return this.auth.resendEmailVerification(email)
  }

  @UseGuards(JwtAuthGuard)
  @Post('resend-verification/me')
  async resendVerificationMe(@CurrentUserId() userId: string) {
    return this.auth.resendEmailVerificationForUser(userId)
  }

  @UseGuards(JwtAuthGuard)
  @Post('resend-email-verification/me')
  async resendEmailVerificationMeAlias(@CurrentUserId() userId: string) {
    return this.auth.resendEmailVerificationForUser(userId)
  }

  @Post('resend-email-verification')
  async resendEmailVerificationAlias(@Body() dto: ResendVerificationDto) {
    const email = (dto.email ?? '').trim().toLowerCase()
    if (!email) throw new BadRequestException('Email is required')
    return this.auth.resendEmailVerification(email)
  }

  @Post('verify-email')
  async verifyEmail(@Body() dto: VerifyEmailDto) {
    const token = (dto.token ?? '').trim()
    if (!token) throw new BadRequestException('Token is required')
    return this.auth.verifyEmail(token)
  }

  @UseGuards(JwtAuthGuard)
  @Get('me')
  async me(@CurrentUserId() userId: string) {
    const user = await this.prisma.user.findUnique({
      where: { id: userId },
      select: {
        id: true,
        email: true,
        handle: true,
        displayName: true,
        firstName: true,
        lastName: true,
        emailVerifiedAt: true,
      },
    })

    if (!user) throw new UnauthorizedException('Unauthorized')

    return { ok: true, user }
  }
}