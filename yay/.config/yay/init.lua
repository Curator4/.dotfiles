-- ~/.config/yay/init.lua  (stow package: yay)
-- Aegis review-hook sensor for yay v13.
--
-- Purpose: emit a structured, append-only audit trail of what gets installed
-- on this box, plus deterministic AUR-provenance signals (recently-modified
-- PKGBUILDs, maintainer changes), for the Aegis security agent to read
-- asynchronously at her morning sweep.
--   consumer: ~/workspace/ai/household-oc/agents/aegis/skills/morning-report/SKILL.md
--   contract: ~/workspace/ai/household-oc/agents/aegis/TOOLS.md  (publisher tools)
--
-- Design rules (deliberate):
--   * The hook is a SENSOR, not a gate. It logs and (non-blockingly)
--     pre-deselects risky AUR upgrades; it NEVER aborts an interactive yay
--     run. The hard block (yay.abort) is deferred until the spool has real
--     data to calibrate the trigger against. Observe -> warn -> pre-deselect
--     -> block; we are at pre-deselect.
--   * Every callback is pcall-wrapped: a bug in here must never break yay.
--   * State lives under $XDG_STATE_HOME/yay (outside the dotfiles tree, so it
--     never shows up as git drift that Aegis would nag about). init.lua itself
--     IS tracked in ~/.dotfiles (it runs as the operator on every yay call --
--     a trust anchor worth version-controlling and drift-watching).

local RECENT_DAYS = 5  -- AUR PKGBUILDs modified within this window get pre-deselected + logged

-- ── paths ────────────────────────────────────────────────────────────────
local HOME = os.getenv("HOME") or ""
local STATE_DIR = (os.getenv("XDG_STATE_HOME") or (HOME .. "/.local/state")) .. "/yay"
local SPOOL = STATE_DIR .. "/review-events.jsonl"
local MAINT = STATE_DIR .. "/maintainers.tsv"

local function ensure_state_dir()
  os.execute('mkdir -p "' .. STATE_DIR .. '" 2>/dev/null')
end

-- ── minimal flat-JSON encoder (no external deps; Aegis reads with jq) ──────
local function json_escape(s)
  s = s:gsub("\\", "\\\\")
  s = s:gsub('"', '\\"')
  s = s:gsub("\n", "\\n")
  s = s:gsub("\r", "\\r")
  s = s:gsub("\t", "\\t")
  return s
end

local function json_num(v)
  if v == math.floor(v) and math.abs(v) < 1e15 then
    return string.format("%.0f", v)  -- avoids decimal / scientific notation on epochs
  end
  return tostring(v)
end

local function json_val(v)
  local t = type(v)
  if t == "number" then return json_num(v)
  elseif t == "boolean" then return tostring(v)
  else return '"' .. json_escape(tostring(v)) .. '"' end
end

