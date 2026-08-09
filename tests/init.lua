-- Headless assertions for the pure version module.
-- Run with:  nvim --headless -l tests/init.lua
package.path = "./lua/?.lua;./lua/?/init.lua;" .. package.path

local total_failures = 0
local files = vim.fn.glob("tests/*_spec.lua", false, true)

for _, file in ipairs(files) do
	io.write(string.format("--- %s ---\n", file))
	local failures = dofile(file)
	if not failures then
		io.write(string.format("\nMissing failures from %s\n", file))
		os.exit(1)
	end

	if failures > 0 then
		io.write(string.format("\n%d assertion(s) failed\n", failures))
	end

	total_failures = total_failures + failures
end

if total_failures > 0 then
	io.write(string.format("\n%d total assertion(s) failed\n", total_failures))
	os.exit(1)
end

io.write("\nAll assertions passed\n")
