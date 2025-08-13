
local id_pref = "BuildControlComp::CostsLabel_UG_ID_"
local id_pref_bb = "BuildControlComp::BuildButton_UG_ID_"

local u = {
	ids = {}
}

function u.isInit(guiid)
	return u.ids[guiid]~=nil
end

function u.initLabel(guiid)
	local e = {
		id = id_pref..guiid,
		bbid = id_pref_bb..guiid,
	}
	local mainView = assert(api.gui.util.getById("mainView"), "No mainView")
	local buildControlComp = mainView:getLayout():getItem(1):getLayout():getItem(0)
	if buildControlComp and buildControlComp:getName()=="BuildControlComp" then
		local bLayout = assert(buildControlComp:getLayout():getItem(1), "No buildControlComp Item1")
		local found
		for i=0,bLayout:getNumItems()-1 do
			local item = bLayout:getItem(i)
			if item:getName()=="BuildControlComp::CostsLabel" then
				item:setId(e.id)
				-- item:onDestroy(function(a) print("DESTROY "..guiid) print(a) end)
				found = true
			elseif item:getName()=="BuildControlComp::BuildButton" then
				item:setId(e.bbid)
			end
		end
		if found then
			u.ids[guiid] = e
			-- print("INIT "..guiid)
		else
			print("ERROR: Track/Street Builder Info: No BuildControlComp::CostsLabel")
		end
	else
		print("ERROR: Track/Street Builder Info: No BuildControlComp")
	end
end

function u.getComp(guiid)
	if u.isInit(guiid) then
		return api.gui.util.getById(u.ids[guiid].id)
	end
end

function u.getBBComp(guiid)
	if u.isInit(guiid) then
		return api.gui.util.getById(u.ids[guiid].bbid)
	end
end

function u.getText(guiid)
	local c = u.getComp(guiid)
	if c then 
		return c:getText()
	end 
end

function u.getPos(guiid)
	local c = u.getComp(guiid)
	if c then 
		return c:getContentRect()
	end
end

function u.getBBPos(guiid)
	local c = u.getBBComp(guiid)
	if c then 
		return c:getContentRect()
	end
end

function u.hide(bool, guiid)
	if not guiid then
		 for id,_ in pairs(u.ids) do
			u.hide(bool, id)
		end
	end
	local c = u.getComp(guiid)
	if c then 
		if bool then 
			c:setMaximumSize(api.gui.util.Size.new(0,0))
		else
			c:setMaximumSize(api.gui.util.Size.new(400,400))
		end
	end 
end

function u.onEvent(guiid, func)
	u.ids[guiid].fnOnEvent = func
end

function u.onVisFalse(guiid, func)
	u.ids[guiid].fnOnEvent = function(name, param)
		if name=="visibilityChange" and param==false then
			func()
		end
	end
end

function u.guiHandleEvent(id, name, param)
	for guiid,e in pairs(u.ids) do
		if id==e.id and e.fnOnEvent then
			 e.fnOnEvent(name, param)
		end
	end
end

-- function u.isVisible()
	-- local c = u.getComp()
	-- if c then 
		-- return c:isVisible()  does not work
	-- end
-- end

-- function u.isonUI()
	-- local c = u.getComp()
	-- if c then
		-- local p = c:getParent()
		-- if p then 
			-- local p2 = p:getParent()
			-- if p2 then
				-- return true
			-- end
		-- end
	-- end
	-- return false
-- end

-- function u.setTooltip(tt)  -- does not work
	-- local c = u.getComp()
	-- if c then 
		-- c:setTooltip(tt)
	-- end
-- end

return u