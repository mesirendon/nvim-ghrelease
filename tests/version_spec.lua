-- Headless assertions for the pure version module.
-- Run with:  nvim --headless -l tests/version_spec.lua
package.path = "./lua/?.lua;./lua/?/init.lua;" .. package.path

local version = require("ghrelease.version")

local failures = 0
local function eq(got, want, label)
  if got ~= want then
    failures = failures + 1
    io.write(string.format("FAIL  %-28s got=%s want=%s\n", label, tostring(got), tostring(want)))
  else
    io.write(string.format("ok    %-28s %s\n", label, tostring(got)))
  end
end

-- parse ---------------------------------------------------------------------
local p = version.parse("v1.3.2")
eq(p and p.prefix, "v", "parse prefix")
eq(p and p.major, 1, "parse major")
eq(p and p.minor, 3, "parse minor")
eq(p and p.patch, 2, "parse patch")
eq(version.parse("not-a-version"), nil, "parse invalid")
eq(version.parse("1.2.3").prefix, "", "parse no-prefix")

-- bump ----------------------------------------------------------------------
eq(version.bump(version.parse("v1.3.2"), "patch"), "v1.3.3", "bump patch")
eq(version.bump(version.parse("v1.3.2"), "minor"), "v1.4.0", "bump minor")
eq(version.bump(version.parse("v1.3.2"), "major"), "v2.0.0", "bump major")
eq(version.bump(version.parse("v1.3.2"), "prerelease"), "v1.3.3-rc.1", "bump prerelease")

-- suggest -------------------------------------------------------------------
local s = version.suggest("v1.3.2")
eq(#s, 4, "suggest count")
eq(s[1].kind, "patch", "suggest first kind")
eq(#version.suggest("garbage"), 0, "suggest invalid -> empty")

if failures > 0 then
  io.write(string.format("\n%d assertion(s) failed\n", failures))
  os.exit(1)
end
io.write("\nAll assertions passed\n")
