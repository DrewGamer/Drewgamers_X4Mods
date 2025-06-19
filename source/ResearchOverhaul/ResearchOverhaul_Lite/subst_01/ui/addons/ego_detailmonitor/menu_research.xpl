﻿-- param == { 0, 0 }

-- ffi setup
local ffi = require("ffi")
local C = ffi.C
ffi.cdef[[
	uint32_t GetAmountOfWareAvailable(const char* wareid, UniverseID productionmoduleid);
	uint32_t GetHQs(UniverseID* result, uint32_t resultlen, const char* factionid);
	uint32_t GetNumHQs(const char* factionid);
	uint32_t GetNumResearchModules(UniverseID containerid);
	uint32_t GetNumWares(const char* tags, bool research, const char* licenceownerid, const char* exclusiontags);
	uint32_t GetResearchModules(UniverseID* result, uint32_t resultlen, UniverseID containerid);
	uint32_t GetWares(const char** result, uint32_t resultlen, const char* tags, bool research, const char* licenceownerid, const char* exclusiontags);
	bool HasResearched(const char* wareid);
	void StartResearch(const char* wareid, UniverseID researchmoduleid);
]]

-- menu variable - used by Helper and used for dynamic variables (e.g. inventory content, etc.)
local menu = {
	name = "ResearchMenu",
	maxnumresources = 7,
	activeresearch = {},
	techtree = {}
}

-- config variable - put all static setup here
local config = {
	mainFrameLayer = 5,
	expandedMenuFrameLayer = 4,
	nodeoffsetx = 30,
	nodewidth = 270,
}

-- init menu and register with Helper
local function init()
	Menus = Menus or { }
	table.insert(Menus, menu)
	if Helper then
		Helper.registerMenu(menu)
	end
end

-- cleanup variables in menu, no need for the menu variable to keep all the data while the menu is not active
function menu.cleanup()
	unregisterForEvent("inputModeChanged", getElement("Scene.UIContract"), menu.onInputModeChanged)
	menu.topLevelOffsetY = nil

	menu.techtree = {}
	menu.researchmodules = nil
	menu.availableresearchmodule = nil
	menu.currentResearch = {}

	menu.checkResearch = nil
	menu.restoreNode = nil
	menu.restoreNodeTech = nil

	menu.flowchartRows = nil
	menu.flowchartCols = nil

	menu.expandedNode = nil
	menu.expandedMenuFrame = nil
	menu.expandedMenuTable = nil

	menu.topRows = {}
	menu.firstCols = {}
	menu.selectedRows = {}
	menu.selectedCols = {}

	menu.frame = nil
end

-- Menu member functions

