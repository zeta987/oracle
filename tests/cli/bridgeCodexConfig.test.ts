import { describe, expect, test } from "vitest";
import { formatCodexMcpSnippet } from "../../src/cli/bridge/codexConfig.js";

describe("formatCodexMcpSnippet", () => {
  test("points the optional npx setup at the fork package", () => {
    const snippet = formatCodexMcpSnippet({ includeToken: false });

    expect(snippet).toContain('# args = ["--yes", "--package", "@zeta987/oracle", "oracle-mcp"]');
    expect(snippet).not.toContain("@steipete/oracle");
  });
});
