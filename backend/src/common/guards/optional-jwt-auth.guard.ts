import { Injectable } from '@nestjs/common'
import { AuthGuard } from '@nestjs/passport'

@Injectable()
export class OptionalJwtAuthGuard extends AuthGuard('jwt') {
  // If token is missing/invalid, do NOT throw.
  // Just allow the request to continue with req.user undefined.
  handleRequest(err: any, user: any) {
    if (err) return null
    return user ?? null
  }
}
