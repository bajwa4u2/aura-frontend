import { Injectable } from '@nestjs/common'
import { PrismaService } from '../prisma/prisma.service'

@Injectable()
export class RepliesService {
  constructor(private readonly prisma: PrismaService) {}

  private authorSelect = { id: true, handle: true, displayName: true, avatarUrl: true } as const

  async listMyReplies(userId: string, cursor?: string, limit?: number) {
    const take = Math.min(Math.max(limit ?? 20, 1), 50)

    const items = await this.prisma.post.findMany({
      where: {
        authorId: userId,
        status: 'PUBLISHED',
        replyToPostId: { not: null },
        visibility: 'PUBLIC',
      },
      take: take + 1,
      ...(cursor ? { skip: 1, cursor: { id: cursor } } : {}),
      orderBy: { createdAt: 'desc' },
      include: { author: { select: this.authorSelect } },
    })

    const hasMore = items.length > take
    const data = hasMore ? items.slice(0, take) : items
    const nextCursor = hasMore ? data[data.length - 1]?.id : null

    return { data, nextCursor }
  }
}
