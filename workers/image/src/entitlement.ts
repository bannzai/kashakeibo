// RevenueCat の entitlement (プレミアム) 判定。
// スキャン無料枠 (月次) を超えた解析リクエストに対して、Worker がサーバー側で課金状態を確認する
// (documents/adr/0001-tech-stack.md の「画像解析」。クライアント申告の isPremium は信用しない)。
// RevenueCat API v2 の active_entitlements をユーザー (Firebase uid = Purchases.logIn に渡す app user ID) で引き、
// プレミアムの entitlement が含まれるかで判定する。API キーは Worker の secret にだけ置く。

/** entitlement 判定に必要な Worker の設定 (binding の説明は wrangler.jsonc)。 */
export interface EntitlementEnv {
  /** RevenueCat API v2 の secret API key (customer_information:customers:read 権限)。 */
  REVENUECAT_SECRET_API_KEY?: string;
  /** RevenueCat の project ID (`proj...`)。 */
  REVENUECAT_PROJECT_ID?: string;
  /** プレミアムの entitlement ID (`entl...`。lookup_key ではなく ID)。 */
  REVENUECAT_PREMIUM_ENTITLEMENT_ID?: string;
}

const revenueCatApiBaseUrl = "https://api.revenuecat.com/v2";

// RevenueCat API 呼び出しのタイムアウト。Workers の fetch サブリクエストには既定のタイムアウトが無く、
// RevenueCat 側の応答遅延が解析リクエスト全体のハングに波及するのを防ぐ。
// active_entitlements は軽い読み取り API のため、通常応答 (1 秒未満) に大きく余裕を持たせた値
const revenueCatRequestTimeoutMilliseconds = 10_000;

/**
 * RevenueCat API の呼び出しに失敗し、課金状態を判定できなかったことを表す。
 * 「プレミアムではない」とは区別し、呼び出し側は無料枠超過の 402 ではなく一時的なエラーとして返す。
 */
export class EntitlementVerificationError extends Error {
  constructor(message: string) {
    super(message);
    this.name = "EntitlementVerificationError";
  }
}

/**
 * ユーザーがプレミアムの entitlement を持っているかを RevenueCat に問い合わせる。
 * 設定 (secret・project ID・entitlement ID) が無い環境では、課金が未セットアップとみなして false を返す
 * (無料枠だけを強制する fail-closed。LLM 原価の上限を守る側に倒す)。
 * RevenueCat が顧客を知らない (404) 場合も false。それ以外の失敗は EntitlementVerificationError。
 * 冪等 (読み取りのみ)。
 */
export async function hasPremiumEntitlement({
  appUserId,
  env,
}: {
  appUserId: string;
  env: EntitlementEnv;
}): Promise<boolean> {
  if (!env.REVENUECAT_SECRET_API_KEY || !env.REVENUECAT_PROJECT_ID || !env.REVENUECAT_PREMIUM_ENTITLEMENT_ID) {
    console.warn("RevenueCat の設定 (REVENUECAT_SECRET_API_KEY / REVENUECAT_PROJECT_ID / REVENUECAT_PREMIUM_ENTITLEMENT_ID) が無いため、プレミアムなしとして扱います");
    return false;
  }

  let activeEntitlementsResponse: Response;
  try {
    activeEntitlementsResponse = await fetch(
      `${revenueCatApiBaseUrl}/projects/${encodeURIComponent(env.REVENUECAT_PROJECT_ID)}/customers/${encodeURIComponent(appUserId)}/active_entitlements`,
      {
        headers: { Authorization: `Bearer ${env.REVENUECAT_SECRET_API_KEY}` },
        signal: AbortSignal.timeout(revenueCatRequestTimeoutMilliseconds),
      },
    );
  } catch (error) {
    throw new EntitlementVerificationError(`RevenueCat への接続に失敗しました: ${String(error)}`);
  }
  if (activeEntitlementsResponse.status === 404) {
    // 一度も RevenueCat SDK に到達していないユーザー (顧客レコードなし) は購入もしていない
    return false;
  }
  if (!activeEntitlementsResponse.ok) {
    // RevenueCat のエラー本文にはプロジェクト ID 等の内部情報が含まれ得るため、
    // 詳細はログにだけ残し、クライアントへは固定文言 + status を返す
    console.warn(
      `RevenueCat の課金状態の取得に失敗 (status=${activeEntitlementsResponse.status}): ${await activeEntitlementsResponse.text()}`,
    );
    throw new EntitlementVerificationError(
      `課金状態を確認できませんでした (status=${activeEntitlementsResponse.status})`,
    );
  }
  const activeEntitlements = (await activeEntitlementsResponse.json()) as { items?: { entitlement_id?: unknown }[] };
  return (activeEntitlements.items ?? []).some((item) => item.entitlement_id === env.REVENUECAT_PREMIUM_ENTITLEMENT_ID);
}
