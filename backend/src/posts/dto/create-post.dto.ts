import { IsIn, IsObject, IsOptional, IsString, MaxLength } from 'class-validator'

export class CreatePostDto {
  /**
   * IMPORTANT:
   * - Normal posts require text (enforced in controller).
   * - Replies require text (enforced in controller).
   * - Reposts may have empty text (commentary optional).
   * - Drafts may be empty.
   */
  @IsOptional()
  @IsString()
  @MaxLength(5000)
  text?: string

  @IsOptional()
  @IsIn(['DRAFT', 'PUBLISHED'])
  status?: 'DRAFT' | 'PUBLISHED'

  @IsOptional()
  @IsString()
  replyToPostId?: string

  @IsOptional()
  @IsString()
  repostOfPostId?: string

  @IsOptional()
  @IsIn(['public', 'unlisted', 'private'])
  visibility?: 'public' | 'unlisted' | 'private'

  @IsOptional()
  @IsObject()
  media?: Record<string, any>
}
