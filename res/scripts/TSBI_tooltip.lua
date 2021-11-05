local tt = {}

tt.createText = function(text,tooltip)
	local containerComp = api.gui.util.getById("toolTipContainer")
	local containerLayout = containerComp:getLayout()
	containerLayout:deleteAll()
	
	local textView = api.gui.comp.TextView.new(text)
	textView:setId("toolTipContainer.toolTip.text")
	
	local layout = api.gui.layout.BoxLayout.new("VERTICAL")
	layout:setId("toolTipContainer.toolTip.layout")
	layout:addItem(textView)
	
	toolTipComp = api.gui.comp.Component.new("ToolTip")
	toolTipComp:setId("toolTipContainer.toolTip")
	toolTipComp:setLayout(layout)
	toolTipComp:setTransparent(true)
	if tooltip then
		toolTipComp:setTooltip(tooltip)
	end
	containerLayout:addItem(toolTipComp, api.gui.util.Rect.new())
	
	local mousePosition = game.gui.getMousePos()
	containerLayout:setPosition(0, mousePosition[1], mousePosition[2])
end

tt.destroy = function()
	if api.gui then
		local containerComp = api.gui.util.getById("toolTipContainer")
		local containerLayout = containerComp:getLayout()
		containerLayout:deleteAll()
	end
end

return tt