import { Injectable } from '@nestjs/common'
import { PrismaService } from '../prisma/prisma.service'

type ListOptions = {
  cursor?: string
  limit?: number
}

@Injectable()
export class NotificationsService {
  constructor(private readonly prisma: PrismaService) {}

  async list(userId: string, opts?: ListOptions) {
    const take = Math.min(Math.max(opts?.limit ?? 50, 1), 100)

    const data = await this.prisma.notification.findMany({
      where: { userId },
      take,
      ...(opts?.cursor
        ? {
            cursor: { id: opts.cursor },
            skip: 1,
          }
        : {}),
      orderBy: [{ createdAt: 'desc' }, { id: 'desc' }],
      include: {
        actor: { select: { id: true, handle: true, displayName: true, avatarUrl: true } },
        post: { select: { id: true, text: true, createdAt: true } },
      },
    })

    // No count exposure: return items + nextCursor only.
    const nextCursor = data.length === take ? data[data.length - 1].id : null

    return { data, nextCursor }
  }

  async markRead(userId: string, id: string) {
    const n = await this.prisma.notification.findUnique({
      where: { id },
      select: { id: true, userId: true, readAt: true },
    })

    // Do not leak existence; do not error. Just "ok".
    if (!n || n.userId !== userId) return { ok: true }
    if (n.readAt) return { ok: true }

    await this.prisma.notification.update({
      where: { id },
      data: { readAt: new Date() },
    })
    return { ok: true }
  }

  async markAllRead(userId: string) {
    await this.prisma.notification.updateMany({
      where: { userId, readAt: null },
      data: { readAt: new Date() },
    })
    return { ok: true }
  }
}
