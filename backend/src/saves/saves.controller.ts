import {
  Controller,
  Param,
  Post,
  Delete,
  Get,
  UseGuards,
  BadRequestException,
  Query,
} from '@nestjs/common'
import { JwtAuthGuard } from '../common/guards/jwt-auth.guard'
import { CurrentUserId } from '../common/decorators/current-user.decorator'
import { SavesService } from './saves.service'

@UseGuards(JwtAuthGuard)
@Controller('saves')
export class SavesController {
  constructor(private readonly saves: SavesService) {}

  // ✅ NEW: GET /v1/saves?limit=12
  @Get()
  async listMine(
    @CurrentUserId() userId: string,
    @Query('limit') limitRaw?: string,
  ) {
    const limitNum = Number(limitRaw ?? 12)
    const limit = Number.isFinite(limitNum)
      ? Math.max(1, Math.min(50, limitNum))
      : 12

    if (typeof (this.saves as any).listMine !== 'function') {
      throw new BadRequestException(
        'Saves list not supported by current service implementation',
      )
    }

    return this.saves.listMine(userId, limit)
  }

  @Post(':postId')
  async save(@CurrentUserId() userId: string, @Param('postId') postId: string) {
    return this.saves.save(userId, postId)
  }

  @Delete(':postId')
  async unsave(
    @CurrentUserId() userId: string,
    @Param('postId') postId: string,
  ) {
    return this.saves.unsave(userId, postId)
  }

  @Post(':postId/toggle')
  async toggle(
    @CurrentUserId() userId: string,
    @Param('postId') postId: string,
  ) {
    const svc: any = this.saves as any

    if (typeof svc.toggle === 'function') {
      return svc.toggle(userId, postId)
    }

    if (
      typeof svc.isSaved === 'function' &&
      typeof svc.save === 'function' &&
      typeof svc.unsave === 'function'
    ) {
      const out = await svc.isSaved(userId, postId)
      const saved =
        typeof out === 'boolean'
          ? out
          : out && typeof out === 'object' && 'saved' in out
          ? Boolean((out as any).saved)
          : Boolean(out)

      return saved
        ? svc.unsave(userId, postId)
        : svc.save(userId, postId)
    }

    throw new BadRequestException(
      'Saves toggle not supported by current service implementation',
    )
  }

  @Get(':postId')
  async isSaved(
    @CurrentUserId() userId: string,
    @Param('postId') postId: string,
  ) {
    const svc: any = this.saves as any

    if (typeof svc.isSaved === 'function') {
      return svc.isSaved(userId, postId)
    }

    if (typeof svc.hasSave === 'function') {
      const saved = await svc.hasSave(userId, postId)
      return { saved: Boolean(saved) }
    }

    return { saved: false }
  }
}
