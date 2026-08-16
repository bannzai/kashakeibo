// 日次アップロード回数カウンターの Durable Object。
// KV の get/put では並行リクエストが同じ旧値を読んで上限判定をすり抜けるため、
// 判定と加算を Durable Object (1インスタンス = 1日) で直列化する。
// 全アップロードが日次のシングルトンインスタンスを通る構成になるが、
// 全体上限が maxDailyUploadCountTotal 回/日 (handler.ts) の規模では DO のスループットで十分。
import { DurableObject } from "cloudflare:workers";

/** incrementIfWithinLimits が判定する1カウンターぶんの条件。 */
export interface UploadCounterCondition {
  /** インスタンス内のストレージキー (例: `uid:{uid}` / `ip:{ip}` / `total`)。 */
  counterKey: string;
  /** このカウンターの上限回数。現在値が上限以上なら加算せず拒否する。 */
  maxDailyUploadCount: number;
}

// カウンターは当日しか使わないため、2日後のアラームでストレージごと削除してゴミを残さない
const counterPurgeDelayMilliseconds = 2 * 24 * 60 * 60 * 1000;

/** 1日ぶんのアップロード回数カウンター群を保持する Durable Object。 */
export class DailyUploadCounter extends DurableObject {
  /**
   * すべての条件が上限未満なら全カウンターを +1 して true を返し、
   * 1つでも上限に達していれば何も加算せず false を返す。
   * Durable Object の直列実行により、並行リクエストでも上限を超えて加算されない。
   */
  async incrementIfWithinLimits(uploadCounterConditions: UploadCounterCondition[]): Promise<boolean> {
    const currentCounts = await Promise.all(
      uploadCounterConditions.map(
        async (condition) => (await this.ctx.storage.get<number>(condition.counterKey)) ?? 0,
      ),
    );
    if (
      uploadCounterConditions.some(
        (condition, conditionIndex) => currentCounts[conditionIndex] >= condition.maxDailyUploadCount,
      )
    ) {
      return false;
    }
    await Promise.all(
      uploadCounterConditions.map((condition, conditionIndex) =>
        this.ctx.storage.put(condition.counterKey, currentCounts[conditionIndex] + 1),
      ),
    );
    if ((await this.ctx.storage.getAlarm()) === null) {
      await this.ctx.storage.setAlarm(Date.now() + counterPurgeDelayMilliseconds);
    }
    return true;
  }

  /** カウンターの掃除。当日を過ぎたインスタンスのストレージを全削除する。 */
  async alarm(): Promise<void> {
    await this.ctx.storage.deleteAll();
  }
}
