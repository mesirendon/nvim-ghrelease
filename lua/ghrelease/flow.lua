-- The ordered interaction, written as a linear script over a coroutine. Each
-- `await` call suspends until its callback-based operation completes.
local gh = require("ghrelease.gh")
local prompt = require("ghrelease.prompt")
local version = require("ghrelease.version")
local config = require("ghrelease.config")

local unpack = table.unpack or unpack

local M = {}

local function notify(msg, level)
  vim.notify(msg, level or vim.log.levels.INFO, { title = "ghrelease" })
end

-- Order the bump suggestions so the configured default appears first.
local function order_suggestions(suggestions)
  local default = config.options.default_bump
  table.sort(suggestions, function(a, b)
    if a.kind == default then
      return true
    end
    if b.kind == default then
      return false
    end
    return false
  end)
  return suggestions
end

--- The full flow body. `await(fn)` runs `fn(resume)` and yields until resume is
--- called, returning whatever resume received.
local function body(await)
  -- 1. Preflight -------------------------------------------------------------
  local ok, err = await(function(done)
    gh.check(function(o, e)
      done(o, e)
    end)
  end)
  if not ok then
    notify(err, vim.log.levels.ERROR)
    return
  end

  -- 2. Context: show existing releases --------------------------------------
  local list_text = await(function(done)
    gh.list(config.options.list_limit, done)
  end)
  await(function(done)
    prompt.context("Current releases", list_text, done)
  end)

  -- 3. Version suggestion ----------------------------------------------------
  local latest = await(function(done)
    gh.latest_tag(done)
  end)

  local tag_default
  local suggestions = order_suggestions(version.suggest(latest))
  if #suggestions > 0 then
    local items = vim.deepcopy(suggestions)
    table.insert(items, { kind = "custom", label = "custom       → enter manually" })
    local choice = await(function(done)
      prompt.select(items, {
        prompt = "Next release (latest: " .. (latest or "none") .. ")",
        format_item = function(item)
          return item.label
        end,
      }, done)
    end)
    if not choice then
      notify("Cancelled.", vim.log.levels.WARN)
      return
    end
    tag_default = choice.tag or latest or config.options.first_tag
  else
    -- No parseable prior tag: seed a first release tag.
    tag_default = latest or config.options.first_tag
  end

  -- 4. Tag -------------------------------------------------------------------
  local tag = await(function(done)
    prompt.buffer_step({ title = "Tag name", default = tag_default }, done)
  end)
  if tag == "" then
    notify("Cancelled: no tag provided.", vim.log.levels.WARN)
    return
  end

  -- 5. Title -----------------------------------------------------------------
  local title = await(function(done)
    prompt.buffer_step({ title = "Release title (optional)", default = tag }, done)
  end)

  -- 6. Notes source ----------------------------------------------------------
  local sources = {
    { key = "own", label = "Write my own" },
    { key = "generated", label = "Use GitHub generated notes as a template" },
    { key = "commitlog", label = "Use the commit log as a template" },
    { key = "blank", label = "Leave blank" },
  }
  local source = await(function(done)
    prompt.select(sources, {
      prompt = "Release notes",
      format_item = function(item)
        return item.label
      end,
    }, done)
  end)
  if not source then
    notify("Cancelled.", vim.log.levels.WARN)
    return
  end

  -- 7. Notes buffer (unless left blank) -------------------------------------
  local notes = ""
  if source.key ~= "blank" then
    local seed = ""
    if source.key == "generated" then
      notify("Fetching generated notes…")
      seed = await(function(done)
        gh.generated_notes(tag, latest, done)
      end)
    elseif source.key == "commitlog" then
      seed = await(function(done)
        gh.commit_log(latest, done)
      end)
    end
    notes = await(function(done)
      prompt.buffer_step({ title = "Release notes", default = seed, filetype = "markdown" }, done)
    end)
  end

  -- 8. Prerelease ------------------------------------------------------------
  local prerelease = await(function(done)
    prompt.confirm("Is this a prerelease?", done)
  end)

  -- 9. Submit ----------------------------------------------------------------
  local submit_items = {
    { key = "publish", label = "Publish release" },
    { key = "draft", label = "Save as draft" },
    { key = "cancel", label = "Cancel" },
  }
  local submit = await(function(done)
    prompt.select(submit_items, {
      prompt = "Submit?",
      format_item = function(item)
        return item.label
      end,
    }, done)
  end)
  if not submit or submit.key == "cancel" then
    notify("Cancelled — no release created.", vim.log.levels.WARN)
    return
  end

  -- 10. Create ---------------------------------------------------------------
  notify("Creating release " .. tag .. "…")
  local created, output = await(function(done)
    gh.create({
      tag = tag,
      title = title,
      notes = notes,
      prerelease = prerelease,
      draft = submit.key == "draft",
    }, done)
  end)
  if created then
    notify("Release created: " .. output)
  else
    notify("Failed to create release:\n" .. output, vim.log.levels.ERROR)
  end
end

--- Entry point: drive `body` inside a coroutine.
function M.run()
  local co
  local function await(fn)
    fn(function(...)
      -- Capture an explicit arity via select("#") so trailing nils survive the
      -- resume (Neovim's LuaJIT has no table.pack, and `#` truncates nil holes).
      local n = select("#", ...)
      local args = { ... }
      vim.schedule(function()
        local ok, err = coroutine.resume(co, unpack(args, 1, n))
        if not ok then
          vim.notify("ghrelease error: " .. tostring(err), vim.log.levels.ERROR)
        end
      end)
    end)
    return coroutine.yield()
  end

  co = coroutine.create(function()
    body(await)
  end)
  local ok, err = coroutine.resume(co)
  if not ok then
    vim.notify("ghrelease error: " .. tostring(err), vim.log.levels.ERROR)
  end
end

return M
