// test/fetch_mock.ts のテスト。
// 他のテストが頼っている 2 つの保証 (意図しない外部通信が無いこと・未消費の差し替えが残らないこと) を検証する。
import { beforeAll, describe, expect, it } from "vitest";
import { fetchMock } from "./fetch_mock";

const mockedApiOrigin = "https://mocked-api.test";

beforeAll(() => {
  fetchMock.activate();
});

describe("fetch の差し替え", () => {
  it("登録した origin・path・method に一致する fetch へ、登録した status と本体を返す", async () => {
    let capturedRequest: { headers: Record<string, string>; body: string } | undefined;
    fetchMock
      .get(mockedApiOrigin)
      .intercept({ path: "/v1/items?page=2", method: "POST" })
      .reply(201, (mockedFetchRequest) => {
        capturedRequest = mockedFetchRequest;
        return JSON.stringify({ created: true });
      });

    const response = await fetch(`${mockedApiOrigin}/v1/items?page=2`, {
      method: "POST",
      headers: { "X-Api-Key": "test-api-key" },
      body: JSON.stringify({ name: "item" }),
    });
    expect(response.status).toBe(201);
    expect(await response.json()).toEqual({ created: true });
    expect(capturedRequest?.headers["x-api-key"]).toBe("test-api-key");
    expect(capturedRequest?.body).toBe(JSON.stringify({ name: "item" }));
    fetchMock.assertNoPendingInterceptors();
  });

  it("登録は 1 回の fetch で消費され、2 回目の同じ fetch は失敗する", async () => {
    fetchMock.get(mockedApiOrigin).intercept({ path: "/once", method: "GET" }).reply(200, "first");

    expect(await (await fetch(`${mockedApiOrigin}/once`)).text()).toBe("first");
    await expect(fetch(`${mockedApiOrigin}/once`)).rejects.toThrow("差し替えを登録していない fetch です");
  });

  it("登録していない fetch (origin・path・method のいずれかが違う) は実通信せず失敗する", async () => {
    fetchMock.get(mockedApiOrigin).intercept({ path: "/items", method: "POST" }).reply(200, "{}");

    await expect(fetch("https://other-api.test/items", { method: "POST" })).rejects.toThrow();
    await expect(fetch(`${mockedApiOrigin}/other`, { method: "POST" })).rejects.toThrow();
    await expect(fetch(`${mockedApiOrigin}/items`, { method: "GET" })).rejects.toThrow();
    // どれにも消費されていないため未消費として検出される
    expect(() => fetchMock.assertNoPendingInterceptors()).toThrow("POST https://mocked-api.test/items");
  });

  it("未消費の検出後は登録が破棄され、後続のテストへ持ち越さない", async () => {
    fetchMock.get(mockedApiOrigin).intercept({ path: "/leftover", method: "GET" }).reply(200, "leftover");
    expect(() => fetchMock.assertNoPendingInterceptors()).toThrow();

    fetchMock.assertNoPendingInterceptors();
    await expect(fetch(`${mockedApiOrigin}/leftover`)).rejects.toThrow();
  });
});
