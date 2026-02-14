import { Injectable, NotFoundException } from '@nestjs/common'
import { PrismaService } from '../prisma/prisma.service'

@Injectable()
export class ReactionsService {
  constructor(private prisma: PrismaService) {}

  async react(userId: string, postId: string) {
    if (!userId) throw new NotFoundException('User not found')

    await this.prisma.reaction.upsert({
      where: { userId_postId: { userId, postId } },
      update: {},
      create: { userId, postId },
    })

    return { ok: true }
  }

  async unreact(userId: string, postId: string) {
    if (!userId) throw new NotFoundException('User not found')

    await this.prisma.reaction.deleteMany({
      where: { userId, postId },
    })

    return { ok: true }
  }

  // ✅ needed by GET /reactions/:postId
  async isLiked(userId: string, postId: string) {
    if (!userId) throw new NotFoundException('User not found')

    const found = await this.prisma.reaction.findUnique({
      where: { userId_postId: { userId, postId } },
      select: { id: true },
    })

    return { liked: !!found }
  }

  // ✅ needed by POST /reactions/:postId/toggle
  async toggle(userId: string, postId: string) {
    if (!userId) throw new NotFoundException('User not found')

    const found = await this.prisma.reaction.findUnique({
      where: { userId_postId: { userId, postId } },
      select: { id: true },
    })

    if (found) {
      await this.prisma.reaction.delete({
        where: { userId_postId: { userId, postId } },
      })
      return { liked: false }
    }

    await this.prisma.reaction.create({
      data: { userId, postId },
    })

    return { liked: true }
  }
}
