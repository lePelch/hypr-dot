-- Run from the configuration directory: lua tests/workspace_store_test.lua
local tests = {}

local function test(name, callback)
	table.insert(tests, { name = name, callback = callback })
end

local function equal(actual, expected)
	assert(actual == expected, string.format("expected %s, got %s", tostring(expected), tostring(actual)))
end

local function fixture()
	local state = { workspaces = {}, monitors = {}, notifications = {}, calls = {}, timers = {}, events = {}, captures = {}, serial = 0, window_serial = 0, ipc = {} }
	for _, name in ipairs({ "eDP-1", "DP-6", "DP-7" }) do
		state.monitors[name] = { name = name }
	end
	state.monitor = state.monitors["eDP-1"]

	local function bound_monitor(id)
		if id <= 3 then
			return state.monitors["eDP-1"]
		elseif id <= 6 or id == 10 then
			return state.monitors["DP-6"]
		end
		return state.monitors["DP-7"]
	end

	function state.add(id, label, monitor, name)
  state.window_serial = state.window_serial + 1
		local stable_id = state.window_serial
		local workspace = setmetatable({
			id = id,
			name = name or tostring(id),
			monitor = monitor or (id <= 10 and bound_monitor(id) or state.monitor),
			windows = label and 1 or 0,
			layout = { label = label },
   get_windows = function(self)
    local windows = {}
    for index = 1, self.windows do table.insert(windows, { stable_id = stable_id * 100 + index }) end
    return windows
   end,
		}, {
			__index = function(self, key)
				if key == "is_empty" then
					return self.windows == 0
				end
			end,
		})
		state.workspaces[id] = workspace
		return workspace
	end

	function state.activate(workspace)
		state.monitor = workspace.monitor
		state.monitor.active_workspace = workspace
	end

	local function selector(value, key)
		return type(value) == "table" and value[key] or value
	end

	local function factory(kind)
		return function(spec)
			-- Like Hyprland, resolve object selectors when creating the dispatcher.
			return {
				kind = kind,
				workspace = selector(spec.workspace, "id"),
				monitor = selector(spec.monitor, "name"),
				id = spec.id,
				name = spec.name,
			}
		end
	end

	local api = {
		get_active_monitor = function()
			return state.monitor
		end,
  get_monitor = function(name) return state.monitors[name] end,
  exec_cmd = function(command)
   local token = command:match("'capture' '[^']+' '(%x+)'")
   assert(token, command)
   table.insert(state.captures, { token = token, command = command })
  end,
  timer = function(callback, options)
   equal(options.timeout, 8000)
   equal(options.type, "oneshot")
   local timer = { enabled = true, callback = callback }
   function timer:set_enabled(value) self.enabled = value end
   table.insert(state.timers, timer)
   return timer
  end,
  on = function(event, callback) state.events[event] = callback end,
		get_workspace = function(id)
			return state.workspaces[id]
		end,
		get_workspaces = function()
			local workspaces = {}
			for _, workspace in pairs(state.workspaces) do
				table.insert(workspaces, workspace)
			end
			return workspaces
		end,
		notification = { create = function(spec)
			table.insert(state.notifications, spec.text)
		end },
		dsp = {
   event = function(data) return { kind = "event", data = data } end,
			focus = factory("focus"),
			workspace = {
				change_id = factory("change_id"),
				rename = factory("rename"),
				move = factory("move"),
			},
		},
	}

	function api.dispatch(action)
  if action.kind == "event" then table.insert(state.ipc, action.data); return { ok = true } end
		table.insert(state.calls, action)
		if state.fail and state.fail(action) then
			state.fail = nil
			return { ok = false, error = "injected dispatcher failure" }
		end
		local workspace = state.workspaces[action.workspace]
		if action.kind == "focus" then
			workspace = workspace or state.add(action.workspace)
			state.activate(workspace)
			-- Nonpersistent empty workspaces expire once no monitor displays them.
			for id, candidate in pairs(state.workspaces) do
				if candidate.is_empty and candidate.monitor.active_workspace ~= candidate then
					state.workspaces[id] = nil
				end
			end
		elseif not workspace then
			return { ok = false, error = "workspace not found" }
		elseif action.kind == "change_id" then
			if state.workspaces[action.id] then
				return { ok = false, error = "ID is taken" }
			end
			state.workspaces[workspace.id] = nil
			workspace.id = action.id
			state.workspaces[workspace.id] = workspace
		elseif action.kind == "rename" then
			workspace.name = action.name
		elseif action.kind == "move" then
			workspace.monitor = assert(state.monitors[action.monitor])
		else
			error("unexpected dispatcher: " .. action.kind)
		end
		return { ok = true }
	end

	function state.reload()
  state.events = {}
  state.raw = assert(loadfile("workspace_store.lua", "t", setmetatable({
   hl = api,
   os = { getenv = function(key)
    if key == "HYPRLAND_INSTANCE_SIGNATURE" then return "test-session" end
    if key == "HOME" then return "/home/test" end
   end },
   io = { open = function(path)
    equal(path, "/proc/sys/kernel/random/uuid")
    state.serial = state.serial + 1
    return { read = function() return string.format("%032x", state.serial) end, close = function() end }
   end },
  }, { __index = _G })))()
  -- Original transactional tests complete the mocked asynchronous capture.
  -- Dedicated tests below use raw.push/pop to inspect the in-flight phase.
  state.store = setmetatable({}, { __index = state.raw })
  for _, method in ipairs({ "push", "pop", "pop_entry" }) do
   state.store[method] = function(...)
    local token = state.raw[method](...)
    if type(token) ~= "string" then return token end
    if state.raw.result(token) == "pending" then state.raw.complete(token, true) end
    return state.raw.result(token) == "ok"
   end
  end
	end

	function state.queue()
		local labels = {}
		for _, workspace in ipairs(state.store.entries()) do
			table.insert(labels, workspace.layout.label)
		end
		return table.concat(labels, ",")
	end

	function state.stored(id, label, monitor)
		return state.add(id, label, monitor, "workspace-store:" .. id)
	end

	state.activate(state.add(1, "X"))
	state.reload()
	return state
