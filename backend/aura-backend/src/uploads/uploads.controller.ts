import {
  BadRequestException,
  Controller,
  Post,
  UploadedFile,
  UseGuards,
  UseInterceptors,
} from '@nestjs/common'
import { FileInterceptor } from '@nestjs/platform-express'
import { diskStorage } from 'multer'
import * as path from 'path'
import { JwtAuthGuard } from '../common/guards/jwt-auth.guard'
import { CurrentUserId } from '../common/decorators/current-user.decorator'
import { PrismaService } from '../prisma/prisma.service'

function safeExt(mime: string, originalName: string) {
  const lower = (originalName || '').toLowerCase()
  if (lower.endsWith('.png')) return '.png'
  if (lower.endsWith('.jpg') || lower.endsWith('.jpeg')) return '.jpg'
  if (lower.endsWith('.webp')) return '.webp'

  if (mime === 'image/png') return '.png'
  if (mime === 'image/jpeg') return '.jpg'
  if (mime === 'image/webp') return '.webp'
  return ''
}

@UseGuards(JwtAuthGuard)
@Controller('uploads')
export class UploadsController {
  constructor(private readonly prisma: PrismaService) {}

  @Post('avatar')
  @UseInterceptors(
    FileInterceptor('file', {
      storage: diskStorage({
        destination: (_req, _file, cb) => cb(null, path.join(process.cwd(), 'uploads')),
        filename: (_req, file, cb) => {
          const ext = safeExt(file.mimetype, file.originalname)
          const name = `avatar_${Date.now()}_${Math.random().toString(16).slice(2)}${ext || ''}`
          cb(null, name)
        },
      }),
      fileFilter: (_req, file, cb) => {
        const ok = ['image/png', 'image/jpeg', 'image/webp'].includes(file.mimetype)
        cb(ok ? null : new BadRequestException('Only PNG/JPG/WEBP allowed'), ok)
      },
      limits: { fileSize: 5 * 1024 * 1024 }, // 5MB
    }),
  )
  async uploadAvatar(
    @CurrentUserId() userId: string,
    @UploadedFile() file?: Express.Multer.File,
  ) {
    if (!userId) throw new BadRequestException('Missing user')
    if (!file) throw new BadRequestException('Missing file')

    // Public URL path served by main.ts: GET /uploads/<filename>
    const avatarUrl = `/uploads/${file.filename}`

    const user = await this.prisma.user.update({
      where: { id: userId },
      data: { avatarUrl },
      select: {
        id: true,
        email: true,
        handle: true,
        displayName: true,
        bio: true,
        avatarUrl: true,
      },
    })

    return { user, avatarUrl }
  }
}
