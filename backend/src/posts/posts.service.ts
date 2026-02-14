import { Injectable, NotFoundException, BadRequestException, ForbiddenException } from '@nestjs/common'
import { PrismaService } from '../prisma/prisma.service'

type PostStatus = 'DRAFT' | 'PUBLISHED'

type CursorParts = { createdAt: Date; id: string }
type Page<T> = { data: T[]; nextCursor: string | null }

@Injectable()
export class PostsService {
  constructor(private readonly prisma: PrismaService) {}

  private authorSelect = { id: true, handle: true, displayName: true, avatarUrl: true } as const

  // ------------------------------------------
  // Cursor utilities (stable cursor: createdAt + id)
  // cursor format: base64url("ISO::id")
  // ------------------------------------------
  private encodeCursor(p: { createdAt: Date; id: string }): string {
    const raw = `${p.createdAt.toISOString()}::${p.id}`
    const b64 = Buffer.from(raw, 'utf8').toString('base64')
    return b64.replace(/\+/g, '-').replace(/\//g, '_').replace(/=+$/g, '')
  }

  private decodeCursor(cursor?: string): CursorParts | null {
    const c = (cursor ?? '').trim()
    if (!c) return null
    try {
      const padded = c.replace(/-/g, '+').replace(/_/g, '/')
      const padLen = (4 - (padded.length % 4)) % 4
      const fixed = padded + '='.repeat(padLen)
      const raw = Buffer.from(fixed, 'base64').toString('utf8')
      const [iso, id] = raw.split('::')
      if (!iso || !id) return null
      const dt = new Date(iso)
      if (Number.isNaN(dt.getTime())) return null
      return { createdAt: dt, id }
    } catch {
      return null
    }
  }

  private clampLimit(limit: number | undefined, def: number, max: number) {
    return Math.min(Math.max(limit ?? def, 1), max)
  }

  // Builds a stable pagination filter for (createdAt desc, id desc)
  private afterCursorWhere(cursor?: string) {
    const p = this.decodeCursor(cursor)
    if (!p) return undefined
    return {
      OR: [{ createdAt: { lt: p.createdAt } }, { createdAt: p.createdAt, id: { lt: p.id } }],
    }
  }

  private mapPost(post: any) {
    // B: response shape lock.
    // Keep it simple. No counts. No private fields.
    return {
      id: post.id,
      text: post.text,
      media: post.media ?? null,
      visibility: post.visibility,
      createdAt: post.createdAt,
      updatedAt: post.updatedAt,
      replyToPostId: post.replyToPostId ?? null,
      repostOfPostId: post.repostOfPostId ?? null,
      author: post.author,
    }
  }

  // ------------------------------------------
  // Create post / reply / repost
  // ------------------------------------------
  async createPost(userId: string, text: string, status: PostStatus = 'PUBLISHED') {
    const created = await this.prisma.post.create({
      data: {
        authorId: userId,
        text,
        status,
      },
      include: {
        author: { select: this.authorSelect },
      },
    })

    return { post: this.mapPost(created) }
  }

  async createReply(userId: string, replyToPostId: string, text: string) {
    const parent = await this.prisma.post.findUnique({
      where: { id: replyToPostId },
      select: { id: true, authorId: true, status: true, visibility: true },
    })
    if (!parent || parent.status !== 'PUBLISHED' || parent.visibility === 'ARCHIVED') {
      throw new NotFoundException('Parent post not found')
    }

    const created = await this.prisma.post.create({
      data: {
        authorId: userId,
        text,
        replyToPostId,
        status: 'PUBLISHED',
      },
      include: {
        author: { select: this.authorSelect },
      },
    })

    if (parent.authorId && parent.authorId !== userId) {
      await this.prisma.notification.create({
        data: { userId: parent.authorId, actorId: userId, type: 'reply', postId: replyToPostId },
      })
    }

    return { post: this.mapPost(created) }
  }

  async createRepost(userId: string, repostOfPostId: string, text?: string) {
    const parent = await this.prisma.post.findUnique({
      where: { id: repostOfPostId },
      select: { id: true, authorId: true, status: true, visibility: true },
    })
    if (!parent || parent.status !== 'PUBLISHED' || parent.visibility === 'ARCHIVED') {
      throw new NotFoundException('Post to repost not found')
    }

    const created = await this.prisma.post.create({
      data: {
        authorId: userId,
        text: (text ?? '').trim(),
        repostOfPostId,
        status: 'PUBLISHED',
      },
      include: {
        author: { select: this.authorSelect },
      },
    })

    if (parent.authorId && parent.authorId !== userId) {
      await this.prisma.notification.create({
        data: { userId: parent.authorId, actorId: userId, type: 'repost', postId: repostOfPostId },
      })
    }

    return { post: this.mapPost(created) }
  }

  // ------------------------------------------
  // Drafts (author-private)
  // ------------------------------------------
  async getLatestDraft(userId: string) {
    const draft = await this.prisma.post.findFirst({
      where: {
        authorId: userId,
        status: 'DRAFT',
        replyToPostId: null,
        repostOfPostId: null,
      },
      orderBy: [{ updatedAt: 'desc' }, { id: 'desc' }],
      include: { author: { select: this.authorSelect } },
    })

    return { draft: draft ? this.mapPost(draft) : null }
  }

  async saveDraft(userId: string, text: string) {
    const existing = await this.prisma.post.findFirst({
      where: {
        authorId: userId,
        status: 'DRAFT',
        replyToPostId: null,
        repostOfPostId: null,
      },
      orderBy: [{ updatedAt: 'desc' }, { id: 'desc' }],
      select: { id: true },
    })

    const draft = existing
      ? await this.prisma.post.update({
          where: { id: existing.id },
          data: { text, status: 'DRAFT' },
          include: { author: { select: this.authorSelect } },
        })
      : await this.prisma.post.create({
          data: { authorId: userId, text, status: 'DRAFT' },
          include: { author: { select: this.authorSelect } },
        })

    return { draft: this.mapPost(draft) }
  }

  async discardLatestDraft(userId: string) {
    const existing = await this.prisma.post.findFirst({
      where: {
        authorId: userId,
        status: 'DRAFT',
        replyToPostId: null,
        repostOfPostId: null,
      },
      orderBy: [{ updatedAt: 'desc' }, { id: 'desc' }],
      select: { id: true },
    })

    if (!existing) return { ok: true }

    // NOTE: schema currently has no deletedAt, so discard is hard delete.
    await this.prisma.post.delete({ where: { id: existing.id } })
    return { ok: true }
  }

  async publishLatestDraft(userId: string) {
    const existing = await this.prisma.post.findFirst({
      where: {
        authorId: userId,
        status: 'DRAFT',
        replyToPostId: null,
        repostOfPostId: null,
      },
      orderBy: [{ updatedAt: 'desc' }, { id: 'desc' }],
      select: { id: true },
    })

    if (!existing) throw new NotFoundException('No draft found')

    const post = await this.prisma.post.update({
      where: { id: existing.id },
      data: { status: 'PUBLISHED' },
      include: { author: { select: this.authorSelect } },
    })

    return { post: this.mapPost(post) }
  }

  // ------------------------------------------
  // Public reads (viewerId optional — reserved for block/mute later)
  // ------------------------------------------
  async getById(id: string, _viewerId?: string) {
    const post = await this.prisma.post.findUnique({
      where: { id },
      include: { author: { select: this.authorSelect } },
    })

    if (!post || post.status !== 'PUBLISHED' || post.visibility === 'ARCHIVED') {
      throw new NotFoundException('Post not found')
    }

    return { post: this.mapPost(post) }
  }

  async listReplies(params: { replyToPostId: string; cursor?: string; limit?: number; viewerId?: string }): Promise<Page<any>> {
    const take = this.clampLimit(params.limit, 50, 100)

    const parent = await this.prisma.post.findUnique({
      where: { id: params.replyToPostId },
      select: { id: true, status: true, visibility: true },
    })
    if (!parent || parent.status !== 'PUBLISHED' || parent.visibility === 'ARCHIVED') {
      throw new NotFoundException('Post not found')
    }

    const after = this.afterCursorWhere(params.cursor)

    const items = await this.prisma.post.findMany({
      where: {
        replyToPostId: params.replyToPostId,
        status: 'PUBLISHED',
        ...(after ? after : {}),
      },
      take: take + 1,
      orderBy: [{ createdAt: 'asc' }, { id: 'asc' }],
      include: { author: { select: this.authorSelect } },
    })

    const hasMore = items.length > take
    const slice = hasMore ? items.slice(0, take) : items
    const data = slice.map((p) => this.mapPost(p))

    const nextCursor = hasMore
      ? this.encodeCursor({ createdAt: slice[slice.length - 1].createdAt, id: slice[slice.length - 1].id })
      : null

    return { data, nextCursor }
  }

  async listPublic(params: { cursor?: string; limit?: number; viewerId?: string }): Promise<Page<any>> {
    const take = this.clampLimit(params.limit, 20, 50)
    const after = this.afterCursorWhere(params.cursor)

    const items = await this.prisma.post.findMany({
      where: {
        status: 'PUBLISHED',
        replyToPostId: null,
        NOT: { visibility: 'ARCHIVED' },
        ...(after ? after : {}),
      },
      take: take + 1,
      orderBy: [{ createdAt: 'desc' }, { id: 'desc' }],
      include: { author: { select: this.authorSelect } },
    })

    const hasMore = items.length > take
    const slice = hasMore ? items.slice(0, take) : items
    const data = slice.map((p) => this.mapPost(p))

    const nextCursor = hasMore
      ? this.encodeCursor({ createdAt: slice[slice.length - 1].createdAt, id: slice[slice.length - 1].id })
      : null

    return { data, nextCursor }
  }

  async getFeed(params: { viewerId: string; cursor?: string; limit?: number }): Promise<Page<any>> {
    // For now feed === public published top-level (no blocks yet, schema doesn’t support it).
    // viewerId reserved for Phase C: blocks/mutes/following feed.
    return this.listPublic({ cursor: params.cursor, limit: params.limit, viewerId: params.viewerId })
  }

  // ------------------------------------------
  // Profile v1: my posts / archived
  // ------------------------------------------
  async getMyPosts(params: { userId: string; cursor?: string; limit?: number }): Promise<Page<any>> {
    const take = this.clampLimit(params.limit, 20, 50)
    const after = this.afterCursorWhere(params.cursor)

    const items = await this.prisma.post.findMany({
      where: {
        authorId: params.userId,
        status: 'PUBLISHED',
        replyToPostId: null,
        NOT: { visibility: 'ARCHIVED' },
        ...(after ? after : {}),
      },
      take: take + 1,
      orderBy: [{ createdAt: 'desc' }, { id: 'desc' }],
      include: { author: { select: this.authorSelect } },
    })

    const hasMore = items.length > take
    const slice = hasMore ? items.slice(0, take) : items
    const data = slice.map((p) => this.mapPost(p))

    const nextCursor = hasMore
      ? this.encodeCursor({ createdAt: slice[slice.length - 1].createdAt, id: slice[slice.length - 1].id })
      : null

    return { data, nextCursor }
  }

  async getArchivedPosts(params: { userId: string; cursor?: string; limit?: number }): Promise<Page<any>> {
    const take = this.clampLimit(params.limit, 20, 50)
    const after = this.afterCursorWhere(params.cursor)

    const items = await this.prisma.post.findMany({
      where: {
        authorId: params.userId,
        status: 'PUBLISHED',
        replyToPostId: null,
        visibility: 'ARCHIVED',
        ...(after ? after : {}),
      },
      take: take + 1,
      orderBy: [{ createdAt: 'desc' }, { id: 'desc' }],
      include: { author: { select: this.authorSelect } },
    })

    const hasMore = items.length > take
    const slice = hasMore ? items.slice(0, take) : items
    const data = slice.map((p) => this.mapPost(p))

    const nextCursor = hasMore
      ? this.encodeCursor({ createdAt: slice[slice.length - 1].createdAt, id: slice[slice.length - 1].id })
      : null

    return { data, nextCursor }
  }

  // ------------------------------------------
  // Search (public) - published only
  // viewerId optional (reserved for Phase C blocks/mutes)
  // ------------------------------------------
  async search(q: string, limit?: number, _viewerId?: string) {
    const query = (q ?? '').trim()
    const take = this.clampLimit(limit, 20, 50)

    if (!query) {
      return { users: [], posts: [] }
    }

    const users = await this.prisma.user.findMany({
      where: {
        OR: [
          { handle: { contains: query, mode: 'insensitive' } },
          { displayName: { contains: query, mode: 'insensitive' } },
        ],
      },
      take: Math.min(take, 20),
      select: { id: true, handle: true, displayName: true, avatarUrl: true, bio: true },
    })

    const posts = await this.prisma.post.findMany({
      where: {
        text: { contains: query, mode: 'insensitive' },
        replyToPostId: null,
        status: 'PUBLISHED',
        NOT: { visibility: 'ARCHIVED' },
      },
      take,
      orderBy: [{ createdAt: 'desc' }, { id: 'desc' }],
      include: { author: { select: this.authorSelect } },
    })

    return { users, posts: posts.map((p) => this.mapPost(p)) }
  }

  // ------------------------------------------
  // Inline edit
  // ------------------------------------------
  async updatePostText(userId: string, postId: string, text?: string) {
    if (text === undefined || text === null) {
      throw new BadRequestException('Missing text')
    }

    const next = (text ?? '').trim()

    const post = await this.prisma.post.findUnique({
      where: { id: postId },
      select: { id: true, authorId: true, replyToPostId: true },
    })
    if (!post) throw new NotFoundException('Post not found')
    if (post.authorId !== userId) throw new ForbiddenException('Not allowed')
    if (post.replyToPostId) throw new BadRequestException('Cannot edit a reply here')

    await this.prisma.post.update({
      where: { id: postId },
      data: { text: next },
    })

    return { ok: true }
  }

  // ------------------------------------------
  // Archive/unarchive using visibility flag
  // ------------------------------------------
  async archivePost(userId: string, postId: string) {
    const post = await this.prisma.post.findUnique({
      where: { id: postId },
      select: { id: true, authorId: true, replyToPostId: true },
    })
    if (!post) throw new NotFoundException('Post not found')
    if (post.authorId !== userId) throw new ForbiddenException('Not allowed')
    if (post.replyToPostId) throw new BadRequestException('Cannot archive a reply')

    await this.prisma.post.update({
      where: { id: postId },
      data: { visibility: 'ARCHIVED' },
    })

    return { ok: true }
  }

  async unarchivePost(userId: string, postId: string) {
    const post = await this.prisma.post.findUnique({
      where: { id: postId },
      select: { id: true, authorId: true, replyToPostId: true },
    })
    if (!post) throw new NotFoundException('Post not found')
    if (post.authorId !== userId) throw new ForbiddenException('Not allowed')
    if (post.replyToPostId) throw new BadRequestException('Cannot unarchive a reply')

    await this.prisma.post.update({
      where: { id: postId },
      data: { visibility: 'PUBLIC' },
    })

    return { ok: true }
  }

  // ------------------------------------------
  // Delete (hard delete — schema has no deletedAt yet)
  // ------------------------------------------
  async deletePost(userId: string, postId: string) {
    const post = await this.prisma.post.findUnique({
      where: { id: postId },
      select: { id: true, authorId: true },
    })
    if (!post) throw new NotFoundException('Post not found')
    if (post.authorId !== userId) throw new ForbiddenException('Not allowed')

    await this.prisma.post.delete({ where: { id: postId } })
    return { ok: true }
  }
}
