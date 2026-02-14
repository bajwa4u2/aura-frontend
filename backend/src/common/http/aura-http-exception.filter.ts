import {
  ArgumentsHost,
  Catch,
  ExceptionFilter,
  HttpException,
  HttpStatus,
} from '@nestjs/common'

function asString(x: unknown): string | undefined {
  if (typeof x === 'string') return x
  return undefined
}

function nowIso() {
  return new Date().toISOString()
}

@Catch()
export class AuraHttpExceptionFilter implements ExceptionFilter {
  catch(exception: unknown, host: ArgumentsHost) {
    const ctx = host.switchToHttp()
    const res = ctx.getResponse<any>()
    const req = ctx.getRequest<any>()

    const requestId =
      req?.requestId ||
      req?.headers?.['x-request-id'] ||
      req?.headers?.['X-Request-Id'] ||
      null

    let status = HttpStatus.INTERNAL_SERVER_ERROR
    let code = 'INTERNAL_ERROR'
    let message = 'Something went wrong'
    let details: any = null

    if (exception instanceof HttpException) {
      status = exception.getStatus()
      const payload = exception.getResponse() as any

      // Nest ValidationPipe often returns:
      // { statusCode, message: string[] | string, error: 'Bad Request' }
      const maybeMessage = payload?.message
      const baseMsg = Array.isArray(maybeMessage)
        ? 'Validation failed'
        : asString(maybeMessage) || asString(payload?.error)

      message = baseMsg || exception.message || message

      if (status === HttpStatus.BAD_REQUEST && Array.isArray(maybeMessage)) {
        code = 'VALIDATION_ERROR'
        details = { issues: maybeMessage }
      } else if (status === HttpStatus.UNAUTHORIZED) {
        code = 'UNAUTHORIZED'
      } else if (status === HttpStatus.FORBIDDEN) {
        code = 'FORBIDDEN'
      } else if (status === HttpStatus.NOT_FOUND) {
        code = 'NOT_FOUND'
      } else if (status >= 500) {
        code = 'SERVER_ERROR'
      } else {
        code = 'REQUEST_ERROR'
        details = payload ?? null
      }
    } else if (exception instanceof Error) {
      message = exception.message || message
      code = 'INTERNAL_ERROR'
    }

    res.status(status).json({
      error: {
        code,
        message,
        details,
        requestId,
        timestamp: nowIso(),
        path: req?.originalUrl ?? null,
      },
    })
  }
}