function menu.onShowMenu()
	Helper.setTabScrollCallback(menu, menu.onTabScroll)
	registerForEvent("inputModeChanged", getElement("Scene.UIContract"), menu.onInputModeChanged)

	menu.topRows = {}
	menu.firstCols = {}
	menu.selectedRows = {}
	menu.selectedCols = {}

	local stationhqlist = {}
	Helper.ffiVLA(stationhqlist, "UniverseID", C.GetNumHQs, C.GetHQs, "player")

	menu.researchmodules = {}
	for i = 1, #stationhqlist do
		Helper.ffiVLA(menu.researchmodules, "UniverseID", C.GetNumResearchModules, C.GetResearchModules, stationhqlist[i])
	end
	menu.availableresearchmodule = nil

	if #menu.techtree == 0 then
		-- Get all research wares from the WareDB.
		local numtechs = C.GetNumWares("", true, "", "hidden")
		local rawtechlist = ffi.new("const char*[?]", numtechs)
		local temptechlist = {}
		numtechs = C.GetWares(rawtechlist, numtechs, "", true, "", "hidden")
		for i = 0, numtechs - 1 do
			table.insert(temptechlist, ffi.string(rawtechlist[i]))
		end
		-- NB: don't really need to sort at this point, but will help the entries in the menu stay consistent.
		table.sort(temptechlist, Helper.sortWareSortOrder)

		-- print("searching for wares without precursor")
		for i = #temptechlist, 1, -1 do
			local techprecursors, sortorder = GetWareData(temptechlist[i], "researchprecursors", "sortorder")
			if #techprecursors == 0 then
				-- print("found " .. temptechlist[i])
				local state_completed = C.HasResearched(temptechlist[i])
				table.insert(menu.techtree, { [1] = { [1] = { tech = temptechlist[i], sortorder = sortorder, completed = state_completed } } })
				table.remove(temptechlist, i)
			end
		end

		-- print("\ngoing through remaining wares")
		local loopcounter = 0
		local idx = 1
		while #temptechlist > 0 do
			-- print("looking at: " .. temptechlist[idx])
			local techprecursors, sortorder = GetWareData(temptechlist[idx], "researchprecursors", "sortorder")
			-- print("    #precusors: " .. #techprecursors)
			local precursordata = {}
			local smallestMainIdx, foundPrecusorCol
			-- try to find all precusors in existing data
			for i, precursor in ipairs(techprecursors) do
				local mainIdx, precursorCol = menu.findTech(menu.techtree, precursor)
				-- print("    precusor " .. precursor .. ": " .. tostring(mainIdx) .. ", " .. tostring(precursorCol))
				if mainIdx and ((not smallestMainIdx) or (smallestMainIdx > mainIdx)) then
					smallestMainIdx = mainIdx
					foundPrecusorCol = precursorCol
				end
				precursordata[i] = { mainIdx = mainIdx, precursorCol = precursorCol }
			end
			-- sort so that highest index comes first - important for deletion order and keeping smallestMainIdx valid
			table.sort(precursordata, menu.precursorSorter)

			if smallestMainIdx then
				-- print("    smallestMainIdx: " .. smallestMainIdx .. ", foundPrecusorCol: " .. foundPrecusorCol)
				-- fix wares without precursors that there wrongly placed in different main entries
				for i, entry in ipairs(precursordata) do
					if entry.mainIdx and (entry.mainIdx ~= smallestMainIdx) then
						-- print("    precusor " .. techprecursors[i] .. " @ " .. entry.mainIdx .. " ... merging")
						for col, columndata in ipairs(menu.techtree[entry.mainIdx]) do
							for techidx, techentry in ipairs(columndata) do
								-- print("    adding menu.techtree[" .. entry.mainIdx .. "][" .. col .. "][" .. techidx .. "] to menu.techtree[" .. smallestMainIdx .. "][" .. col .. "]")
								table.insert(menu.techtree[smallestMainIdx][col], techentry)
							end
						end
						-- print("    removing mainIdx " .. entry.mainIdx)
						table.remove(menu.techtree, entry.mainIdx)
					end
				end

				-- add this tech to the tree and remove it from the list
				local state_completed = C.HasResearched(temptechlist[idx])
				if menu.techtree[smallestMainIdx][foundPrecusorCol + 1] then
					-- print("    adding")
					table.insert(menu.techtree[smallestMainIdx][foundPrecusorCol + 1], { tech = temptechlist[idx], sortorder = sortorder, completed = state_completed })
				else
					-- print("    new entry")
					menu.techtree[smallestMainIdx][foundPrecusorCol + 1] = { [1] = { tech = temptechlist[idx], sortorder = sortorder, completed = state_completed } }
				end
				-- print("    removed")
				table.remove(temptechlist, idx)
			end

			if idx >= #temptechlist then
				loopcounter = loopcounter + 1
				idx = 1
			else
				idx = idx + 1
			end
			if loopcounter > 100 then
				DebugError("Infinite loop detected - aborting.")
				break
			end
		end
	end

	menu.flowchartRows = 0
	menu.flowchartCols = 0
	local lastsortorder = 0
	for i, mainentry in ipairs(menu.techtree) do
		if (menu.flowchartRows ~= 0) and (math.floor(mainentry[1][1].sortorder / 100) ~= math.floor(lastsortorder / 100)) then
			menu.flowchartRows = menu.flowchartRows + 1
		end
		lastsortorder = mainentry[1][1].sortorder

		menu.flowchartCols = math.max(menu.flowchartCols, #mainentry)
		local maxRows = 0
		for col, columnentry in ipairs(mainentry) do
			maxRows = math.max(maxRows, #columnentry)
			table.sort(columnentry, menu.sortTechName)
		end

		menu.flowchartRows = menu.flowchartRows + maxRows
	end

	menu.display()
end

function menu.display()
	-- remove old data
	Helper.clearDataForRefresh(menu)

	-- Organize Visual Menu
	local width = Helper.viewWidth
	local height = Helper.viewHeight
	local xoffset = 0
	local yoffset = 0

	local numcategories = 0

	menu.frame = Helper.createFrameHandle(menu, { height = height, width = width, x = xoffset, y = yoffset, backgroundID = "solid", backgroundColor = Helper.color.semitransparent, layer = config.mainFrameLayer })

	menu.createTopLevel(menu.frame)

	width = width - 2 * Helper.frameBorder
	xoffset = xoffset + Helper.frameBorder

	-- HACK: Disabling the top level tab table as interactive object
	local table_data = menu.frame:addTable( 1, { tabOrder = 1, highlightMode = "column", width = width, x = xoffset, y = menu.topLevelOffsetY + Helper.borderSize } )

	menu.flowchart = menu.frame:addFlowchart(menu.flowchartRows, menu.flowchartCols, { borderHeight = 3, borderColor = Helper.defaultSimpleBackgroundColor, minRowHeight = 45, minColWidth = 80, x = Helper.frameBorder, y = menu.topLevelOffsetY + Helper.borderSize, width = width, edgeWidth = 1 })
	menu.flowchart:setDefaultNodeProperties({
		expandedFrameLayer = config.expandedMenuFrameLayer,
		expandedTableNumColumns = 2,
		x = config.nodeoffsetx,
		width = config.nodewidth,
	})
	for col = 2, menu.flowchartCols, 2 do
		menu.flowchart:setColBackgroundColor(col, Helper.defaultSimpleBackgroundColor)
	end

	-- update current research and available research module
	menu.currentResearch = {}
	for _, module in ipairs(menu.researchmodules) do
		local proddata = GetProductionModuleData(ConvertStringTo64Bit(tostring(module)))
		if proddata.state == "empty" then
			if not menu.availableresearchmodule then
				menu.availableresearchmodule = module
			end
		elseif proddata.state == "producing" then
			menu.currentResearch[proddata.blueprintware] = module
		end
	end

	-- update research status of given tech if any
	if menu.checkResearch then
		local mainIdx, col, techIdx = menu.findTech(menu.techtree, menu.checkResearch)
		menu.techtree[mainIdx][col][techIdx].completed = C.HasResearched(menu.checkResearch)
		menu.checkResearch = nil
	end

	local rowCounter = 1
	local lastsortorder = 0
	for i, mainentry in ipairs(menu.techtree) do
		if (rowCounter ~= 1) and (math.floor(mainentry[1][1].sortorder / 100) ~= math.floor(lastsortorder / 100)) then
			rowCounter = rowCounter + 1
		end
		lastsortorder = mainentry[1][1].sortorder

		local maxRows = 0
		for col, columnentry in ipairs(mainentry) do
			maxRows = math.max(maxRows, #columnentry)
			for j, techentry in ipairs(columnentry) do
				local value, max = 0, 100
				local statusText
				if techentry.completed then
					value = 100
				elseif menu.currentResearch[techentry.tech] then
					local proddata = GetProductionModuleData(ConvertStringTo64Bit(tostring(menu.currentResearch[techentry.tech])))
					value = function() return Helper.round(math.max(1, menu.currentResearch[techentry.tech] and (GetProductionModuleData(ConvertStringTo64Bit(tostring(menu.currentResearch[techentry.tech]))).cycleprogress or 0) or 100)) end
					statusText = function() return Helper.round(math.max(1, menu.currentResearch[techentry.tech] and (GetProductionModuleData(ConvertStringTo64Bit(tostring(menu.currentResearch[techentry.tech]))).cycleprogress or 0) or 100)) .. " %" end
				end
				local color
				if (not techentry.completed) and (not menu.currentResearch[techentry.tech]) and (not menu.isResearchAvailable(techentry.tech, i, col)) then
					color = Helper.color.grey
				end
				techentry.node = menu.flowchart:addNode(rowCounter + j - 1, col, { data = { mainIdx = i, col = col, techdata = techentry }, expandHandler = menu.expandNode }, { shape = "stadium", value = value, max = max }):setText(GetWareData(techentry.tech, "name")):setStatusText(statusText)
				techentry.node.properties.outlineColor = color
				techentry.node.properties.text.color = color
				techentry.node.properties.statustext.color = color

				techentry.node.handlers.onExpanded = menu.onFlowchartNodeExpanded
				techentry.node.handlers.onCollapsed = menu.onFlowchartNodeCollapsed

				if menu.restoreNodeTech and menu.restoreNodeTech == techentry.tech then
					menu.restoreNode = techentry.node
					menu.restoreNodeTech = nil
				end

				if col > 1 then
					for k, previousentry in ipairs(mainentry[col - 1]) do
						-- print("adding edge from node " .. previousentry.tech .. " to " .. techentry.tech)
						local edge = previousentry.node:addEdgeTo(techentry.node)
						if not previousentry.completed then
							edge.properties.sourceSlotColor = Helper.color.grey
							edge.properties.color = Helper.color.grey
						end
						edge.properties.destSlotColor = color
					end
				end
			end
		end

		local skiprow = false
		if math.floor(mainentry[1][1].sortorder / 100) ~= math.floor(lastsortorder / 100) then
			lastsortorder = mainentry[1][1].sortorder
			skiprow = true
		end

		rowCounter = rowCounter + maxRows
	end

	menu.restoreFlowchartState("flowchart", menu.flowchart)

	-- display view/frame
	menu.frame:display()
end

function menu.onFlowchartNodeExpanded(node, frame, ftable)
	node.flowchart:collapseAllNodes()
	local data = node.customdata
	local expandHandler = data.expandHandler
	if expandHandler then
		expandHandler(ftable, data.data)
		menu.expandedNode = node
		menu.expandedMenuFrame = frame
		menu.expandedMenuTable = ftable
	end
end

function menu.expandNode(ftable, data)
	AddUITriggeredEvent(menu.name, "research_selected", data.techdata.tech)
	local description, researchtime, resources = GetWareData(data.techdata.tech, "description", "researchtime", "resources")

	-- description
	local row = ftable:addRow(nil, { fixed = true, bgColor = Helper.color.transparent })
	row[1]:setColSpan(2):createText(description .. "\n ", { wordwrap = true })
	if menu.currentResearch[data.techdata.tech] then
		-- remaining time
		local row = ftable:addRow(nil, { fixed = true, bgColor = Helper.color.transparent })
		row[1]:setColSpan(2):createText(ReadText(1001, 7409))
		local row = ftable:addRow(nil, { fixed = true, bgColor = Helper.color.transparent })
		row[1]:setColSpan(2):createText(function () return ConvertTimeString(menu.currentResearch[data.techdata.tech] and (GetProductionModuleData(ConvertStringTo64Bit(tostring(menu.currentResearch[data.techdata.tech]))).remainingcycletime or 0) or 0) end, { halign = "right" })
	elseif data.techdata.completed then
		-- completed
		local row = ftable:addRow(nil, { fixed = true, bgColor = Helper.color.transparent })
		row[1]:setColSpan(2):createText(ReadText(1001, 7408))
	else
		-- research time
		local row = ftable:addRow(nil, { fixed = true, bgColor = Helper.color.transparent })
		row[1]:setColSpan(2):createText(ReadText(1001, 7406))
		local row = ftable:addRow(nil, { fixed = true, bgColor = Helper.color.transparent })
		row[1]:setColSpan(2):createText(ConvertTimeString(researchtime), { halign = "right" })

		-- needed resources
		if resources then 
			local row = ftable:addRow(nil, { fixed = true, bgColor = Helper.color.transparent })
			row[1]:setColSpan(2):createText(ReadText(1001, 7403))
		
			for _, resourcedata in ipairs(resources) do
				local row = ftable:addRow(nil, { fixed = true, bgColor = Helper.color.transparent })
				local locamount = C.GetAmountOfWareAvailable(resourcedata.ware, menu.availableresearchmodule)
				local resourcecolor = Helper.color.white

				if locamount < resourcedata.amount then
					resourcecolor = Helper.color.red
				end

				row[1]:setColSpan(2):createText("(" .. locamount .. "/" .. resourcedata.amount .. ") " .. GetWareData(resourcedata.ware, "name"), { halign = "right", color = resourcecolor })
				
			end
		end

		-- start button
		local row = ftable:addRow(true, { fixed = true, bgColor = Helper.color.transparent })
		local isavailable = menu.isResearchAvailable(data.techdata.tech, data.mainIdx, data.col)
		local mouseovertext = ""
		if not isavailable then
			if menu.availableresearchmodule then
				mouseovertext = "\27R" .. ReadText(1026, 7410)
			else
				mouseovertext = "\27R" .. ReadText(1026, 7401)
			end
		end

		row[1]:setColSpan(2):createButton({ active = isavailable, mouseOverText = mouseovertext }):setText(ReadText(1001, 7407))
		row[1].handlers.onClick = function () return menu.buttonStartResearch(data.techdata) end
		row[1].properties.uiTriggerID = data.techdata.tech
	end

	menu.restoreTableState("nodeTable", ftable)
end

function menu.onFlowchartNodeCollapsed(node, frame)
	if menu.expandedNode == node and menu.expandedMenuFrame == frame then
		local data = node.customdata
		local collapseHandler = data.collapseHandler
		if collapseHandler then
			collapseHandler(data)
		end
		Helper.clearFrame(menu, config.expandedMenuFrameLayer)
		menu.expandedMenuTable = nil
		menu.expandedMenuFrame = nil
		menu.expandedNode = nil
	end
end

function menu.createTopLevel(frame)
	menu.topLevelOffsetY = Helper.createTopLevelTab(menu, "research", frame, "", nil, true)
end

function menu.onTabScroll(direction)
	if direction == "right" then
		Helper.scrollTopLevel(menu, "research", 1)
	elseif direction == "left" then
		Helper.scrollTopLevel(menu, "research", -1)
	end
end

function menu.onInputModeChanged(_, mode)
	menu.display()
end

-- widget scripts

function menu.buttonStartResearch(techdata)
	if menu.availableresearchmodule then
		local resources = GetWareData(techdata.tech, "resources")
		for _, resourcedata in ipairs(resources) do
			local locamount = C.GetAmountOfWareAvailable(resourcedata.ware, menu.availableresearchmodule)
			if locamount < resourcedata.amount then
				return
			end
		end
		
		menu.currentResearch[techdata.tech] = menu.availableresearchmodule
		C.StartResearch(techdata.tech, menu.availableresearchmodule)
		menu.availableresearchmodule = nil

		menu.restoreNodeTech = techdata.tech
		menu.updateExpandedNode()
		menu.refresh = getElapsedTime()
	end
end

menu.updateInterval = 0.1

-- hook to update the menu while it is being displayed
function menu.onUpdate()
	local curtime = getElapsedTime()
	if next(menu.currentResearch) then
		for tech, module in pairs(menu.currentResearch) do
			local proddata = GetProductionModuleData(ConvertStringTo64Bit(tostring(module)))
			if proddata.state == "empty" then
				menu.currentResearch[tech] = nil
				menu.restoreNodeTech = tech
				menu.checkResearch = tech
				menu.refresh = curtime + 2.0
			end
		end
	end

	if menu.refresh and (menu.refresh <= curtime) then
		menu.refresh = nil
		menu.saveFlowchartState("flowchart", menu.flowchart)
		if menu.expandedNode then
			menu.expandedNode:collapse()
		end
		menu.display()
		return
	end

	if menu.restoreNode and menu.restoreNode.id then
		menu.restoreNode:expand()
		menu.restoreNode = nil
	end

	-- 1 second updates are enough for frame content
	if (not menu.frameUpdateTimer) or (menu.frameUpdateTimer < curtime) then
		menu.frameUpdateTimer = curtime + 1
		menu.frame:update()
		if menu.expandedMenuFrame then
			menu.expandedMenuFrame:update()
		end
	end
end

function menu.onColChanged(row, col)
end

-- hook if the highlighted row is selected
function menu.onSelectElement(table, modified)
end

-- hook if the menu is being closed
function menu.onCloseElement(dueToClose)
	Helper.closeMenu(menu, dueToClose)
	menu.cleanup()
end

function menu.findTech(ftable, tech)
	for i, mainentry in ipairs(menu.techtree) do
		for col, columnentry in ipairs(mainentry) do
			for j, techentry in ipairs(columnentry) do
				if techentry.tech == tech then
					return i, col, j
				end
			end
		end
	end
end

function menu.precursorSorter(a, b)
	local aIdx = a.mainIdx or 0
	local bIdx = b.mainIdx or 0
	return aIdx > bIdx
end

function menu.isResearchAvailable(tech, mainIdx, col)
	if menu.availableresearchmodule then
		if col > 1 then
			for _, techentry in ipairs(menu.techtree[mainIdx][col - 1]) do
				if not techentry.completed then
					return false
				end
			end
		end
		local resources = GetWareData(tech, "resources")
		for _, resourcedata in ipairs(resources) do
			local locamount = C.GetAmountOfWareAvailable(resourcedata.ware, menu.availableresearchmodule)
			if locamount < resourcedata.amount then
				return false
			end
		end
		return true
	end
	return false
end

function menu.sortTechName(a, b)
	local aname = GetWareData(a.tech, "name")
	local bname = GetWareData(b.tech, "name")

	return aname < bname
end

function menu.updateExpandedNode()
	local node = menu.expandedNode
	node:collapse()
	node:expand()
end

-- helpers to maintain row/column states while frame is re-created
function menu.saveFlowchartState(name, flowchart)
	menu.topRows[name], menu.firstCols[name] = GetFlowchartFirstVisibleCell(flowchart.id)
	menu.selectedRows[name], menu.selectedCols[name] = GetFlowchartSelectedCell(flowchart.id)
end

function menu.restoreFlowchartState(name, flowchart)
	flowchart.properties.firstVisibleRow = menu.topRows[name] or 1
	flowchart.properties.firstVisibleCol = menu.firstCols[name] or 1
	menu.topRows[name] = nil
	menu.firstCols[name] = nil
	flowchart.properties.selectedRow = menu.selectedRows[name] or 1
	flowchart.properties.selectedCol = menu.selectedCols[name] or 1
	menu.selectedRows[name] = nil
	menu.selectedCols[name] = nil
end

function menu.saveTableState(name, ftable, row, col)
	menu.topRows[name] = GetTopRow(ftable.id)
	menu.selectedRows[name] = row or Helper.currentTableRow[ftable.id]
	menu.selectedCols[name] = col or Helper.currentTableCol[ftable.id]
end

function menu.restoreTableState(name, ftable)
	ftable:setTopRow(menu.topRows[name])
	ftable:setSelectedRow(menu.selectedRows[name])
	ftable:setSelectedCol(menu.selectedCols[name] or 0)

	menu.topRows[name] = nil
	menu.selectedRows[name] = nil
	menu.selectedCols[name] = nil
end

init()
