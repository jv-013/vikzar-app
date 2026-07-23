import { HttpsError } from "firebase-functions/v2/https";
import {
  requireString,
  optionalString,
  requireNumber,
  optionalNumber,
  requireNumberInRange,
  optionalNumberInRange,
  requireBoundedString,
  optionalBoundedString,
  requireExactShape,
  requireEnum,
  requireStringArray,
  requireIsoTimestamp,
  requireObject,
  optionalObject,
} from "../../src/lib/validation";

describe("requireString", () => {
  it("returns the value when present and non-empty", () => {
    expect(requireString({ field: "hello" }, "field")).toBe("hello");
  });

  it("throws invalid-argument when missing", () => {
    expect(() => requireString({}, "field")).toThrow(HttpsError);
  });

  it("throws invalid-argument when empty string", () => {
    expect(() => requireString({ field: "" }, "field")).toThrow(HttpsError);
  });

  it("throws invalid-argument when wrong type", () => {
    expect(() => requireString({ field: 42 }, "field")).toThrow(HttpsError);
  });
});

describe("optionalString", () => {
  it("returns undefined when absent", () => {
    expect(optionalString({}, "field")).toBeUndefined();
  });

  it("returns undefined when null", () => {
    expect(optionalString({ field: null }, "field")).toBeUndefined();
  });

  it("returns the value when present", () => {
    expect(optionalString({ field: "x" }, "field")).toBe("x");
  });

  it("throws when present but wrong type", () => {
    expect(() => optionalString({ field: 1 }, "field")).toThrow(HttpsError);
  });
});

describe("requireNumber", () => {
  it("returns the value when a number", () => {
    expect(requireNumber({ field: 3.14 }, "field")).toBe(3.14);
  });

  it("accepts zero", () => {
    expect(requireNumber({ field: 0 }, "field")).toBe(0);
  });

  it("throws when missing", () => {
    expect(() => requireNumber({}, "field")).toThrow(HttpsError);
  });

  it("throws when NaN", () => {
    expect(() => requireNumber({ field: NaN }, "field")).toThrow(HttpsError);
  });

  it("throws when a string", () => {
    expect(() => requireNumber({ field: "1" }, "field")).toThrow(HttpsError);
  });
});

describe("optionalNumber", () => {
  it("returns undefined when absent", () => {
    expect(optionalNumber({}, "field")).toBeUndefined();
  });

  it("returns the value when present", () => {
    expect(optionalNumber({ field: 5 }, "field")).toBe(5);
  });
});

describe("requireEnum", () => {
  it("accepts an allowed value", () => {
    expect(requireEnum({ field: "low" }, "field", ["low", "high"] as const)).toBe("low");
  });

  it("rejects a value outside the allowed set", () => {
    expect(() => requireEnum({ field: "medium" }, "field", ["low", "high"] as const)).toThrow(
      HttpsError
    );
  });
});

describe("requireStringArray", () => {
  it("returns a non-empty string array", () => {
    expect(requireStringArray({ field: ["a", "b"] }, "field")).toEqual(["a", "b"]);
  });

  it("rejects an empty array", () => {
    expect(() => requireStringArray({ field: [] }, "field")).toThrow(HttpsError);
  });

  it("rejects a non-array", () => {
    expect(() => requireStringArray({ field: "a" }, "field")).toThrow(HttpsError);
  });

  it("rejects an array with a non-string element", () => {
    expect(() => requireStringArray({ field: ["a", 1] }, "field")).toThrow(HttpsError);
  });
});

describe("requireIsoTimestamp", () => {
  it("parses a valid ISO 8601 string", () => {
    const result = requireIsoTimestamp({ field: "2026-07-19T14:30:00.000Z" }, "field");
    expect(result.toISOString()).toBe("2026-07-19T14:30:00.000Z");
  });

  it("rejects an unparseable string", () => {
    expect(() => requireIsoTimestamp({ field: "not-a-date" }, "field")).toThrow(HttpsError);
  });
});

describe("requireNumberInRange", () => {
  it("accepts a value within the range, inclusive of bounds", () => {
    expect(requireNumberInRange({ field: 0 }, "field", 0, 1)).toBe(0);
    expect(requireNumberInRange({ field: 1 }, "field", 0, 1)).toBe(1);
    expect(requireNumberInRange({ field: 0.5 }, "field", 0, 1)).toBe(0.5);
  });

  it("rejects a value below the minimum", () => {
    expect(() => requireNumberInRange({ field: -0.01 }, "field", 0, 1)).toThrow(HttpsError);
  });

  it("rejects a value above the maximum", () => {
    expect(() => requireNumberInRange({ field: 1.01 }, "field", 0, 1)).toThrow(HttpsError);
  });

  it("still enforces the underlying number type check", () => {
    expect(() => requireNumberInRange({ field: "0.5" }, "field", 0, 1)).toThrow(HttpsError);
  });
});

describe("optionalNumberInRange", () => {
  it("returns undefined when absent", () => {
    expect(optionalNumberInRange({}, "field", 0, 1)).toBeUndefined();
  });

  it("rejects an out-of-range value when present", () => {
    expect(() => optionalNumberInRange({ field: 5 }, "field", 0, 1)).toThrow(HttpsError);
  });
});

describe("requireBoundedString / optionalBoundedString", () => {
  it("accepts a string within the length limit", () => {
    expect(requireBoundedString({ field: "hello" }, "field", 10)).toBe("hello");
  });

  it("rejects a string exceeding the length limit", () => {
    expect(() => requireBoundedString({ field: "a".repeat(11) }, "field", 10)).toThrow(HttpsError);
  });

  it("accepts a string exactly at the length limit", () => {
    expect(requireBoundedString({ field: "a".repeat(10) }, "field", 10)).toBe("a".repeat(10));
  });

  it("optionalBoundedString returns undefined when absent", () => {
    expect(optionalBoundedString({}, "field", 10)).toBeUndefined();
  });

  it("optionalBoundedString rejects an over-length value when present", () => {
    expect(() => optionalBoundedString({ field: "a".repeat(11) }, "field", 10)).toThrow(HttpsError);
  });
});

describe("requireExactShape", () => {
  it("accepts an object whose keys are all allowlisted", () => {
    expect(() => requireExactShape({ a: 1, b: 2 }, ["a", "b", "c"])).not.toThrow();
  });

  it("rejects an object with an unknown key", () => {
    expect(() => requireExactShape({ a: 1, evil: "payload" }, ["a", "b"])).toThrow(HttpsError);
  });

  it("rejects a non-object payload", () => {
    expect(() => requireExactShape("not-an-object", ["a"])).toThrow(HttpsError);
    expect(() => requireExactShape(["a"], ["a"])).toThrow(HttpsError);
    expect(() => requireExactShape(null, ["a"])).toThrow(HttpsError);
  });
});

describe("requireObject / optionalObject", () => {
  it("returns a plain object", () => {
    expect(requireObject({ field: { a: 1 } }, "field")).toEqual({ a: 1 });
  });

  it("rejects an array", () => {
    expect(() => requireObject({ field: [1, 2] }, "field")).toThrow(HttpsError);
  });

  it("optionalObject returns undefined when absent", () => {
    expect(optionalObject({}, "field")).toBeUndefined();
  });
});
