import { randomUUID } from 'crypto'

export function requestIdMiddleware() {
  return (req: any, res: any, next: any) => {
    const incoming = req.headers?.['x-request-id']
    const id =
      (typeof incoming === 'string' && incoming.trim().length > 0 ? incoming.trim() : null) ??
      randomUUID()

    req.requestId = id
    res.setHeader('x-request-id', id)
    next()
  }
}
