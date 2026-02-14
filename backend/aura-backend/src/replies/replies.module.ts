import { Module } from '@nestjs/common'
import { PrismaModule } from '../prisma/prisma.module'
import { RepliesController } from './replies.controller'
import { RepliesService } from './replies.service'

@Module({
  imports: [PrismaModule],
  controllers: [RepliesController],
  providers: [RepliesService],
})
export class RepliesModule {}
