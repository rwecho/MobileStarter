import { NextResponse } from 'next/server';
import { ZodError } from 'zod';

type ApiErrorBody = Readonly<{
  code: string;
  message: string;
  traceId: string;
  retryable: boolean;
  fieldErrors?: Readonly<Record<string, readonly string[]>>;
}>;

export class ApiError extends Error {
  constructor(
    readonly status: number,
    readonly code: string,
    message: string,
    readonly retryable = false,
  ) {
    super(message);
  }
}

export function ok<T>(data: T, status = 200) {
  return NextResponse.json({ data }, { status });
}

export function handleError(error: unknown) {
  const traceId = crypto.randomUUID();
  if (error instanceof ZodError) {
    return NextResponse.json({
      error: {
        code: 'VALIDATION_ERROR',
        message: '请检查输入内容',
        traceId,
        retryable: false,
        fieldErrors: error.flatten().fieldErrors,
      } satisfies ApiErrorBody,
    }, { status: 400 });
  }
  if (error instanceof ApiError) {
    return NextResponse.json({
      error: {
        code: error.code,
        message: error.message,
        traceId,
        retryable: error.retryable,
      } satisfies ApiErrorBody,
    }, { status: error.status });
  }
  console.error(JSON.stringify({ level: 'error', traceId, message: 'Unhandled API error' }));
  return NextResponse.json({
    error: {
      code: 'INTERNAL_ERROR',
      message: '服务暂时不可用',
      traceId,
      retryable: true,
    } satisfies ApiErrorBody,
  }, { status: 500 });
}

