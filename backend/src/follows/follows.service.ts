import { Injectable, NotFoundException } from '@nestjs/common'
import { PrismaService } from '../prisma/prisma.service'

@Injectable()
export class FollowsService {
  constructor(private readonly prisma: PrismaService) {}

  async follow(viewerId: string, handle: string) {
    const h = handle.trim().toLowerCase()

    const target = await this.prisma.user.findUnique({
      where: { handle: h },
      select: { id: true, handle: true, displayName: true, avatarUrl: true },
    })
    if (!target) throw new NotFoundException('User not found')

    // Self-follow: return ok without writing
    if (target.id === viewerId) {
      return { ok: true, following: target }
    }

    await this.prisma.follow.upsert({
      where: { followerId_followingId: { followerId: viewerId, followingId: target.id } },
      create: { followerId: viewerId, followingId: target.id },
      update: {},
    })

    // Optional: follow notification (kept from your earlier logic)
    await this.prisma.notification.create({
      data: {
        userId: target.id,
        actorId: viewerId,
        type: 'follow',
      },
    })

    return { ok: true, following: target }
  }

  async unfollow(viewerId: string, handle: string) {
    const h = handle.trim().toLowerCase()

    const target = await this.prisma.user.findUnique({
      where: { handle: h },
      select: { id: true },
    })
    if (!target) throw new NotFoundException('User not found')

    if (target.id === viewerId) return { ok: true }

    await this.prisma.follow.deleteMany({
      where: { followerId: viewerId, followingId: target.id },
    })

    return { ok: true }
  }

  async listFollowing(viewerId: string) {
    const rows = await this.prisma.follow.findMany({
      where: { followerId: viewerId },
      orderBy: { createdAt: 'desc' },
      include: {
        following: { select: { id: true, handle: true, displayName: true, avatarUrl: true } },
      },
      take: 200,
    })

    return { data: rows.map((r) => r.following) }
  }

  async isFollowing(viewerId: string, handle: string) {
    const h = handle.trim().toLowerCase()

    const target = await this.prisma.user.findUnique({
      where: { handle: h },
      select: { id: true },
    })
    if (!target) throw new NotFoundException('User not found')

    if (target.id === viewerId) return { following: true }

    const found = await this.prisma.follow.findUnique({
      where: { followerId_followingId: { followerId: viewerId, followingId: target.id } },
    })

    return { following: !!found }
  }
}
