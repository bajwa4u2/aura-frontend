import { Injectable, NotFoundException, BadRequestException } from '@nestjs/common'
import { PrismaService } from '../prisma/prisma.service'

@Injectable()
export class UsersService {
  constructor(private readonly prisma: PrismaService) {}

  private normalizeHandle(handle: string) {
    const h = (handle ?? '').trim().toLowerCase()
    return h.startsWith('@') ? h.slice(1) : h
  }

  private publicSelect = {
    id: true,
    handle: true,
    displayName: true,
    bio: true,
    avatarUrl: true,
    createdAt: true,
  } as const

  async getPublicById(id: string) {
    const uid = (id ?? '').trim()
    if (!uid) return null

    return this.prisma.user.findUnique({
      where: { id: uid },
      select: this.publicSelect,
    })
  }

  async getPublicByHandle(handle: string) {
    const h = this.normalizeHandle(handle)
    if (!h) return null

    return this.prisma.user.findUnique({
      where: { handle: h },
      select: this.publicSelect,
    })
  }

  async listFollowingByHandle(handle: string) {
    const h = this.normalizeHandle(handle)
    if (!h) throw new NotFoundException('User not found')

    const user = await this.prisma.user.findUnique({
      where: { handle: h },
      select: { id: true },
    })
    if (!user) throw new NotFoundException('User not found')

    const rows = await this.prisma.follow.findMany({
      where: { followerId: user.id },
      orderBy: { createdAt: 'desc' },
      include: {
        following: { select: { id: true, handle: true, displayName: true, avatarUrl: true } },
      },
      take: 200,
    })

    return { data: rows.map((r) => r.following) }
  }

  async listFollowersByHandle(handle: string) {
    const h = this.normalizeHandle(handle)
    if (!h) throw new NotFoundException('User not found')

    const user = await this.prisma.user.findUnique({
      where: { handle: h },
      select: { id: true },
    })
    if (!user) throw new NotFoundException('User not found')

    const rows = await this.prisma.follow.findMany({
      where: { followingId: user.id },
      orderBy: { createdAt: 'desc' },
      include: {
        follower: { select: { id: true, handle: true, displayName: true, avatarUrl: true } },
      },
      take: 200,
    })

    return { data: rows.map((r) => r.follower) }
  }

  async toggleFollowByHandle(currentUserId: string, targetHandle: string) {
    const me = (currentUserId ?? '').trim()
    if (!me) throw new NotFoundException('User not found')

    const h = this.normalizeHandle(targetHandle)
    if (!h) throw new NotFoundException('User not found')

    const target = await this.prisma.user.findUnique({
      where: { handle: h },
      select: { id: true },
    })
    if (!target) throw new NotFoundException('User not found')

    if (target.id === me) {
      throw new BadRequestException('You cannot follow yourself')
    }

    const existing = await this.prisma.follow.findUnique({
      where: { followerId_followingId: { followerId: me, followingId: target.id } },
      select: { followerId: true, followingId: true },
    })

    if (existing) {
      await this.prisma.follow.delete({
        where: { followerId_followingId: { followerId: me, followingId: target.id } },
      })
      return { following: false }
    }

    await this.prisma.follow.create({
      data: { followerId: me, followingId: target.id },
    })
    return { following: true }
  }
}
