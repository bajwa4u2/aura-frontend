import { Module } from '@nestjs/common'
import { SavesController } from './saves.controller'
import { SavesService } from './saves.service'
import { PrismaModule } from '../prisma/prisma.module'

@Module({
  imports: [PrismaModule],
  controllers: [SavesController],
  providers: [SavesService],
})
export class SavesModule {}
