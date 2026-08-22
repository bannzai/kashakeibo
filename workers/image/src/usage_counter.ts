// 回数カウンターの Durable Object。日次のアップロード・解析回数 (uid 別・IP 別・全体) と、
// 月次のスキャン回数 (uid 別。無料枠の判定) を数える。
// KV の get/put では並行リクエストが同じ旧値を読んで上限判定をすり抜けるため、
// 判定と加算を Durable Object (1インスタンス = 1日 または 1ヶ月) で直列化する。
// 全アップロード・解析が日次・月次のシングルトンインスタンスを通る構成になるが、
// 全体上限が maxDailyUploadCountTotal 回/日 (handler.ts) の規模では DO のスループットで十分。
import { DurableObject } from "cloudflare:workers";

/** incrementIfWithinLimits が判定する1カウンターぶんの条件。 */
export interface UsageCounterCondition {
  /** インスタンス内のストレージキー (例: `uid:{uid}` / `ip:{ip}` / `total` / `scan:uid:{uid}`)。 */
  counterKey: string;
  /** このカウンターの上限回数。現在値が上限以上なら加算せず拒否する。 */
  maxCount: number;
}

/** 日次インスタンスの掃除までの猶予。当日しか使わないため、2日後にストレージごと削除してゴミを残さない。 */
export const dailyCounterPurgeDelayMilliseconds = 2 * 24 * 60 * 60 * 1000;

/** 月次インスタンスの掃除までの猶予。初回加算 (月内) から 40 日後には月が終わっているため、その時点で削除する。 */
export const monthlyCounterPurgeDelayMilliseconds = 40 * 24 * 60 * 60 * 1000;

/** 1日ぶん・1ヶ月ぶんの回数カウンター群を保持する Durable Object。 */
export class UsageCounter extends DurableObject {
  /**
   * すべての条件が上限未満なら全カウンターを +1 して true を返し、
   * 1つでも上限に達していれば何も加算せず false を返す。
   * Durable Object の直列実行により、並行リクエストでも上限を超えて加算されない。
   * purgeDelayMilliseconds は初回加算時に 1 度だけアラームに設定され、期限が来るとストレージを全削除する
   * (日次インスタンスは dailyCounterPurgeDelayMilliseconds、月次は monthlyCounterPurgeDelayMilliseconds)。
   */
  async incrementIfWithinLimits(
    usageCounterConditions: UsageCounterCondition[],
    purgeDelayMilliseconds: number,
  ): Promise<boolean> {
    const currentCounts = await Promise.all(
      usageCounterConditions.map(
        async (condition) => (await this.ctx.storage.get<number>(condition.counterKey)) ?? 0,
      ),
    );
    if (
      usageCounterConditions.some(
        (condition, conditionIndex) => currentCounts[conditionIndex] >= condition.maxCount,
      )
    ) {
      return false;
    }
    await Promise.all(
      usageCounterConditions.map((condition, conditionIndex) =>
        this.ctx.storage.put(condition.counterKey, currentCounts[conditionIndex] + 1),
      ),
    );
    if ((await this.ctx.storage.getAlarm()) === null) {
      await this.ctx.storage.setAlarm(Date.now() + purgeDelayMilliseconds);
    }
    return true;
  }

  /** カウンターの現在値を返す (加算しない)。未使用のキーは 0。 */
  async getCount(counterKey: string): Promise<number> {
    return (await this.ctx.storage.get<number>(counterKey)) ?? 0;
  }

  /**
   * カウンターの値を指定値に上書きする (DEBUG 用。現在値を見ずに設定する)。
   * 加算と同じく、初回設定時にアラームが未設定ならストレージ削除のアラームを立てる
   * (設定しただけのインスタンスがゴミとして残らないようにする)。
   * 冪等: 同じ値で何度呼んでも結果は同じ。
   */
  async setCount(counterKey: string, count: number, purgeDelayMilliseconds: number): Promise<void> {
    await this.ctx.storage.put(counterKey, count);
    if ((await this.ctx.storage.getAlarm()) === null) {
      await this.ctx.storage.setAlarm(Date.now() + purgeDelayMilliseconds);
    }
  }

  /** カウンターの掃除。当日・当月を過ぎたインスタンスのストレージを全削除する。 */
  async alarm(): Promise<void> {
    await this.ctx.storage.deleteAll();
  }
}
