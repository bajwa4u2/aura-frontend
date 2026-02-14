import { Injectable } from '@nestjs/common'
import { PrismaService } from '../prisma/prisma.service'

@Injectable()
export class SavesService {
  constructor(private readonly prisma: PrismaService) {}

  async listMine(userId: string, limit: number) {
    const rows = await this.prisma.save.findMany({
      where: { userId },
      orderBy: { createdAt: 'desc' },
      take: limit,
      include: {
        post: {
          include: {
            author: {
              select: {
                id: true,
                handle: true,
                displayName: true,
                avatarUrl: true,
              },
            },
          },
        },
      },
    })

    return rows.map((r) => ({
      id: r.id,
      postId: r.postId,
      createdAt: r.createdAt,
      text: r.post?.text ?? '',
      postCreatedAt: r.post?.createdAt ?? null,
      author: r.post?.author ?? null,
    }))
  }

  async save(userId: string, postId: string) {
    return this.prisma.save.create({
      data: { userId, postId },
    })
  }

  async unsave(userId: string, postId: string) {
    return this.prisma.save.deleteMany({
      where: { userId, postId },
    })
  }

  async isSaved(userId: string, postId: string) {
    const found = await this.prisma.save.findFirst({
      where: { userId, postId },
    })
    return { saved: Boolean(found) }
  }
}
