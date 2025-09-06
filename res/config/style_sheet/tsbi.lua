local ssu = require "stylesheetutil"

local hp = 5
local vp = 2

function data()
    local result = {}
    local a = ssu.makeAdder(result)
	
	a("#tsbi.toolTipContainer.toolTip", {
		backgroundColor = ssu.makeColor(15, 35, 50, 100),
		-- margin = ,
		gravity = { 0, 0 },
		blurRadius = 16,
	})
	
	a("#tsbi.toolTipContainer.toolTip.uglabel", {
		-- backgroundColor = ssu.makeColor(50, 125, 200, 200),
		backgroundColor = ssu.makeColor(50, 50, 50, 200),
		fontSize = 18,
		padding = { vp, hp, vp, hp },
		gravity = { -1, 0 },
	})
	
	
	a("!BuildControlComp-CostsLabel-hide", {
		backgroundColor = ssu.makeColor(0, 0, 0, 0)   -- hide vanilla info
	})
	
    return result
end
