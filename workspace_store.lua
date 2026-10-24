local store = {}

local first_store_id = 1000
local store_prefix = "workspace-store:"

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

local function active_slot()
	local monitor = hl.get_active_monitor()
	if not monitor or monitor.active_special_workspace then
		return
	end

	local workspace = monitor.active_workspace
	if workspace and workspace.id and workspace.id >= 1 and workspace.id <= 10 then
		return workspace, monitor
	end
end

-- Derive the queue from live workspaces so a config reload cannot lose it.
function store.entries()
	local entries = {}
	for _, workspace in ipairs(hl.get_workspaces()) do
		local id = workspace.id
		if id and id >= first_store_id and workspace.name == store_prefix .. id and not workspace.is_empty then
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

function store.push()
	local workspace = active_slot()
	if not workspace or workspace.is_empty then
		return false
	end

	local slot, name = workspace.id, workspace.name
	local id = next_id(store.entries())
	if not identify(workspace, id, store_prefix .. id) then
		return false
	end

	if not dispatch(hl.dsp.focus({ workspace = slot })) then
		identify(workspace, slot, name)
		return false
	end
	return true
end

function store.pop(index)
	local current, monitor = active_slot()
	if not current then
		return false
	end

	local entries = store.entries()
	if #entries == 0 then
		return false
	end

	index = index or 0
	local position = index + 1
	if position < 1 or position > #entries or position % 1 ~= 0 then
		position = #entries
	end

	-- Select before parking the current workspace, including for invalid indices.
	local selected = entries[position]
	local selected_id, selected_name = selected.id, selected.name
	local selected_monitor = selected.monitor
	if not selected_monitor then
		return false
	end

	local slot, current_name = current.id, current.name
	local parking_id = next_id(entries)
	local parking_name = current.is_empty and tostring(parking_id) or store_prefix .. parking_id
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
