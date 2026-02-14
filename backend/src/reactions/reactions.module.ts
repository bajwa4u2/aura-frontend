import { Module } from '@nestjs/common'
import { ReactionsController } from './reactions.controller'
import { ReactionsService } from './reactions.service'
import { PrismaModule } from '../prisma/prisma.module'

@Module({
  imports: [PrismaModule],
  controllers: [ReactionsController],
  providers: [ReactionsService],
})
export class ReactionsModule {}
