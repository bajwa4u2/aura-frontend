import { Test } from '@nestjs/testing'
import { AppController } from './app.controller'
import { PrismaService } from './prisma/prisma.service'

describe('AppController', () => {
  it('health returns ok', async () => {
    const moduleRef = await Test.createTestingModule({
      controllers: [AppController],
      providers: [
        {
          provide: PrismaService,
          useValue: { user: { count: async () => 0 } },
        },
      ],
    }).compile()

    const appController = moduleRef.get(AppController)
    const res = await appController.health()
    expect(res.ok).toBe(true)
  })
})
