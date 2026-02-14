import { Controller, Get } from '@nestjs/common'
import { PrismaService } from './prisma/prisma.service'

@Controller()
export class AppController {
  constructor(private readonly prisma: PrismaService) {}

  // With app.setGlobalPrefix('v1'), this becomes GET /v1/health
  @Get('health')
  async health() {
    const now = new Date().toISOString()
    const users = await this.prisma.user.count()
    return { ok: true, now, users }
  }
}
