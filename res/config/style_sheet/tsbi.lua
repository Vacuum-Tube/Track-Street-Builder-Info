local ssu = require "stylesheetutil"

function data()
    local result = {}
    local a = ssu.makeAdder(result)
	
	a("#tsbi.toolTipContainer.toolTip", {
		backgroundColor = ssu.makeColor(15, 35, 50, 100),
		-- margin = ,
		gravity = { .0, .0 },
		blurRadius = 16,
	})
	
	-- a("#tsbi.toolTipContainer.toolTip TextView", {
		-- backgroundColor = ssu.makeColor(50, 125, 200, 200),
		-- fontSize = 18,
	-- })
	
    return result
end