end

test("push parks the whole workspace and leaves the same slot empty", function()
	local s = fixture()
	local original = s.workspaces[1]
	assert(s.store.push())
	equal(s.queue(), "X")
	equal(s.store.entries()[1], original)
	equal(s.monitor.active_workspace.id, 1)
	assert(s.monitor.active_workspace.is_empty)
end)

test("empty workspaces are never inserted", function()
	local s = fixture()
	s.workspaces[1].windows = 0
	assert(not s.store.push())
	equal(#s.calls, 0)
	equal(s.queue(), "")
end)

test("push appends and avoids IDs occupied by unrelated workspaces", function()
	local s = fixture()
	s.stored(1000, "A")
	local unrelated = s.add(1001, "unrelated")
	assert(s.store.push())
	equal(s.queue(), "A,X")
	equal(s.workspaces[1001], unrelated)
	equal(s.store.entries()[2].id, 1002)
end)

test("pop is FIFO and appends the replaced nonempty workspace", function()
	local s = fixture()
	s.stored(1000, "A")
	s.stored(1002, "B")
	assert(s.store.pop())
	equal(s.monitor.active_workspace.layout.label, "A")
	equal(s.monitor.active_workspace.id, 1)
	equal(s.monitor.active_workspace.name, "1")
	equal(s.queue(), "B,X")
end)

test("indexed retrieval is zero-based and reindexes the remaining entries", function()
	local s = fixture()
	s.stored(1000, "A")
	s.stored(1003, "B")
	s.stored(1007, "C")
	assert(s.store.pop(1))
	equal(s.monitor.active_workspace.layout.label, "B")
	equal(s.queue(), "A,C,X")
	assert(s.store.pop(1))
	equal(s.monitor.active_workspace.layout.label, "C")
	equal(s.queue(), "A,X,B")
end)

for _, index in ipairs({ 9, -1, 1.5 }) do
	test("invalid index " .. index .. " selects the last entry before inserting current", function()
		local s = fixture()
		s.stored(1000, "A")
		s.stored(1001, "B")
		assert(s.store.pop(index))
		equal(s.monitor.active_workspace.layout.label, "B")
		equal(s.queue(), "A,X")
	end)
end

test("empty destination is not enqueued and its ID is freed", function()
	local s = fixture()
	s.workspaces[1].windows = 0
	s.stored(1000, "A")
	assert(s.store.pop(0))
	equal(s.monitor.active_workspace.layout.label, "A")
	equal(s.queue(), "")
	equal(s.workspaces[1001], nil)
end)

test("empty store does not displace current even for an invalid index", function()
	local s = fixture()
	local current = s.workspaces[1]
	assert(not s.store.pop(9))
	equal(s.monitor.active_workspace, current)
	equal(#s.calls, 0)
end)

test("entries whose windows have closed are ignored before indexing", function()
	local s = fixture()
	s.stored(1000, "A").windows = 0
	s.stored(1001, "B")
	s.stored(1002, "C").windows = 0
	assert(s.store.pop(9))
	equal(s.monitor.active_workspace.layout.label, "B")
	equal(s.queue(), "X")
end)

test("store with only empty or deleted entries is a no-op", function()
	local s = fixture()
	s.stored(1000, "A").windows = 0
	s.stored(1001, "B")
	s.workspaces[1001] = nil
	assert(not s.store.pop())
	equal(#s.calls, 0)
end)

test("queue order survives a fresh Lua module after config reload", function()
	local s = fixture()
	s.stored(1000, "A")
	s.stored(1007, "B")
	assert(s.store.push())
	s.reload()
	equal(s.queue(), "A,B,X")
	assert(s.store.pop(1))
	equal(s.monitor.active_workspace.layout.label, "B")
	equal(s.queue(), "A,X")
end)

test("cross-monitor retrieval preserves layout and both screens' fixed slots", function()
	local s = fixture()
	local other_screen = s.monitors["DP-6"]
	local other_current = s.add(4, "other", other_screen)
	other_screen.active_workspace = other_current
	local selected = s.stored(1000, "A", other_screen)
	local layout = selected.layout
	assert(s.store.pop())
	equal(s.workspaces[1], selected)
	equal(selected.layout, layout)
	equal(selected.monitor.name, "eDP-1")
	equal(other_screen.active_workspace, other_current)
	equal(other_current.id, 4)
end)

test("retrieval works on slot 10 without treating it as store index 0", function()
	local s = fixture()
	s.activate(s.add(10, "game"))
	s.stored(1000, "A", s.monitors["eDP-1"])
	assert(s.store.pop(0))
	equal(s.monitor.name, "DP-6")
	equal(s.monitor.active_workspace.id, 10)
	equal(s.monitor.active_workspace.name, "10")
	equal(s.queue(), "game")
end)

test("store can grow beyond ten entries", function()
	local s = fixture()
	for index = 0, 11 do
		s.stored(1000 + index, tostring(index))
	end
	assert(s.store.push())
	equal(#s.store.entries(), 13)
	assert(s.store.pop(9))
	equal(s.monitor.active_workspace.layout.label, "9")
	equal(#s.store.entries(), 12)
end)

test("scroll skips storage and wraps through existing normal workspaces", function()
	local s = fixture()
	s.add(4, "B")
	s.add(9, "C")
	s.add(1001, "unrelated")
	s.stored(1000, "A")
	assert(s.store.cycle(-1))
	equal(s.monitor.active_workspace.id, 9)
	assert(s.store.cycle(1))
	equal(s.monitor.active_workspace.id, 1)
	assert(s.store.cycle(1))
	equal(s.monitor.active_workspace.id, 4)
	equal(s.queue(), "A")
end)

test("scroll with a single normal workspace does not refocus itself", function()
	local s = fixture()
	s.stored(1000, "A")
	assert(s.store.cycle(1))
	equal(#s.calls, 0)
end)

test("special workspaces and nonstandard slots are protected", function()
	local s = fixture()
	s.stored(1000, "A")
	s.monitor.active_special_workspace = { id = -99 }
	assert(not s.store.push())
	assert(not s.store.pop())
	assert(not s.store.cycle(1))
	s.monitor.active_special_workspace = nil
	s.activate(s.add(11, "outside"))
	assert(not s.store.push())
	assert(not s.store.pop())
	equal(#s.calls, 0)
end)

test("missing monitor or active workspace is a no-op", function()
	local s = fixture()
	s.monitor.active_workspace = nil
	assert(not s.store.push())
	assert(not s.store.pop())
	s.monitor = nil
	assert(not s.store.push())
	assert(not s.store.pop())
end)

for _, kind in ipairs({ "change_id", "rename", "focus" }) do
	test("push failure during " .. kind .. " restores the original workspace", function()
		local s = fixture()
		local current = s.workspaces[1]
		s.fail = function(action)
			return action.kind == kind
		end
		assert(not s.store.push())
		equal(s.workspaces[1], current)
		equal(current.name, "1")
		equal(s.queue(), "")
		equal(#s.notifications, 1)
	end)
end

for _, kind in ipairs({ "change_id", "rename", "move", "focus" }) do
	test("retrieval failure during " .. kind .. " restores queue, monitor and current", function()
		local s = fixture()
		local current = s.workspaces[1]
		local selected = s.stored(1000, "A", s.monitors["DP-6"])
		s.fail = function(action)
			if action.kind ~= kind then
				return false
			end
			if kind == "change_id" then
				return action.workspace == 1000
			elseif kind == "rename" then
				return action.workspace == 1 and action.name == "1"
			end
			return true
		end
		assert(not s.store.pop())
		equal(s.workspaces[1], current)
		equal(current.name, "1")
		equal(s.monitor.active_workspace, current)
		equal(selected.id, 1000)
		equal(selected.monitor.name, "DP-6")
		equal(s.queue(), "A")
		equal(#s.notifications, 1)
	end)
end

test("failed parking does not remove the selected entry", function()
	local s = fixture()
	s.stored(1000, "A")
	s.fail = function(action)
		return action.kind == "change_id" and action.workspace == 1
	end
	assert(not s.store.pop())
	equal(s.queue(), "A")
	equal(s.workspaces[1].layout.label, "X")
end)

test("all keybindings map digits to the correct zero-based store index", function()
	local bindings, calls = {}, {}
	local namespace = setmetatable({}, {
		__index = function()
			return function()
				return {}
			end
		end,
	})
	local fake_store = {}
	for _, method in ipairs({ "push", "pop", "cycle" }) do
		fake_store[method] = function(value)
			table.insert(calls, { method, value })
		end
	end
	local environment = setmetatable({
		hl = {
			bind = function(key, callback)
				bindings[key] = callback
			end,
			dsp = setmetatable({ window = namespace }, getmetatable(namespace)),
		},
		require = function(name)
			if name == "workspace_store" then
				return fake_store
			end
			equal(name, "vars")
			return { mainMod = "SUPER", terminal = "kitty", calc = "calc", fileManager = "files", menu = "menu", color_picker = "picker" }
		end,
	}, { __index = _G })
	assert(loadfile("keybinds.lua", "t", environment))()
	for digit = 0, 9 do
		bindings["SUPER + CTRL + " .. digit]()
		equal(calls[#calls][1], "pop")
		equal(calls[#calls][2], digit)
		assert(bindings["SUPER + " .. digit])
		assert(bindings["SUPER + SHIFT + " .. digit])
	end
	bindings["SUPER + A"]()
	equal(calls[#calls][1], "push")
	bindings["SUPER + D"]()
	equal(calls[#calls][1], "pop")
	equal(calls[#calls][2], nil)
	bindings["SUPER + mouse_down"]()
	equal(calls[#calls][2], 1)
	bindings["SUPER + mouse_up"]()
	equal(calls[#calls][2], -1)
end)

test("capture precedes every push mutation and failed captures use a unique fallback identity", function()
 local s = fixture()
 local original = s.workspaces[1]
 local token = s.raw.push()
 equal(#s.calls, 0)
 equal(s.workspaces[1], original)
 equal(#s.captures, 1)
 equal(s.ipc[1], "workspace-store:begin:" .. token)
 equal(s.raw.result(token), "pending")
 assert(s.raw.valid(token))
 equal(s.raw.complete(token, false), "ok")
 equal(s.raw.result(token), "ok")
 equal(s.ipc[#s.ipc], "workspace-store:end:" .. token)
 equal(original.name, "workspace-store:1000:test-session:" .. token)
 s.timers[1].callback() -- a completed operation's watchdog is harmless
 equal(s.raw.result(token), "ok")
end)

test("pop captures outgoing content before parking and freezes the selected entry", function()
 local s = fixture()
 local selected = s.stored(1000, "A")
 local token = s.raw.pop(0)
 equal(#s.calls, 0)
 equal(s.queue(), "A")
 equal(#s.captures, 1)
 s.stored(1001, "B") -- the selected entry must not drift to a new index
 equal(s.raw.complete(token, true), "ok")
 equal(s.monitor.active_workspace, selected)
 equal(s.queue(), "B,X")
 equal(s.store.entries()[2].name, "workspace-store:1002:test-session:" .. token)
end)

test("empty pop destinations require no screenshot", function()
 local s = fixture()
 s.workspaces[1].windows = 0
 s.stored(1000, "A")
 local token = s.raw.pop()
 equal(s.raw.result(token), "ok")
 equal(#s.captures, 0)
end)

test("concurrent bar/keyboard operations are serialized", function()
 local s = fixture()
 s.stored(1000, "A")
 local token = s.raw.push()
 assert(not s.raw.push())
 assert(not s.raw.pop())
 equal(#s.captures, 1)
 equal(s.raw.complete(token, true), "ok")
end)

for _, change in ipairs({ "source", "source-id-reuse", "windows", "special", "selected", "selected-id-reuse", "selected-monitor", "switch-back" }) do
 test("capture aborts without parking after change to " .. change, function()
  local s = fixture()
  local original = s.workspaces[1]
  local selected = s.stored(1000, "A")
  local token = s.raw.pop()
  if change == "source" then
   s.activate(s.add(2, "other"))
  elseif change == "source-id-reuse" then
   s.activate(s.add(1, "replacement"))
  elseif change == "windows" then
   original.windows = 2
  elseif change == "special" then
   s.monitor.active_special_workspace = { id = -99 }
  elseif change == "selected" then
   s.workspaces[1000] = nil
  elseif change == "selected-id-reuse" then
   s.stored(1000, "replacement")
  elseif change == "selected-monitor" then
   selected.monitor = s.monitors["DP-6"]
  else
   s.events["workspace.active"]() -- switch away and back, same final identity
  end
  assert(not s.raw.valid(token))
  assert(s.raw.complete(token, true):match("^error:"))
  equal(original.id, 1)
  equal(#s.calls, 0)
 end)
end

test("bar operations address their own monitor, without falling back to the focused one", function()
 local s = fixture()
 local other = s.add(4, "other", s.monitors["DP-6"])
 s.monitors["DP-6"].active_workspace = other
 assert(not s.raw.push("unplugged"))
 assert(not s.raw.push("DP-6", 5)) -- source switched before the request arrived
 local token = s.raw.push("DP-6")
 assert(s.raw.valid(token))
 assert(s.captures[1].command:find("'DP%-6' '4'"))
 equal(s.raw.complete(token, true), "ok")
 equal(s.workspaces[1].layout.label, "X")
 equal(s.queue(), "other")
end)

test("reused workspace IDs get different image identities and stale callbacks cannot finish a new request", function()
 local s = fixture()
 assert(s.store.push())
 local first_name = s.store.entries()[1].name
 local first_token = s.captures[1].token
 assert(s.store.pop())
 local token = s.raw.push()
 s.timers[1].callback() -- the previous capture's watchdog cannot abort this one
 equal(s.raw.result(token), "pending")
 equal(s.raw.complete(first_token, true), "unknown")
 equal(s.workspaces[1].layout.label, "X")
 equal(s.raw.complete(token, true), "ok")
 equal(s.store.entries()[1].id, 1000)
 assert(s.store.entries()[1].name ~= first_name)
end)

test("timeouts and config reloads never move workspaces before capture completion", function()
 local s = fixture()
 local token = s.raw.push()
 s.timers[1].callback()
 equal(s.raw.result(token), "error:capture expirée")
 equal(s.raw.complete(token, true), "unknown")
 equal(#s.calls, 0)
 local second = s.raw.push()
 s.reload()
 equal(s.raw.complete(second, true), "unknown")
 equal(s.workspaces[1].id, 1)
end)

test("UI retrieval uses full identity rather than an obsolete queue index", function()
 local s = fixture()
 local selected = s.stored(1001, "B")
 local name = selected.name
 s.stored(1000, "A")
 assert(s.store.pop_entry(name, "eDP-1"))
 equal(s.monitor.active_workspace, selected)
 assert(not s.raw.pop_entry(name, "eDP-1"))
end)

local failures = 0
for _, case in ipairs(tests) do
	local ok, message = pcall(case.callback)
	if ok then
		print("PASS " .. case.name)
	else
		failures = failures + 1
		io.stderr:write("FAIL " .. case.name .. ": " .. tostring(message) .. "\n")
	end
end
print(string.format("%d tests, %d failures", #tests, failures))
os.exit(failures == 0 and 0 or 1)
