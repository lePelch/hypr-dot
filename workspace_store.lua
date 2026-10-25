local store = {}

local first_store_id = 1000
local store_prefix = "workspace-store:"
local session = os.getenv("HYPRLAND_INSTANCE_SIGNATURE") or ""
local config_home = os.getenv("XDG_CONFIG_HOME")
if not config_home or config_home == "" then config_home = (os.getenv("HOME") or "") .. "/.config" end
local capture_helper = config_home .. "/ags/scripts/workspace_store.py"
local pending
local results, result_order = {}, {}

local function notify(message)
	hl.notification.create({ text = "Workspace store: " .. message, timeout = 5000 })
end

local function emit(phase, token)
	-- Shared AGS IPC lets keyboard captures close any open preview popover too.
	hl.dispatch(hl.dsp.event("workspace-store:" .. phase .. ":" .. token))
end

local function dispatch(action)
	local result = hl.dispatch(action)
	if result and result.ok then
		return true
	end

	hl.notification.create({
		text = "Workspace store: " .. (result and result.error or "dispatcher failed"),
		timeout = 5000,
	})
	return false
end

local function active_slot(monitor_name)
	local monitor
	if monitor_name then
		monitor = hl.get_monitor(monitor_name)
	else
		monitor = hl.get_active_monitor()
	end
	if not monitor or monitor.active_special_workspace then
		return
	end

	local workspace = monitor.active_workspace
	if workspace and workspace.id and workspace.id >= 1 and workspace.id <= 10 then
		return workspace, monitor
	end
end

local function entry_name(workspace)
	local id = workspace.id
	if not id or id < first_store_id then return false end
	if workspace.name == store_prefix .. id then return true end -- pre-thumbnail entries
	local stored_id, stored_session, token = workspace.name:match("^workspace%-store:(%d+):([%w_-]+):(%x+)$")
	return tonumber(stored_id) == id and stored_session ~= nil and token ~= nil and #token == 32
end

-- Derive the queue from live workspaces so a config reload cannot lose it.
function store.entries()
	local entries = {}
	for _, workspace in ipairs(hl.get_workspaces()) do
		if entry_name(workspace) and not workspace.is_empty then
			table.insert(entries, workspace)
		end
	end
	table.sort(entries, function(a, b)
		return a.id < b.id
	end)
	return entries
end

local function next_id(entries)
	local id = first_store_id
	for _, workspace in ipairs(entries) do
		id = math.max(id, workspace.id + 1)
	end
	while hl.get_workspace(id) do
		id = id + 1
	end
	return id
end

local function identify(workspace, id, name)
	local old_id, old_name = workspace.id, workspace.name
	if not dispatch(hl.dsp.workspace.change_id({ workspace = workspace, id = id })) then
		return false
	end
	if not dispatch(hl.dsp.workspace.rename({ workspace = workspace, name = name })) then
		dispatch(hl.dsp.workspace.change_id({ workspace = workspace, id = old_id }))
		dispatch(hl.dsp.workspace.rename({ workspace = workspace, name = old_name }))
		return false
	end
	return true
end

local function commit_push(request)
	local workspace = request.current
	local slot, name = workspace.id, workspace.name
	local id = next_id(store.entries())
	if not identify(workspace, id, store_prefix .. id .. ":" .. session .. ":" .. request.token) then
		return false
	end

	if not dispatch(hl.dsp.focus({ workspace = slot })) then
		identify(workspace, slot, name)
		return false
	end
	return true
end

local function commit_pop(request)
	local current, monitor, selected = request.current, request.monitor, request.selected
	local entries = store.entries()
	local selected_id, selected_name = selected.id, selected.name
	local selected_monitor = selected.monitor
	if not selected_monitor then
		return false
	end

	local slot, current_name = current.id, current.name
	local parking_id = next_id(entries)
	local parking_name = current.is_empty and tostring(parking_id)
		or (store_prefix .. parking_id .. ":" .. session .. ":" .. request.token)
	-- Even an empty destination occupies its ID: park it without enqueuing it.
	if not identify(current, parking_id, parking_name) then
		return false
	end

	local function rollback()
		if selected.id == slot then
			identify(selected, selected_id, selected_name)
		end
		if selected.monitor and selected.monitor.name ~= selected_monitor.name then
			dispatch(hl.dsp.workspace.move({ workspace = selected, monitor = selected_monitor }))
		end
		identify(current, slot, current_name)
		dispatch(hl.dsp.focus({ workspace = slot }))
	end

	if not identify(selected, slot, tostring(slot)) then
		rollback()
		return false
	end
	if selected_monitor.name ~= monitor.name then
		if not dispatch(hl.dsp.workspace.move({ workspace = selected, monitor = monitor })) then
			rollback()
			return false
		end
	end
	if not dispatch(hl.dsp.focus({ workspace = slot })) then
		rollback()
		return false
	end
	return true
end

local function fingerprint(workspace)
	local ids = {}
	for _, window in ipairs(workspace:get_windows()) do
		table.insert(ids, tostring(window.stable_id))
	end
	table.sort(ids)
	return table.concat(ids, ",")
end

local function remember(request, status)
	-- Let the one-shot watchdog expire naturally, so Hyprland releases its Lua
	-- callback instead of retaining a permanently disabled timer per capture.
	results[request.token] = status
	table.insert(result_order, request.token)
	if #result_order > 64 then results[table.remove(result_order, 1)] = nil end
	if pending == request then pending = nil end
	emit("end", request.token)
	return status
