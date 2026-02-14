import { Module } from '@nestjs/common'
import { ConfigModule } from '@nestjs/config'

import { PrismaModule } from './prisma/prisma.module'
import { AppController } from './app.controller'

import { AuthModule } from './auth/auth.module'
import { UsersModule } from './users/users.module'
import { PostsModule } from './posts/posts.module'
import { RepliesModule } from './replies/replies.module'
import { FollowsModule } from './follows/follows.module'
import { NotificationsModule } from './notifications/notifications.module'
import { ReactionsModule } from './reactions/reactions.module'
import { SavesModule } from './saves/saves.module'
import { UploadsModule } from './uploads/uploads.module'

@Module({
  imports: [
    ConfigModule.forRoot({
      isGlobal: true,
      envFilePath: '.env',
      expandVariables: true,
    }),

    PrismaModule,

    AuthModule,
    UsersModule,

    PostsModule,
    RepliesModule,
    FollowsModule,
    NotificationsModule,
    ReactionsModule,
    SavesModule,
    UploadsModule,
  ],
  controllers: [AppController],
})
export class AppModule {}
