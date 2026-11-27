import { describe, expect, it } from "vitest";
import { schemaFromUrl } from "@/lib/db/client";

describe("schemaFromUrl", () => {
  it("reads the schema the migrations were applied to", () => {
    expect(
      schemaFromUrl(
        "postgresql://app:pw@db.internal:5432/appdb?schema=openreply&sslmode=verify-full"
      )
    ).toBe("openreply");
  });

  it("leaves the adapter default when no schema is given", () => {
    expect(schemaFromUrl("postgresql://app:pw@localhost:5432/openreply")).toBeUndefined();
    expect(schemaFromUrl("postgresql://app:pw@localhost:5432/openreply?schema=")).toBeUndefined();
  });

  it("does not throw on a string that is not a URL", () => {
    expect(schemaFromUrl("not a url")).toBeUndefined();
  });
});
