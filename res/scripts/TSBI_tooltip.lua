local tt = {}

local ttContainerID = "toolTipContainer"
local function getContainerLayout()
	local containerComp = api.gui.util.getById(ttContainerID)
	return containerComp:getLayout()
end

tt.id = "tsbi.toolTipContainer.toolTip"

function tt.createText(text,tooltip,pos_offset,text2)
	tt.destroy()
	
	local layout = api.gui.layout.BoxLayout.new("VERTICAL")
	if text2 then
		local textView2 = api.gui.comp.TextView.new(text2)
		-- textView2:setName("BuildControlComp::CostsLabel")
		textView2:setId("tsbi.toolTipContainer.toolTip.uglabel")
		layout:addItem(textView2)
	end
	local textView = api.gui.comp.TextView.new(text)
	layout:addItem(textView)
	
	local toolTipComp = api.gui.comp.Component.new("ToolTip")
	toolTipComp:setId(tt.id)  -- style: game-menu
	toolTipComp:setLayout(layout)
	-- toolTipComp:setTransparent(true)  no effect?
	if tooltip then
		toolTipComp:setTooltip(tooltip)
	end
	
	local containerLayout = getContainerLayout()
	local mousePosition = game.gui.getMousePos()
	pos_offset = pos_offset or {x=0,y=0}
	containerLayout:addItem(toolTipComp, api.gui.util.Rect.new(
		mousePosition[1]+pos_offset.x,
		mousePosition[2]+pos_offset.y,
		0,0
	))
end

function tt.getSize()
	local comp = api.gui.util.getById(tt.id)
	if comp then
		return comp:getContentRect()
	end
end

function tt.updatePos(x,y)
	local comp = api.gui.util.getById(tt.id)
	if comp then
		local layout = comp:getParent():getLayout()
		layout:setItemPosition(layout:getIndex(comp), x, y)
	end
end

function tt.destroy(fromCallback)
	if api.gui then
		local elem = api.gui.util.getById(tt.id)
		if elem then
			local containerLayout = getContainerLayout()
			containerLayout:removeItem(elem)
			if not fromCallback then
				elem:destroy()  -- Callback:  Warning: a UI component has destroyed itself during handling an event, this leads to undefined behaviour!
			else
				api.gui.util.destroyLater(elem)
			end
		end
	end
end

function tt.exists()
	return api.gui.util.getById(tt.id)~=nil
end

return tt