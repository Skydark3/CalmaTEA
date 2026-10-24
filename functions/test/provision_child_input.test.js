const assert = require("node:assert/strict");
const test = require("node:test");

const {
  generateTemporaryPassword,
  InvalidProvisionChildInputError,
  parseProvisionChildInput,
} = require("../lib/provision_child_input.js");

test("normalizes childId and email", () => {
  assert.deepEqual(
    parseProvisionChildInput({
      childId: " child-123 ",
      email: " Patient@Example.COM ",
    }),
    {childId: "child-123", email: "patient@example.com"},
  );
});

test("rejects invalid child identifiers", () => {
  for (const childId of ["", "   ", "children/child-123"]) {
    assert.throws(
      () => parseProvisionChildInput({childId, email: "patient@example.com"}),
      InvalidProvisionChildInputError,
    );
  }
});

test("rejects invalid email and unexpected fields", () => {
  assert.throws(
    () => parseProvisionChildInput({childId: "child-123", email: "invalid"}),
    InvalidProvisionChildInputError,
  );
  assert.throws(
    () =>
      parseProvisionChildInput({
        childId: "child-123",
        email: "patient@example.com",
        role: "child",
      }),
    InvalidProvisionChildInputError,
  );
});

test("generates a non-empty password without returning it in parsed input", () => {
  const password = generateTemporaryPassword();
  const parsed = parseProvisionChildInput({
    childId: "child-123",
    email: "patient@example.com",
  });

  assert.ok(password.length >= 32);
  assert.equal(Object.hasOwn(parsed, "password"), false);
  assert.notEqual(generateTemporaryPassword(), password);
});
