local u = {}

function u.tableadd(tab,add)
	if #tab==#add then
		for i = 1,#add do
			tab[i] = tab[i] + add[i]
		end
	else
		error("table size dont match: "..tostring(#tab).."/"..tostring(#add))
	end
end

function u.add(tab, field, val)  -- not kidding, why dont you have += or ++ , LUA?
	tab[field] = tab[field] + val
end



function u.newList()
	return {
		sum = 0,
		max = -math.huge,
		min = math.huge,
	}
end

function u.newVal(List, val)
	u.addsum(List, val)
	u.setmax(List, val)
	u.setmin(List, val)
end

function u.addsum(List,add)
	List.sum = List.sum + add
end

function u.setmax(List,val)
	if val>List.max then
		List.max = val
	end
end

function u.setmin(List,val)
	if val<List.min then
		List.min = val
	end
end


u.mtList = {
	__add = function(sum,val)
		-- if type(val)=="table" then
			u.tableadd(sum,val)  -- WARNING tableadd writes sum
		-- else
			-- return List.sum + val
		-- end
	end,
	__div = function(sum,val)
		local div = {}
		for i,s in pairs(sum) do
			div[i] = s/val
		end
		return div
	end,
}

local ValueList = {}
u.ValueList = ValueList
ValueList.__index = ValueList
function ValueList:new()
	--self.__index = self
	local o = u.newList()
	setmetatable(o, self)
	return o
end
function ValueList:newVal(val)
	u.newVal(self, val)
end

return u