import { Controller, Delete, Get, Param, Post, UseGuards } from '@nestjs/common'
import { JwtAuthGuard } from '../common/guards/jwt-auth.guard'
import { CurrentUserId } from '../common/decorators/current-user.decorator'
import { FollowsService } from './follows.service'

@UseGuards(JwtAuthGuard)
@Controller('follows')
export class FollowsController {
  constructor(private readonly follows: FollowsService) {}

  @Get()
  async listFollowing(@CurrentUserId() viewerId: string) {
    return this.follows.listFollowing(viewerId)
  }

  @Get('is-following/:handle')
  async isFollowing(@CurrentUserId() viewerId: string, @Param('handle') handle: string) {
    return this.follows.isFollowing(viewerId, handle)
  }

  @Post(':handle')
  async follow(@CurrentUserId() viewerId: string, @Param('handle') handle: string) {
    return this.follows.follow(viewerId, handle)
  }

  @Delete(':handle')
  async unfollow(@CurrentUserId() viewerId: string, @Param('handle') handle: string) {
    return this.follows.unfollow(viewerId, handle)
  }
}
