// 外部 API への fetch を差し替えるテスト用スタブ。
// @cloudflare/vitest-pool-workers 0.13 が cloudflare:test の fetchMock を削除したため、
// 公式の移行ガイドに従って globalThis.fetch を直接差し替える。
// https://developers.cloudflare.com/workers/testing/vitest-integration/migration-guides/migrate-from-vitest-3-to-vitest-4/
// テストと main worker は同じ isolate で動くため、ここでの差し替えは src/ の fetch 呼び出しにも効く。

/** 応答を組み立てるコールバックへ渡す、差し替え対象のリクエストの内容。 */
export interface MockedFetchRequest {
  /** ヘッダー名を小文字にしたリクエストヘッダー。 */
  headers: Record<string, string>;
  /** リクエスト本体の文字列。 */
  body: string;
}

/** 差し替える応答の本体。リクエストの内容を検証・記録したい時はコールバックで渡す。 */
export type MockedFetchResponseBody = string | ((mockedFetchRequest: MockedFetchRequest) => string);

/** 1 回の fetch にだけ応答する差し替え定義。 */
interface FetchInterceptor {
  /** 対象の origin (例: `https://api.revenuecat.com`)。 */
  origin: string;
  /** 対象のパス (クエリ文字列を含む)。 */
  path: string;
  /** 対象の HTTP メソッド。 */
  method: string;
  /** 返す HTTP ステータス。 */
  status: number;
  /** 返す応答の本体。 */
  responseBody: MockedFetchResponseBody;
}

/** まだ fetch に消費されていない差し替え定義。登録順に消費する。 */
const pendingFetchInterceptors: FetchInterceptor[] = [];

/**
 * 登録済みの差し替え定義に一致する fetch にだけ応答する。
 * 一致しない fetch は実通信へ流さず失敗させ、意図しない外部通信が無いことを保証する。
 */
async function respondFromInterceptors(input: RequestInfo | URL, init?: RequestInit): Promise<Response> {
  const request = new Request(input, init);
  const requestUrl = new URL(request.url);
  const interceptorIndex = pendingFetchInterceptors.findIndex(
    (interceptor) =>
      interceptor.origin === requestUrl.origin &&
      interceptor.path === `${requestUrl.pathname}${requestUrl.search}` &&
      interceptor.method === request.method,
  );
  if (interceptorIndex === -1) {
    throw new Error(`差し替えを登録していない fetch です: ${request.method} ${request.url}`);
  }
  const [interceptor] = pendingFetchInterceptors.splice(interceptorIndex, 1);
  return new Response(
    typeof interceptor.responseBody === "string"
      ? interceptor.responseBody
      : interceptor.responseBody({ headers: Object.fromEntries(request.headers), body: await request.text() }),
    { status: interceptor.status },
  );
}

/** 外部 API への fetch の差し替えを登録・検証する窓口。 */
export const fetchMock = {
  /** globalThis.fetch を差し替える。冪等: 何度呼んでも同じ関数を代入するだけ。 */
  activate(): void {
    globalThis.fetch = respondFromInterceptors;
  },

  /** origin への fetch のうち、path と method が一致する 1 回ぶんの応答を登録する。 */
  get(origin: string) {
    return {
      intercept({ path, method }: { path: string; method: string }) {
        return {
          reply(status: number, responseBody: MockedFetchResponseBody): void {
            pendingFetchInterceptors.push({ origin, path, method, status, responseBody });
          },
        };
      },
    };
  },

  /**
   * 登録した差し替えがすべて消費済みであることを検証する (呼ばれるはずの外部 API が呼ばれなかったことを検出する)。
   * 残っていた定義は破棄し、失敗したテストの定義が後続のテストの fetch に応答しないようにする。
   */
  assertNoPendingInterceptors(): void {
    const unconsumedInterceptors = pendingFetchInterceptors.splice(0);
    if (unconsumedInterceptors.length > 0) {
      throw new Error(
        `消費されていない fetch の差し替えが残っています: ${unconsumedInterceptors
          .map((interceptor) => `${interceptor.method} ${interceptor.origin}${interceptor.path}`)
          .join(", ")}`,
      );
    }
  },
};
