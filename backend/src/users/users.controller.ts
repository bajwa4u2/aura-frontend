import {
  Body,
  Controller,
  Get,
  NotFoundException,
  Param,
  Patch,
  Post,
  UseGuards,
  BadRequestException,
} from '@nestjs/common'

import { JwtAuthGuard } from '../common/guards/jwt-auth.guard'
import { CurrentUserId } from '../common/decorators/current-user.decorator'
import { UsersService } from './users.service'
import { PrismaService } from '../prisma/prisma.service'

type UpdateMeBody = {
  displayName?: string | null
  bio?: string | null
  avatarUrl?: string | null
}

// Normalize incoming "optional + nullable" fields into:
// - undefined => not provided
// - string (possibly empty) => provided (empty means "clear")
function normalizeField(v: unknown): string | undefined {
  if (v === undefined) return undefined
  if (v === null) return '' // clear
  if (typeof v !== 'string') return undefined
  return v.trim()
}

function clampLen(s: string, max: number): string {
  if (s.length <= max) return s
  return s.slice(0, max)
}

@Controller('users')
export class UsersController {
  constructor(
    private readonly users: UsersService,
    private readonly prisma: PrismaService,
  ) {}

  // -----------------------------
  // ME (logged-in)
  // IMPORTANT: keep BEFORE :handle
  // -----------------------------

  // GET /v1/users/me (logged-in)
  @UseGuards(JwtAuthGuard)
  @Get('me')
  async me(@CurrentUserId() userId: string) {
    const user = await this.users.getPublicById(userId)
    if (!user) throw new NotFoundException('User not found')
    return { data: user }
  }

  // PATCH /v1/users/me (logged-in)
  // Canonical profile update route.
  @UseGuards(JwtAuthGuard)
  @Patch('me')
  async updateMe(@CurrentUserId() userId: string, @Body() body: UpdateMeBody) {
    const displayNameRaw = normalizeField(body?.displayName)
    const bioRaw = normalizeField(body?.bio)
    const avatarUrlRaw = normalizeField(body?.avatarUrl)

    // If client sent nothing we can act on, fail fast.
    if (displayNameRaw === undefined && bioRaw === undefined && avatarUrlRaw === undefined) {
      throw new BadRequestException('No profile fields provided')
    }

    // Apply basic limits (stable UI, avoids abuse)
    const displayName = displayNameRaw === undefined ? undefined : clampLen(displayNameRaw, 64)
    const bio = bioRaw === undefined ? undefined : clampLen(bioRaw, 600)
    let avatarUrl = avatarUrlRaw === undefined ? undefined : clampLen(avatarUrlRaw, 512)

    // Avatar URL: only validate when non-empty. Empty means "clear".
    if (avatarUrl !== undefined && avatarUrl.length > 0) {
      if (!/^https?:\/\/.+/i.test(avatarUrl)) {
        throw new BadRequestException('avatarUrl must be an http(s) URL')
      }
    }

    // Prisma schema in your project treats displayName as non-nullable (String).
    // So we NEVER send null. Clearing becomes empty string.
    await this.prisma.user.update({
      where: { id: userId },
      data: {
        ...(displayName !== undefined ? { displayName } : {}),
        ...(bio !== undefined ? { bio } : {}),
        ...(avatarUrl !== undefined ? { avatarUrl } : {}),
      },
      select: { id: true },
    })

    const user = await this.users.getPublicById(userId)
    if (!user) throw new NotFoundException('User not found')
    return { data: user }
  }

  // -----------------------------
  // PROFILE ALIASES (logged-in)
  // Keeps Flutter/back-compat stable.
  // -----------------------------

  // PATCH /v1/users/profile (alias)
  @UseGuards(JwtAuthGuard)
  @Patch('profile')
  async updateProfileAlias(@CurrentUserId() userId: string, @Body() body: UpdateMeBody) {
    return this.updateMe(userId, body)
  }

  // POST /v1/users/profile (alias)
  @UseGuards(JwtAuthGuard)
  @Post('profile')
  async updateProfileAliasPost(@CurrentUserId() userId: string, @Body() body: UpdateMeBody) {
    return this.updateMe(userId, body)
  }

  // -----------------------------
  // PUBLIC PROFILE (by handle)
  // -----------------------------

  // GET /v1/users/:handle (public)
  @Get(':handle')
  async getByHandle(@Param('handle') handle: string) {
    const user = await this.users.getPublicByHandle(handle)
    if (!user) throw new NotFoundException('User not found')
    return { data: user }
  }

  // GET /v1/users/:handle/following (public)
  @Get(':handle/following')
  async following(@Param('handle') handle: string) {
    return this.users.listFollowingByHandle(handle)
  }

  // GET /v1/users/:handle/followers (public)
  @Get(':handle/followers')
  async followers(@Param('handle') handle: string) {
    return this.users.listFollowersByHandle(handle)
  }

  // POST /v1/users/:handle/follow (logged-in)
  // Toggles follow/unfollow.
  @UseGuards(JwtAuthGuard)
  @Post(':handle/follow')
  async toggleFollow(@CurrentUserId() userId: string, @Param('handle') handle: string) {
    return this.users.toggleFollowByHandle(userId, handle)
  }
}
