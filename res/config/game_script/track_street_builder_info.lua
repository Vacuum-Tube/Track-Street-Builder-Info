local toolTipCont = require "TSBI_tooltip"
local GeomInfo = require "TSBI_getGeomInfo"
local ugCostLabel = require "TSBI_ugCostLabel"


local function linesConcat(tab)  --  table.concat not so flexible with nil...
	local text = ""
	for _,str in pairs(tab) do
		if str then
			text = text .. str .. "\n"
		end
	end
	text = text:gsub("^%s*(.-)%s*$", "%1")  -- trim
	return text
end

local function radiusStr(r)
	return r and math.abs(r)<1e6 and (math.abs(r)<10 and string.format("%.1f m", math.abs(r)) or string.format("%.0f m", math.abs(r))) or "∞"
end

local function radiusDir(r)
	return r and math.abs(r)<1e6 and (r>0 and "left" or "right") or "straight"
end


local active_guiid

local function guiHandleEvent(id, name, param)
	ugCostLabel.guiHandleEvent(id, name, param)
	if id=="trackBuilder" or id=="streetBuilder" or id=="constructionBuilder" then  -- or id=="streetTrackModifier" -- works in principle, but not reliably bec sometimes more adjacent than the selected segment are updated
		if name=="builder.proposalCreate" then
			if param.data.errorState.critical or #param.proposal.proposal.addedSegments==0 then 
				toolTipCont.destroy()
				ugCostLabel.hide(false, id)
				active_guiid = nil
				return
			end
			local status, err = pcall( function() 
				-- local sttime = os.clock()
				local g = GeomInfo.calc(param, id)
				if g.ns==0 then
					toolTipCont.destroy()
					ugCostLabel.hide(false, id)
					active_guiid = nil
					return
				end
				
				local speedstring = string.format("v: %.0f%s km/h", g.speedLimit.min*3.6, g.multi and g.speedLimit.max>g.speedLimit.min and string.format(" - %.0f", g.speedLimit.max*3.6) or "")
				if g.formtype~="STRAIGHT" and g.curveSpeedLimit.min*3.6<1000 then
					speedstring = speedstring..string.format(" | c: %.0f%s km/h", g.curveSpeedLimit.min*3.6, g.multi and g.curveSpeedLimit.max>g.curveSpeedLimit.min and string.format(" - %.0f", g.curveSpeedLimit.max*3.6) or "")
				end
				local slopemaxstr = ""
				if g.slope.A and g.slope.max>0.0005 and g.slope.max>1.1*math.max(math.abs(g.slope.A),math.abs(g.slope.E)) then
					 slopemaxstr = string.format(" | max: %.0f‰", g.slope.max*1000)
				end
				local heightmaxstr = ""
				if g.height.A and g.height.min<math.min(g.height.A,g.height.E)-0.05 then
					heightmaxstr = heightmaxstr..string.format(" | min: %.1f m",  g.height.min)
				end
				if g.height.A and g.height.max>math.max(g.height.A,g.height.E)+0.05 then
					heightmaxstr = heightmaxstr..string.format(" | max: %.1f m",  g.height.max)
				end
				local radiusmaxstr = ""
				if g.radius.A and g.radius.min<1e4 and g.radius.min<0.95*math.min(math.abs(g.radius.A),math.abs(g.radius.E)) then
					radiusmaxstr = radiusmaxstr..string.format(" | min: %s", radiusStr(g.radius.min))
				end
				if g.radius.A and g.formtype~="S-CURVE" and g.radius.max>1.05*math.max(math.abs(g.radius.A),math.abs(g.radius.E)) then
					radiusmaxstr = radiusmaxstr..string.format(" | max: %s", radiusStr(g.radius.max))
				end
				local rAdir = ""
				local rEdir = ""
				if g.formtype=="S-CURVE" then
					rAdir = string.format(" (%s)", radiusDir(g.radius.A))
					rEdir = string.format(" (%s)", radiusDir(g.radius.E))
				end
				local tttext = linesConcat({
					-- string.format("L: %.0f m", g.leng),
					(id=="constructionBuilder" or id=="streetTrackModifier") and g.lengS>0 and string.format("Street: %.0f m", g.lengS),
					(id=="constructionBuilder" or id=="streetTrackModifier") and g.lengT>0 and string.format("Track: %.0f m", g.lengT),
					g.lengBr>0 and string.format("Bridge: %.0f m", g.lengBr),
					g.lengTn>0 and string.format("Tunnel: %.0f m", g.lengTn),
					g.height.A and string.format("H: %.1f m → %.1f m" , g.height.A, g.height.E )..heightmaxstr,
					g.multi and string.format("H: %.1f", g.height.min)..(g.height.max>g.height.min+0.05 and string.format(" - %.1f", g.height.max) or "").." m",
					g.slope.A and string.format("s: %.0f‰ → %.0f‰", g.slope.A*1000, g.slope.E*1000)..slopemaxstr,
					speedstring,
					g.formtype~="STRAIGHT" and not g.multi and (g.formtype=="CURVE" and string.format("R: %s", radiusStr(g.radius.A)) or string.format("R: %s%s → %s%s", radiusStr(g.radius.A), rAdir, radiusStr(g.radius.E), rEdir))..radiusmaxstr,
					g.formtype~="STRAIGHT" and g.multi and g.radius.min<1e6 and string.format("R: %s - %s", radiusStr(g.radius.min), radiusStr(g.radius.max)),
					not g.multi and g.angle.sum>0.0017 and string.format("a: %.1f°", math.deg(g.angle.sum)),
					-- (g.formtype~="STRAIGHT" and g.formtype~="CURVE" and id~="constructionBuilder") and g.formtype,
				})
				local tttoolt = linesConcat({
					string.format("Formtype: %s", g.formtype),  --g.formtype:sub(1,1), g.formtype:sub(2):lower()),
					string.format("Length: %.2f m (without crossing connections)", g.leng),
					g.height.A and string.format("Height: %.2f m → %.2f m | min: %.2f m | max: %.2f m" , g.height.A, g.height.E, g.height.min, g.height.max ),
					g.slope.A and string.format("Slope: %.1f‰ → %.1f‰ | min: %.1f‰ | max: %.1f‰", g.slope.A*1000, g.slope.E*1000, g.slope.min*1000, g.slope.max*1000),
					string.format("Speed Limit: %.0f km/h | Curve: %.1f km/h", g.speedLimit.min*3.6, g.curveSpeedLimit.min*3.6),
					--string.format("curSpeed: %.0f km/h", g.curSpeed*3.6),  -- what even is this?
					string.format("Radius: %s (%s) → %s (%s) | min: %s | max: %s", radiusStr(g.radius.A), radiusDir(g.radius.A), radiusStr(g.radius.E), radiusDir(g.radius.E), radiusStr(g.radius.min), radiusStr(g.radius.max)),
					string.format("Angle: %.2f° | max: %.1f° | av: %.1f°" , math.deg(g.angle.sum), math.deg(g.angle.max), math.deg(g.angle.sum/g.ns) ),
					"Segments: "..g.ns.." - Lanes: "..g.ne,
					g.nr>0 and "Segments replaced: "..g.nr,
					g.width>0 and string.format("Width: %.2f m", g.width),
					g.trackType and g.trackType>=0 and _("Track Type")..": "..api.res.trackTypeRep.getName(g.trackType) or g.streetType and g.streetType>=0 and _("Street Type")..": "..api.res.streetTypeRep.getName(g.streetType),
					g.notord>0 and string.format("Not ordered: %d", g.notord),
					-- string.format("Calc Time: %.3f s", os.clock()-sttime),
				})
				
				-- if not ugCostLabel.isonUI() then
					-- ugCostLabel.getComp():destroy()
					-- ugCostLabel.init = false
				-- end
				if not ugCostLabel.isInit(id) then
					ugCostLabel.initLabel(id)
					ugCostLabel.onVisFalse(id, function()
						toolTipCont.destroy()
						ugCostLabel.hide(false, id)
						active_guiid = nil
					end)
				end
				local ug_text = ugCostLabel.getText(id) or "ERROR - No UG label"
				toolTipCont.createText(tttext, tttoolt, {x=30,y=30}, ug_text)
				ugCostLabel.hide(true, id)
				active_guiid = id
			end)
			if status==false then
				ugCostLabel.hide(false, id)
				print("===== Track/Street Builder Info - Error Handler:")
				debugPrint(param)
				print(err)
				print("===== Track/Street Builder Info - Please submit this message to the mod author - https://www.transportfever.net/filebase/index.php?entry/5766-track-street-builder-info/")
				toolTipCont.createText("Error - see console or stdout", err, {x=30,y=30})
			end
		elseif name=="builder.slope" then
			-- state.slope = param  -- sending the wrong param when switching off slope...
		elseif name=="builder.apply" then
			toolTipCont.destroy()
			ugCostLabel.hide(false, id)
			active_guiid = nil
		end
	elseif (id=="menu.construction.railmenu" and name=="visibilityChange" and param==false) or
			(id=="menu.construction.roadmenu" and name=="visibilityChange" and param==false) or
			(id=="menu.construction.rail.tabs" and name=="tabWidget.currentChanged") or
			(id=="menu.construction.road.tabs" and name=="tabWidget.currentChanged") or
			(id=="bwc.tooltip" and name=="destroy")
	then
		toolTipCont.destroy()
		ugCostLabel.hide(false)
		active_guiid = nil
	elseif (id=="mainView" and name=="camera.userPan") or
			-- (id=="mainView" and name=="camera.userZoom") or
			(id=="mainView" and name=="camera.keyScroll") or
			(id=="mainView" and name=="camera.userRotateTilt")
	then
		local cpos = ugCostLabel.getPos(active_guiid)
		local bbpos = ugCostLabel.getBBPos(active_guiid)
		if cpos and bbpos then
			local x,y
			if cpos.x<bbpos.x then  -- text left
				x,y = cpos.x-toolTipCont.getSize().w, cpos.y
			else
				x,y = cpos.x, cpos.y
			end
			toolTipCont.updatePos(x,y)
		else
			toolTipCont.destroy()
			ugCostLabel.hide(false)
			active_guiid = nil
		end
	end
end

function data()
	return {
		--init = init,
		--update = update,
		--handleEvent = handleEvent,
		--save = save,
		--load = load,
		-- guiInit = guiInit,
		--guiUpdate = guiUpdate,
		guiHandleEvent = guiHandleEvent,
	}
end