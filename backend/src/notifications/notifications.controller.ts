import { Controller, Get, Param, Post, Query, UseGuards } from '@nestjs/common'
import { JwtAuthGuard } from '../common/guards/jwt-auth.guard'
import { CurrentUser } from '../common/decorators/current-user.decorator'
import { NotificationsService } from './notifications.service'

@UseGuards(JwtAuthGuard)
@Controller('notifications')
export class NotificationsController {
  constructor(private readonly notifications: NotificationsService) {}

  @Get()
  async list(
    @CurrentUser() user: { userId: string },
    @Query('cursor') cursor?: string,
    @Query('limit') limit?: string,
  ) {
    const parsedLimit = limit ? Number(limit) : undefined
    const safeLimit = Number.isFinite(parsedLimit as number) ? (parsedLimit as number) : undefined
    return this.notifications.list(user.userId, { cursor, limit: safeLimit })
  }

  @Post(':id/read')
  async read(@CurrentUser() user: { userId: string }, @Param('id') id: string) {
    return this.notifications.markRead(user.userId, id)
  }

  @Post('read-all')
  async readAll(@CurrentUser() user: { userId: string }) {
    return this.notifications.markAllRead(user.userId)
  }
}
