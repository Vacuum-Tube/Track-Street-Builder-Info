local toolTipCont = require "TSBI_tooltip"
local GeomInfo = require "TSBI_getGeomInfo"

local state = {
	slope = 0
}

local function guiHandleEvent(id, name, param)
	if id=="trackBuilder" or id=="streetBuilder" then  -- or id=="streetTrackModifier" -- or id=="streetTerminalBuilder" 
		if name=="builder.proposalCreate" then
			if param.data.errorState.critical or #param.proposal.proposal.addedSegments==0 then 
				toolTipCont.destroy()
				return
			end
			local status, err = pcall( function() 
				local sttime = os.clock()
				local ginf = GeomInfo.calc(param)
				if ginf.ns==0 then
					toolTipCont.destroy()
					return
				end
				local radiusstring, curvestring
				if ginf.angle.sum>0.01 or ginf.angle.max>0.01 then  --0.57°
					local radius
					if math.abs(ginf.radius.div)<0.05 then  --ginf.radius.dif<10
						radius = string.format("%.0f m", ginf.radius.min)
					else
						radius = string.format("%.0f - %s m", ginf.radius.min, ginf.radius.max<50000 and string.format("%.0f",ginf.radius.max) or "∞" )
					end
					radiusstring = string.format("R: %s (%.1f°)", radius , math.deg(ginf.angle.sum) )
					curvestring = string.format("c: %.0f km/h", ginf.curveSpeedLimit*3.6)
				end
				local speedstring = string.format("v: %.0f km/h", ginf.speedLimit*3.6)
				if curvestring then
					speedstring = speedstring..string.format(" (%s)", curvestring)
				end
				local heightstring
				if math.abs(ginf.heightend-ginf.heightstart)>0.5 then
					heightstring = string.format("H: %.0f m → %.0f m" , ginf.heightstart, ginf.heightend )
				end
				local slopemaxstring = ""
				if ginf.slopemax>1.1*math.max(math.abs(ginf.slopestart),math.abs(ginf.slopeend)) then
					 slopemaxstring = string.format(" (max: %.0f‰)", ginf.slopemax*1000)
				end
				local tttexttab = {
					string.format("L: %.0f m", ginf.leng),
					heightstring,
					--string.format("Building Slope: %.0f‰", state.slope*1000),
					string.format("s: %.0f‰ → %.0f‰", ginf.slopestart*1000, ginf.slopeend*1000)..slopemaxstring,
					speedstring,
					--string.format("curSpeed: %.0f km/h", ginf.curSpeed*3.6),  -- what even is this?
					radiusstring,
					--string.format("Calc Time: %.3f s", os.clock()-sttime),
					ginf.notord>0 and string.format("Not ordered: %d", ginf.notord ) or nil,
					ginf.noentn>0 and string.format("noentn: %d", ginf.noentn ) or nil,
				}
				local tttooltab = {
					string.format("Length: %.2f m", ginf.leng),
					string.format("Height: %.2f m → %.2f m" , ginf.heightstart, ginf.heightend ),
					--string.format("Building Slope: %.0f‰", state.slope*1000),
					string.format("Slope: %.1f‰ → %.1f‰ (max: %.1f‰)", ginf.slopestart*1000, ginf.slopeend*1000, ginf.slopemax*1000),
					string.format("Speed Limit: %.0f km/h (Curve: %.1f km/h)", ginf.speedLimit*3.6, ginf.curveSpeedLimit*3.6),
					--string.format("curSpeed: %.0f km/h", ginf.curSpeed*3.6),  -- what even is this?
					string.format("Radius: %.0f - %.0f m, Angle: %.1f° (max: %.1f°)", ginf.radius.min, ginf.radius.max , math.deg(ginf.angle.sum), math.deg(ginf.angle.max) ),
					"Segments: "..ginf.ns.." - Edges: "..ginf.ne,
					ginf.trackType>=0 and _("Track Type")..": "..api.res.trackTypeRep.getName(ginf.trackType) or _("Street Type")..": "..api.res.streetTypeRep.getName(ginf.streetType),
					string.format("Calc Time: %.3f s", os.clock()-sttime),
					ginf.notord>0 and string.format("Not ordered: %d", ginf.notord ) or nil,
				}
				local tttext = ""  -- table.concat(tttexttab, "\n")  concat not so flexible with nil...
				local tttoolt = ""
				for i,str in pairs(tttexttab) do
					if str then
						tttext = tttext .. str .. "\n"
					end
				end
				for i,str in pairs(tttooltab) do
					if str then
						tttoolt = tttoolt .. str .. "\n"
					end
				end
				tttext = tttext:gsub("^%s*(.-)%s*$", "%1")  -- trim
				tttoolt = tttoolt:gsub("^%s*(.-)%s*$", "%1")
				toolTipCont.createText(tttext,tttoolt,{x=30,y=15})
			end)
			if status==false then
				print("===== Track/Street Builder Info - Error Handler:")
				debugPrint(param)
				print(err)
				print("===== Track/Street Builder Info - Please submit this message to the mod author - https://www.transportfever.net/filebase/index.php?entry/5766-track-street-builder-info/")
				toolTipCont.createText("Error - see console or stdout",err,{x=30,y=15})
			end
		elseif name=="builder.slope" then
			--print("Slope",param)
			state.slope = param  -- sending the wrong param when switching off slope...
		elseif name=="builder.apply" then
			toolTipCont.destroy()
		-- else
			-- print(id,name,param)
			-- toolTipCont.createText(name,tostring(param))
		end
	elseif (id=="menu.construction.railmenu" and name=="visibilityChange" and param==false) or
			(id=="menu.construction.roadmenu" and name=="visibilityChange" and param==false) or
			(id=="menu.construction.rail.tabs" and name=="tabWidget.currentChanged") or
			(id=="menu.construction.road.tabs" and name=="tabWidget.currentChanged") or
			(id=="mainView" and name=="camera.userPan") or
			(id=="mainView" and name=="camera.keyScroll") or
			(id=="mainView" and name=="camera.userZoom") or
			(id=="bwc.tooltip" and name=="destroy")
	then
		toolTipCont.destroy()
		state.slope = 0
	end
end

function data()
	return {
		--init = init,
		--update = update,
		--handleEvent = handleEvent,
		--save = save,
		--load = load,
		--guiInit = guiInit,
		--guiUpdate = guiUpdate,
		guiHandleEvent = guiHandleEvent,
	}
end