-- encode an ordered list of {key, value} pairs; nil values are skipped
local function json_obj(kvs)
  local parts = {}
  for _, kv in ipairs(kvs) do
    local k, v = kv[1], kv[2]
    if v ~= nil then
      parts[#parts + 1] = '"' .. json_escape(k) .. '":' .. json_val(v)
    end
  end
  return "{" .. table.concat(parts, ",") .. "}"
end

local function spool(kvs)
  local ok, err = pcall(function()
    ensure_state_dir()
    local f = io.open(SPOOL, "a")
    if not f then return end
    -- stamp every record so Aegis can filter to "since yesterday's report"
    table.insert(kvs, 1, {"iso", os.date("!%Y-%m-%dT%H:%M:%SZ")})
    table.insert(kvs, 1, {"ts", os.time()})
    f:write(json_obj(kvs) .. "\n")
    f:close()
  end)
  if not ok then yay.log.warn("aegis-hook: spool write failed: " .. tostring(err)) end
end

-- ── maintainer state (TSV, no JSON decoder needed) ────────────────────────
local function read_maintainers()
  local known = {}
  local f = io.open(MAINT, "r")
  if not f then return known end
  for line in f:lines() do
    local base, m = line:match("^([^\t]+)\t(.*)$")
    if base then known[base] = m end
  end
  f:close()
  return known
end

local function write_maintainers(known)
  ensure_state_dir()
  local f = io.open(MAINT, "w")
  if not f then return end
  for base, m in pairs(known) do
    f:write(base .. "\t" .. m .. "\n")
  end
  f:close()
end

-- ── UpgradeSelect: pre-deselect risky AUR upgrades + log provenance ───────
-- Fires during `yay -Syu` after the upgrade graph is built, before the
-- exclusion menu. We return an exclude list (non-blocking: the operator still
-- sees the menu and can re-tick anything) and never set skip_menu.
yay.create_autocmd("UpgradeSelect", {
  desc = "aegis: pre-deselect recently-modified / maintainer-changed AUR upgrades",
  callback = function(event)
    local ok, result = pcall(function()
      local data = event.data or {}
      local upgrades = data.upgrades or {}
      local recent_cutoff = os.time() - (RECENT_DAYS * 24 * 60 * 60)
      local exclude = {}
      local known = read_maintainers()
      local state_dirty = false

      for _, pkg in ipairs(upgrades) do
        if pkg.repository == "aur" then
          local name = pkg.name
          local base = pkg.base or name
          local reasons = {}

          -- (1) recently-modified PKGBUILD
          if type(pkg.last_modified) == "number" and pkg.last_modified >= recent_cutoff then
            reasons[#reasons + 1] = "recently_modified"
          end

          -- (2) maintainer change vs last-known
          local m = pkg.maintainer
          if type(m) == "string" and m ~= "" then
            local prev = known[base]
            if prev and prev ~= m then
              reasons[#reasons + 1] = "maintainer_changed"
              spool({
                {"event", "maintainer_changed"},
                {"name", name}, {"base", base},
                {"prev_maintainer", prev}, {"new_maintainer", m},
                {"last_modified", pkg.last_modified},
                {"local_version", pkg.local_version}, {"remote_version", pkg.remote_version},
              })
            end
            known[base] = m
            state_dirty = true
          end

          if #reasons > 0 then
            exclude[#exclude + 1] = name
            spool({
              {"event", "upgrade_predeselected"},
              {"name", name}, {"base", base},
              {"reasons", table.concat(reasons, ",")},
              {"maintainer", m},
              {"last_modified", pkg.last_modified},
              {"local_version", pkg.local_version}, {"remote_version", pkg.remote_version},
            })
          end
        end
      end

      if state_dirty then write_maintainers(known) end
      return { exclude = exclude, skip_menu = false }
    end)

    if not ok then
      yay.log.warn("aegis-hook UpgradeSelect failed: " .. tostring(result))
      return nil
    end
    return result
  end,
})

-- ── AURPreInstall: log install-time provenance (sensor only, no abort) ────
-- Fires after the PKGBUILD is fetched, before build. This is where MVP-3's
-- source-swap / suspicious-content abort would eventually live (via
-- yay.abort), deferred until calibrated. For now: pure provenance capture,
-- including for fresh `yay -S foo` installs that never hit UpgradeSelect.
yay.create_autocmd("AURPreInstall", {
  desc = "aegis: log AUR install provenance (PKGBUILD age, sources, url)",
  callback = function(event)
    local ok, err = pcall(function()
      local d = event.data or {}
      local srcinfo = d.srcinfo or {}
      local sources
      if type(srcinfo.source) == "table" then
        sources = table.concat(srcinfo.source, " | ")
      end
      spool({
        {"event", "aur_preinstall"},
        {"base", d.base},
        {"version", d.version},
        {"installed", d.installed},
        {"last_modified", d.last_modified},
        {"url", srcinfo.url},
        {"sources", sources},
        {"pkgbuild_path", d.pkgbuild_path},
      })
    end)
    if not ok then yay.log.warn("aegis-hook AURPreInstall failed: " .. tostring(err)) end
  end,
})

-- ── PostInstall: the core audit trail — what actually landed on the box ────
yay.create_autocmd("PostInstall", {
  desc = "aegis: audit trail of completed installs",
  callback = function(event)
    local ok, err = pcall(function()
      local pkgs = (event.data or {}).packages or {}
      for _, pkg in ipairs(pkgs) do
        spool({
          {"event", "installed"},
          {"name", pkg.name},
          {"version", pkg.version},
          {"local_version", pkg.local_version},
          {"source", pkg.source},
          {"reason", pkg.reason},
        })
      end
    end)
    if not ok then yay.log.warn("aegis-hook PostInstall failed: " .. tostring(err)) end
  end,
})

yay.log.debug("aegis review hooks loaded")
