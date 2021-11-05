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


function u.newCountList(list)
	local clist = {}
	for i,val in pairs(list) do
		clist[val] = 0
	end
	return clist
end


return u