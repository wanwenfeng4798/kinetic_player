/** Browser stub for Node `util` pulled in by MediaPipe (danmuku-mask). */
export function inherits(
  ctor: { prototype: object },
  superCtor: { prototype: object },
): void {
  Object.setPrototypeOf(ctor.prototype, superCtor.prototype);
}

export function deprecate<T extends (...args: never[]) => unknown>(
  fn: T,
  _message?: string,
): T {
  return fn;
}

export function promisify<T extends (...args: never[]) => unknown>(fn: T): T {
  return fn;
}

export function format(...args: unknown[]): string {
  return args.map(String).join(' ');
}

export function inspect(value: unknown): string {
  try {
    return JSON.stringify(value);
  } catch {
    return String(value);
  }
}

const util = {
  inherits,
  deprecate,
  promisify,
  format,
  inspect,
};

export default util;
