import {
  Body,
  Controller,
  Delete,
  Get,
  NotFoundException,
  Param,
  Patch,
  Post,
  Put,
  Query,
  UseGuards,
  BadRequestException,
} from '@nestjs/common'
import { JwtAuthGuard } from '../common/guards/jwt-auth.guard'
import { CurrentUserId } from '../common/decorators/current-user.decorator'
import { CreatePostDto } from './dto/create-post.dto'
import { UpdatePostDto } from './dto/update-post.dto'
import { PostsService } from './posts.service'

@Controller('posts')
export class PostsController {
  constructor(private readonly posts: PostsService) {}

  // Draft (logged-in) — DB-backed
  @UseGuards(JwtAuthGuard)
  @Get('draft')
  async getDraft(@CurrentUserId() userId: string) {
    return this.posts.getLatestDraft(userId)
  }

  @UseGuards(JwtAuthGuard)
  @Put('draft')
  async saveDraft(@CurrentUserId() userId: string, @Body() dto: CreatePostDto) {
    // drafts can be empty
    return this.posts.saveDraft(userId, dto.text ?? '')
  }

  @UseGuards(JwtAuthGuard)
  @Delete('draft')
  async discardDraft(@CurrentUserId() userId: string) {
    return this.posts.discardLatestDraft(userId)
  }

  @UseGuards(JwtAuthGuard)
  @Post('draft/publish')
  async publishDraft(@CurrentUserId() userId: string) {
    return this.posts.publishLatestDraft(userId)
  }

  // Feed (logged-in) - published only
  @UseGuards(JwtAuthGuard)
  @Get('feed')
  async feed(@CurrentUserId() userId: string, @Query('cursor') cursor?: string, @Query('limit') limit?: string) {
    return this.posts.getFeed({
      viewerId: userId,
      cursor: cursor || undefined,
      limit: limit ? Number(limit) : undefined,
    })
  }

  // Public latest list (published only)
  @Get()
  async list(@Query('limit') limit?: string, @Query('scope') scope?: string, @Query('cursor') cursor?: string) {
    const sc = (scope ?? '').trim().toLowerCase()
    if (sc === 'me' || sc === 'mine') throw new NotFoundException('Use /v1/posts/me or /v1/posts/mine')
    if (sc === 'archived') throw new NotFoundException('Use /v1/posts/archived')

    return this.posts.listPublic({
      cursor: cursor || undefined,
      limit: limit ? Number(limit) : undefined,
    })
  }

  // Search (public) - published only
  @Get('search')
  async search(@Query('q') q: string, @Query('limit') limit?: string) {
    return this.posts.search(q || '', limit ? Number(limit) : undefined)
  }

  // ======== Aliases to satisfy existing Flutter calls ========

  @UseGuards(JwtAuthGuard)
  @Get('me')
  async myPostsMe(@CurrentUserId() userId: string, @Query('cursor') cursor?: string, @Query('limit') limit?: string) {
    return this.posts.getMyPosts({
      userId,
      cursor: cursor || undefined,
      limit: limit ? Number(limit) : undefined,
    })
  }

  @UseGuards(JwtAuthGuard)
  @Get('mine')
  async myPostsMine(
    @CurrentUserId() userId: string,
    @Query('cursor') cursor?: string,
    @Query('limit') limit?: string,
  ) {
    return this.posts.getMyPosts({
      userId,
      cursor: cursor || undefined,
      limit: limit ? Number(limit) : undefined,
    })
  }

  @UseGuards(JwtAuthGuard)
  @Get('archived')
  async archived(@CurrentUserId() userId: string, @Query('cursor') cursor?: string, @Query('limit') limit?: string) {
    return this.posts.getArchivedPosts({
      userId,
      cursor: cursor || undefined,
      limit: limit ? Number(limit) : undefined,
    })
  }

  // ======== Create ========

  @UseGuards(JwtAuthGuard)
  @Post()
  async create(@CurrentUserId() userId: string, @Body() dto: CreatePostDto) {
    const text = (dto.text ?? '').toString()

    // Reply must have text
    if (dto.replyToPostId && dto.replyToPostId.trim().length > 0) {
      if (!text.trim()) throw new BadRequestException('Reply text is required')
      return this.posts.createReply(userId, dto.replyToPostId.trim(), text)
    }

    // Repost may be empty (commentary optional)
    if (dto.repostOfPostId && dto.repostOfPostId.trim().length > 0) {
      return this.posts.createRepost(userId, dto.repostOfPostId.trim(), text)
    }

    // Normal post must have text
    if (!text.trim()) throw new BadRequestException('Post text is required')

    const status = (dto.status ?? 'PUBLISHED') as 'DRAFT' | 'PUBLISHED'
    return this.posts.createPost(userId, text, status)
  }

  // ======== Read ========

  @Get(':id')
  async one(@Param('id') id: string) {
    return this.posts.getById(id)
  }

  @Get(':id/replies')
  async replies(@Param('id') id: string, @Query('cursor') cursor?: string, @Query('limit') limit?: string) {
    return this.posts.listReplies({
      replyToPostId: id,
      cursor: cursor || undefined,
      limit: limit ? Number(limit) : undefined,
    })
  }

  @UseGuards(JwtAuthGuard)
  @Post(':id/replies')
  async createReply(@CurrentUserId() userId: string, @Param('id') id: string, @Body() dto: CreatePostDto) {
    const text = (dto.text ?? '').toString()
    if (!text.trim()) throw new BadRequestException('Reply text is required')
    return this.posts.createReply(userId, id, text)
  }

  @UseGuards(JwtAuthGuard)
  @Post(':id/repost')
  async repost(@CurrentUserId() userId: string, @Param('id') id: string, @Body() dto: CreatePostDto) {
    const text = (dto.text ?? '').toString()
    return this.posts.createRepost(userId, id, text)
  }

  // ======== Update (Edit) ========

  @UseGuards(JwtAuthGuard)
  @Patch(':id')
  async patch(@CurrentUserId() userId: string, @Param('id') id: string, @Body() dto: UpdatePostDto) {
    return this.posts.updatePostText(userId, id, dto.text)
  }

  @UseGuards(JwtAuthGuard)
  @Put(':id')
  async put(@CurrentUserId() userId: string, @Param('id') id: string, @Body() dto: UpdatePostDto) {
    return this.posts.updatePostText(userId, id, dto.text)
  }

  // ======== Archive / Unarchive ========

  @UseGuards(JwtAuthGuard)
  @Post(':id/archive')
  async archive(@CurrentUserId() userId: string, @Param('id') id: string) {
    return this.posts.archivePost(userId, id)
  }

  @UseGuards(JwtAuthGuard)
  @Post(':id/unarchive')
  async unarchive(@CurrentUserId() userId: string, @Param('id') id: string) {
    return this.posts.unarchivePost(userId, id)
  }

  // ======== Delete ========

  @UseGuards(JwtAuthGuard)
  @Delete(':id')
  async delete(@CurrentUserId() userId: string, @Param('id') id: string) {
    return this.posts.deletePost(userId, id)
  }
}
