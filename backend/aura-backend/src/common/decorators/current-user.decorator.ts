import { createParamDecorator, ExecutionContext } from '@nestjs/common'

export type JwtUser = {
  userId?: string
  sub?: string
  id?: string
  email?: string
  handle?: string
}

function getReq(ctx: ExecutionContext) {
  return ctx.switchToHttp().getRequest()
}

function resolveUser(req: any): JwtUser | null {
  return (req?.user ?? null) as JwtUser | null
}

function resolveUserId(u: JwtUser | null): string | null {
  return (u?.userId ?? u?.sub ?? u?.id ?? null) as string | null
}

/**
 * Returns req.user as a typed object (or null).
 * Controllers can use @CurrentUser() user: JwtUser | null
 */
export const CurrentUser = createParamDecorator((data: unknown, ctx: ExecutionContext) => {
  const req = getReq(ctx)
  return resolveUser(req)
})

/**
 * Returns a stable user id string from req.user (or null).
 * Controllers can use @CurrentUserId() userId: string
 */
export const CurrentUserId = createParamDecorator((data: unknown, ctx: ExecutionContext) => {
  const req = getReq(ctx)
  const u = resolveUser(req)
  return resolveUserId(u)
})

/**
 * Back-compat alias: some files may import CurrentUserId as CurrentUserId.
 * Also, if any older code used a different name, keep this alias available.
 */
export const CurrentUserID = CurrentUserId
