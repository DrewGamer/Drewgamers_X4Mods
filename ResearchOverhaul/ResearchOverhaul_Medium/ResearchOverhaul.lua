-- ffi setup, we need this since we are using C
local ffi = require("ffi")
local C = ffi.C

-- setup local variabls
local orig = {}
local addRequiredResearchWares = {}

local function init()
    --DebugError("Research Overhaul mod init")
    for _, menu in ipairs(Menus) do
        if menu.name == "ResearchMenu" then
            -- save entire menu, for other helper function access
            orig.menu = menu
            -- save original function
            orig.expandNode = menu.expandNode
            -- replace original functions with modded functions
            menu.expandNode = addRequiredResearchWares.expandNode
            break
        end
    end
end

function addRequiredResearchWares.expandNode(ftable, data)
    -- we do stuff here
    AddUITriggeredEvent(orig.menu.name, "research_selected", data.techdata.tech)
    -- NEW FROM MOD: added "resources" as a local
	local description, researchtime, resources = GetWareData(data.techdata.tech, "description", "researchtime", "resources")

	-- description
	local row = ftable:addRow(nil, { fixed = true, bgColor = Helper.color.transparent })
	row[1]:setColSpan(2):createText(description .. "\n ", { wordwrap = true })
	if orig.menu.currentResearch[data.techdata.tech] then
		-- remaining time
		local row = ftable:addRow(nil, { fixed = true, bgColor = Helper.color.transparent })
		row[1]:setColSpan(2):createText(ReadText(1001, 7409))
		local row = ftable:addRow(nil, { fixed = true, bgColor = Helper.color.transparent })
		row[1]:setColSpan(2):createText(function () return ConvertTimeString(orig.menu.currentResearch[data.techdata.tech] and (GetProductionModuleData(ConvertStringTo64Bit(tostring(menu.currentResearch[data.techdata.tech]))).remainingcycletime or 0) or 0) end, { halign = "right" })
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

		-- NEW FROM MOD: here we add the display for needed resources
		if resources then 
			local row = ftable:addRow(nil, { fixed = true, bgColor = Helper.color.transparent })
			row[1]:setColSpan(2):createText(ReadText(1001, 7403))
		
			for _, resourcedata in ipairs(resources) do
				local row = ftable:addRow(nil, { fixed = true, bgColor = Helper.color.transparent })
				local locamount = C.GetAmountOfWareAvailable(resourcedata.ware, orig.menu.availableresearchmodule)
				local resourcecolor = Helper.color.white

				if locamount < resourcedata.amount then
					resourcecolor = Helper.color.red
				end

				row[1]:setColSpan(2):createText("(" .. locamount .. "/" .. resourcedata.amount .. ") " .. GetWareData(resourcedata.ware, "name"), { halign = "right", color = resourcecolor })
				
			end
		end

		-- start button
		local row = ftable:addRow(true, { fixed = true, bgColor = Helper.color.transparent })
		local isavailable = orig.menu.isResearchAvailable(data.techdata.tech, data.mainIdx, data.col)
		local mouseovertext = ""
		if not isavailable then
            if orig.menu.availableresearchmodule then
                -- NEW FROM MOD: changed text from 7402 to 7410 to account for missing resources
				mouseovertext = "\27R" .. ReadText(1026, 7410)
			else
				mouseovertext = "\27R" .. ReadText(1026, 7401)
			end
		end

		row[1]:setColSpan(2):createButton({ active = isavailable, mouseOverText = mouseovertext }):setText(ReadText(1001, 7407))
		row[1].handlers.onClick = function () return orig.menu.buttonStartResearch(data.techdata) end
		row[1].properties.uiTriggerID = data.techdata.tech
	end

	orig.menu.restoreTableState("nodeTable", ftable)
	-- we call the original function (do we really want to do this?!)
	-- orig.expandNode()
end


init()