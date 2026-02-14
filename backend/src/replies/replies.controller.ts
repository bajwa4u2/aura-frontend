import { Controller, Get, Query, UseGuards } from '@nestjs/common'
import { JwtAuthGuard } from '../common/guards/jwt-auth.guard'
import { CurrentUserId } from '../common/decorators/current-user.decorator'
import { RepliesService } from './replies.service'

@Controller('replies')
export class RepliesController {
  constructor(private readonly replies: RepliesService) {}

  // GET /v1/replies/me (logged-in)
  @UseGuards(JwtAuthGuard)
  @Get('me')
  async me(@CurrentUserId() userId: string, @Query('cursor') cursor?: string, @Query('limit') limit?: string) {
    return this.replies.listMyReplies(userId, cursor || undefined, limit ? Number(limit) : undefined)
  }

  // GET /v1/replies/mine (logged-in) - alias
  @UseGuards(JwtAuthGuard)
  @Get('mine')
  async mine(@CurrentUserId() userId: string, @Query('cursor') cursor?: string, @Query('limit') limit?: string) {
    return this.replies.listMyReplies(userId, cursor || undefined, limit ? Number(limit) : undefined)
  }

  // GET /v1/replies?scope=me (logged-in) - alias
  @UseGuards(JwtAuthGuard)
  @Get()
  async list(@CurrentUserId() userId: string, @Query('scope') scope?: string, @Query('cursor') cursor?: string, @Query('limit') limit?: string) {
    const sc = (scope ?? '').trim().toLowerCase()
    if (sc === 'me' || sc === 'mine') {
      return this.replies.listMyReplies(userId, cursor || undefined, limit ? Number(limit) : undefined)
    }
    return { data: [], nextCursor: null }
  }
}