end

function store.result(token)
	if pending and pending.token == token then return "pending" end
	return results[token] or "unknown"
end

function store.cancel(token)
	if not pending or pending.token ~= token then return "unknown" end
	return remember(pending, "error:capture annulée")
end

function store.valid(token)
	local request = pending
	if not request or request.token ~= token or request.invalid or request.committing then return false end
	local current, monitor = active_slot(request.monitor.name)
	if current ~= request.current or not monitor or current.id ~= request.slot or current.name ~= request.name then return false end
	if not request.explicit_monitor and hl.get_active_monitor() ~= monitor then return false end
	if fingerprint(current) ~= request.windows then return false end
	if request.selected then
		local selected = hl.get_workspace(request.selected_id)
		if selected ~= request.selected or selected.name ~= request.selected_name or selected.is_empty then return false end
		if not selected.monitor or selected.monitor.name ~= request.selected_monitor then return false end
	end
	return true
end

-- Called only after the helper has finished capturing (successfully or not).
-- Never park first and try to capture a now-hidden workspace afterwards.
function store.complete(token, captured)
	local request = pending
	if not request or request.token ~= token then return "unknown" end
	if not store.valid(token) then
		notify("opération annulée : workspace ou cible modifié pendant la capture")
		return remember(request, "error:workspace ou cible modifié pendant la capture")
	end
	request.committing = true
	local ok
	if request.selected then
		ok = commit_pop(request)
	else
		ok = commit_push(request)
	end
	return remember(request, ok and "ok" or "error:échec du rangement (restauration tentée)")
end

local function shell_quote(value)
	return "'" .. tostring(value):gsub("'", "'\\''") .. "'"
end

local function begin(current, monitor, selected, explicit_monitor)
	if pending then notify("une capture est déjà en cours"); return false end
	if not session:match("^[%w_-]+$") then notify("session Hyprland introuvable"); return false end
	local file = io.open("/proc/sys/kernel/random/uuid", "r")
	if not file then notify("identifiant de capture indisponible"); return false end
	local token = (file:read("*l") or ""):gsub("%-", "")
	file:close()
	if not token:match("^%x+$") or #token ~= 32 then return false end
	local request = {
		token = token, current = current, monitor = monitor, slot = current.id,
		name = current.name, windows = fingerprint(current), selected = selected,
		explicit_monitor = explicit_monitor,
		selected_id = selected and selected.id,
		selected_name = selected and selected.name,
		selected_monitor = selected and selected.monitor and selected.monitor.name,
	}
	pending = request
	-- No outgoing content means no screenshot is necessary for this pop.
	if current.is_empty then store.complete(token, false); return token end
	emit("begin", token)
	hl.timer(function()
		if pending == request then
			notify("capture expirée : aucun workspace déplacé")
			remember(request, "error:capture expirée")
		end
	end, { timeout = 8000, type = "oneshot" })
	local command = { "python3", capture_helper, "capture", session, token, monitor.name, tostring(current.id) }
	for i, value in ipairs(command) do command[i] = shell_quote(value) end
	local ok = pcall(hl.exec_cmd, table.concat(command, " "))
	if not ok then remember(request, "error:impossible de lancer la capture") end
	return token
end

function store.push(monitor_name, expected_slot)
	local current, monitor = active_slot(monitor_name)
	if not current or current.is_empty then return false end
	if expected_slot and current.id ~= expected_slot then return false end
	return begin(current, monitor, nil, monitor_name ~= nil)
end

function store.pop(index, monitor_name, expected_slot)
	local current, monitor = active_slot(monitor_name)
	if not current then return false end
	if expected_slot and current.id ~= expected_slot then return false end
	local entries = store.entries()
	if #entries == 0 then return false end
	index = index or 0
	local position = index + 1
	if position < 1 or position > #entries or position % 1 ~= 0 then position = #entries end
	local selected = entries[position] -- freeze before parking the current workspace
	if not selected.monitor then return false end
	return begin(current, monitor, selected, monitor_name ~= nil)
end

-- The UI selects a full entry identity, never a stale/reindexed queue position.
function store.pop_entry(name, monitor_name, expected_slot)
	for index, workspace in ipairs(store.entries()) do
		if workspace.name == name then return store.pop(index - 1, monitor_name, expected_slot) end
	end
	return false
end

-- Conservatively cancel if the displayed workspace changes during grim,
-- including a switch away and back before the final identity check.
for _, event in ipairs({ "workspace.active", "workspace.special_active", "workspace.move_to_monitor", "window.move_to_workspace", "monitor.layout_changed" }) do
	hl.on(event, function()
		if pending and not pending.committing then pending.invalid = true end
	end)
end

-- Keep the existing-workspace scroll behavior, excluding storage/parking IDs.
function store.cycle(direction)
	local current = active_slot()
	if not current then
		return false
	end

	local workspaces = {}
	for _, workspace in ipairs(hl.get_workspaces()) do
		if workspace.id and workspace.id >= 1 and workspace.id <= 10 then
			table.insert(workspaces, workspace)
		end
	end
	table.sort(workspaces, function(a, b)
		return a.id < b.id
	end)
	for index, workspace in ipairs(workspaces) do
		if workspace.id == current.id then
			local target = workspaces[(index - 1 + direction) % #workspaces + 1]
			if target.id == current.id then
				return true
			end
			return dispatch(hl.dsp.focus({ workspace = target }))
		end
	end
	return false
end

return store
