import { extractMemoryCandidate } from "../../../src/lib/intelligence/razMemoryExtraction";

describe("extractMemoryCandidate", () => {
  it("returns a candidate when a body part and a concern word are both present", () => {
    const candidate = extractMemoryCandidate("my left knee has been sore since Tuesday");
    expect(candidate).not.toBeNull();
    expect(candidate?.topic).toBe("left_knee_discomfort");
    expect(candidate?.fact).toContain("my left knee has been sore since Tuesday");
  });

  it("does not fabricate a candidate from a body part alone, with no concern word", () => {
    expect(extractMemoryCandidate("I hit my knee on the ball during the drill")).toBeNull();
  });

  it("does not fabricate a candidate from a concern word alone, with no body part", () => {
    expect(extractMemoryCandidate("I'm feeling a bit sore and tired today")).toBeNull();
  });

  it("returns null for an unrelated question", () => {
    expect(extractMemoryCandidate("What's my training load looking like this week?")).toBeNull();
  });

  it("matches a general body part when no left/right qualifier is given", () => {
    const candidate = extractMemoryCandidate("my ankle feels tight after that session");
    expect(candidate?.topic).toBe("ankle_discomfort");
  });

  it("prefers the more specific left/right topic over the general one", () => {
    const candidate = extractMemoryCandidate("my right hamstring is a bit tight");
    expect(candidate?.topic).toBe("right_hamstring_discomfort");
  });

  it("truncates a very long question in the stored fact rather than storing it unbounded", () => {
    const longQuestion = `my knee is sore, ${"a".repeat(300)}`;
    const candidate = extractMemoryCandidate(longQuestion);
    expect(candidate).not.toBeNull();
    expect(candidate!.fact.length).toBeLessThan(longQuestion.length);
    expect(candidate!.fact).toContain("…");
  });

  it("is case-insensitive for both the body part and the concern word", () => {
    const candidate = extractMemoryCandidate("MY SHOULDER IS ACHING today");
    expect(candidate?.topic).toBe("shoulder_discomfort");
  });
});
