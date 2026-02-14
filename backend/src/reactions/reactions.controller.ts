import { Controller, Get, Param, Post, UseGuards } from '@nestjs/common'
import { JwtAuthGuard } from '../common/guards/jwt-auth.guard'
import { CurrentUserId } from '../common/decorators/current-user.decorator'
import { ReactionsService } from './reactions.service'

@UseGuards(JwtAuthGuard)
@Controller('reactions')
export class ReactionsController {
  constructor(private readonly reactions: ReactionsService) {}

  @Get(':postId')
  async isLiked(
    @CurrentUserId() userId: string,
    @Param('postId') postId: string,
  ) {
    return this.reactions.isLiked(userId, postId)
  }

  @Post(':postId/toggle')
  async toggle(
    @CurrentUserId() userId: string,
    @Param('postId') postId: string,
  ) {
    return this.reactions.toggle(userId, postId)
  }
}
