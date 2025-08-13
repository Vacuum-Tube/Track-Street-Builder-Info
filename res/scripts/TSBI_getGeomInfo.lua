local list = require "TSBI_listutil"
-- local vec2 = require "vec2"
-- local vec3 = require "vec3"

local gi = {}

gi.calc = function(param, builder)
	-- debugPrint(param)
	local prop = param.proposal.proposal
	local entity2tn = param.data.entity2tn
	
	local newnodes = {}
	for i,node in pairs(prop.addedNodes) do
		newnodes[node.entity] = {
			position = node.comp.position
		}
	end
	
	local getNodePos = function(node)
		if node<0 then --new
			return newnodes[node].position
		else -- existing
			--game.interface.getEntity(node).position
			local c = api.engine.getComponent(node, api.type.ComponentType.BASE_NODE)  -- safe is safe...
			return c.position
		end
	end
	
	local newsegs = {}
	local tryordering = builder=="trackBuilder" or builder=="streetBuilder" or builder=="streetTrackModifier"
	local connecnode1, connecnode2  -- 2 tries of detecting the "node-chain"
	local firstseg, lastseg
	local outoforder = {}
	
	for i,seg in pairs(prop.addedSegments) do
		if not prop.new2oldSegments[seg.entity] or builder=="streetTrackModifier" then  -- not part of replacing edges
			local node0ent = seg.comp.node0
			local node1ent = seg.comp.node1
			local newseg = {
				entity = seg.entity,
				edgeType = seg.type,  -- 0 street, 1 track
				structureType = seg.comp.type,  -- 0 normal, 1 bridge, 2 tunnel
				structureIdx = seg.comp.typeIndex,
				node0ent = node0ent,
				node1ent = node1ent,
				node0 = getNodePos(node0ent),
				node1 = getNodePos(node1ent),
				tangent0 = seg.comp.tangent0,
				tangent1 = seg.comp.tangent1,
				tangent0XY = api.type.Vec2f.new(seg.comp.tangent0.x, seg.comp.tangent0.y),
				tangent1XY = api.type.Vec2f.new(seg.comp.tangent1.x, seg.comp.tangent1.y),
				trackType = seg.trackEdge.trackType,
				streetType = seg.streetEdge.streetType,
			}
			table.insert(newsegs, newseg)
			if tryordering then
				local segidx = #newsegs			
				if connecnode1 then
					if node0ent==connecnode1 then  -- next segment in order
						connecnode1 = node1ent
						lastseg = segidx
					elseif node1ent==connecnode2 then  -- "chain" from the other direction
						connecnode2 = node0ent
						firstseg = segidx
					else
						table.insert(outoforder, segidx)
					end
				else   -- first segment
					connecnode1 = node1ent
					connecnode2 = node0ent
					firstseg = segidx
					lastseg = segidx
				end
			end
		end
	end
	
	local notord = {}
	if #outoforder>0 then
		local counter = 0
		local maxcount = 16
		while #outoforder>0 do
			notord = {}
			for i,seg in pairs(outoforder) do
				if newsegs[seg].node0ent==connecnode1 then
					connecnode1 = newsegs[seg].node1ent
					lastseg = seg  -- last segment in order
				elseif newsegs[seg].node1ent==connecnode2 then
					connecnode2 = newsegs[seg].node0ent
					firstseg = seg
				else  -- segment could NOT be ordered
					table.insert(notord, seg)
				end
			end
			outoforder = notord
			counter = counter + 1
			if counter>maxcount and #outoforder>0 then 
				break
			end
		end
	end
	if #notord~=0 then
		if builder~="streetTrackModifier" then
			print("Track/Street Builder Info","Segments could NOT be ORDERED","#seg",#newsegs, "counter",counter)
			debugPrint(notord)
			print("firstseg: "..firstseg,"lastseg: "..lastseg,"c1: "..connecnode1,"c2: "..connecnode2)
		end
		firstseg = nil
		lastseg = nil
	end
	
	local multi = not firstseg or not lastseg  -- no clear start+end, don't consider as path
	local ns = #newsegs
	local ne = 0
	local curve, transitioncurve, scurve
	
	local leng = list.ValueList:new()
	local lengS = list.ValueList:new()
	local lengT = list.ValueList:new()
	local lengBr = list.ValueList:new()
	local lengTn = list.ValueList:new()
	local height = list.ValueList:new()
	local slope = list.ValueList:new()
	local radius = list.ValueList:new()
	local angle = list.ValueList:new()
	local width = list.ValueList:new()
	local speedLimit = list.ValueList:new()
	local curveSpeedLimit = list.ValueList:new()
	-- local curSpeed = list.ValueList:new()
	
	for _,seg in pairs(newsegs) do
		height:newVal(seg.node0.z)
		height:newVal(seg.node1.z)
		local hmid1, hmid2 = gi.hermiteMidMaxHeight(seg)
		if hmid1 then
			height:newVal(hmid1)
		end
		if hmid2 then
			height:newVal(hmid2)
		end
		slope:newVal(math.abs(gi.getVecZTangent(seg.tangent0)))
		slope:newVal(math.abs(gi.getVecZTangent(seg.tangent1)))
		local smid = gi.hermiteMidMaxSlope(seg)
		if smid then
			slope:newVal(math.abs(smid))
		end
		-- local r, a = gi.calcRadiusAndAngle(seg)
		angle:newVal(gi.calcAngle(seg))
		
		seg.straight = gi.edgeIsStraightXY(seg, builder=="constructionBuilder" and 1e-6 or 1e-7)  -- some stations have inaccurate edges...
		if not seg.straight then
			seg.radiusA = 1/gi.hermiteCurvature(seg, 0)
			seg.radiusE = 1/gi.hermiteCurvature(seg, 1)
			if seg.edgeType==0 and math.abs(seg.radiusA)>20000 and math.abs(seg.radiusE)>20000 then
				seg.straight = true
			elseif seg.edgeType==1 and math.abs(seg.radiusA)>1e6 and math.abs(seg.radiusE)>1e6 then
				seg.straight = true
			elseif math.abs(1-seg.radiusA/seg.radiusE)<.05 then
				seg.curve = true
				curve = true
			else
				transitioncurve = true
				if seg.radiusA/seg.radiusE<0 then
					scurve = true
				end
			end
			radius:newVal(math.abs(seg.radiusA))
			radius:newVal(math.abs(seg.radiusE))
			radius:newVal(math.abs(1/gi.hermiteCurvature(seg, 0.25)))
			radius:newVal(math.abs(1/gi.hermiteCurvature(seg, 0.5)))
			radius:newVal(math.abs(1/gi.hermiteCurvature(seg, 0.75)))
		else
			radius:newVal(math.huge)
		end
		
		local tn = entity2tn[seg.entity]
		if tn then
			local outerLaneLength0 = tn.edges[1].geometry.length
			local outerLaneLength1 = tn.edges[#tn.edges].geometry.length
			if #tn.nodes>0 then -- multiple lanes along segment length when signal or bus stop
				for i = 2, #tn.edges do
					if tn.edges[i].geometry.params.offset == tn.edges[i - 1].geometry.params.offset then
						outerLaneLength0 = outerLaneLength0 + tn.edges[i].geometry.length
					else
						break
					end
				end
				for i = #tn.edges - 1, 1, -1 do
					if tn.edges[i].geometry.params.offset == tn.edges[i + 1].geometry.params.offset then
						outerLaneLength1 = outerLaneLength1 + tn.edges[i].geometry.length
					else
						break
					end
				end
			end
			local length = (outerLaneLength0 + outerLaneLength1) / 2
			leng:newVal(length)
			if seg.edgeType == 0 then
				lengS:newVal(length)
			elseif seg.edgeType == 1 then
				lengT:newVal(length)
			end
			if seg.structureType==1 then
				lengBr:newVal(length)
			end
			if seg.structureType==2 then
				lengTn:newVal(length)
			end
			local widthLanes = list.ValueList:new()
			local speedLimitLanes = list.ValueList:new()
			local curveSpeedLimitLanes = list.ValueList:new()
			-- local curSpeedLanes = list.ValueList:new()
			local offsets = {}
			for i,edge in pairs(tn.edges) do  -- lanes is the better term
				if not offsets[edge.geometry.params.offset or 0] then
					widthLanes:newVal(edge.geometry.width)
					offsets[edge.geometry.params.offset or 0] = true
				end
				speedLimitLanes:newVal(edge.speedLimit)
				curveSpeedLimitLanes:newVal(edge.curveSpeedLimit)
				-- curSpeedLanes:newVal(edge.curSpeed)
				ne = ne + 1
			end
			width:newVal(widthLanes.sum)
			speedLimit:newVal(speedLimitLanes.max)  -- max because sidewalks have 0
			if not seg.straight  then
				curveSpeedLimit:newVal(curveSpeedLimitLanes.max)
			end
			-- curSpeed:newVal(curSpeedLanes.max)
		end
	end
	
	local radiusA, radiusE
	if not multi then
		radiusA = newsegs[firstseg].radiusA or math.huge
		radiusE = newsegs[lastseg].radiusE or math.huge
		if not curve and not gi.edgeTangentsParallel(newsegs[firstseg].tangent0XY, newsegs[lastseg].tangent1XY, .999995) then
			curve = true
		end
		if curve and not transitioncurve and math.abs(1-radiusA/radiusE)>.05 then
			transitioncurve = true
			if radiusA/radiusE<0 then
				scurve = true
			end
		end
	end
	
	return {
		leng = leng.sum, 
		lengS = lengS.sum, 
		lengT = lengT.sum, 
		lengBr = lengBr.sum,
		lengTn = lengTn.sum,
		ne = ne,
		ns = ns,
		nr = #prop.removedSegments,
		multi = multi,
		formtype = scurve and "S-CURVE" or transitioncurve and "TRANSITION" or curve and "CURVE" or "STRAIGHT",
		slope = {
			A = firstseg and gi.getVecZTangent(newsegs[firstseg].tangent0),
			E = lastseg and gi.getVecZTangent(newsegs[lastseg].tangent1),
			max = slope.max,
			min = slope.min,
		},
		height = {
			A = firstseg and newsegs[firstseg].node0.z,
			E = lastseg and newsegs[lastseg].node1.z,
			max = height.max,
			min = height.min,
		},
		speedLimit = speedLimit,
		curveSpeedLimit = curveSpeedLimit,
		-- curSpeed = curSpeed.min,
		width = width.max,
		-- d2 = newsegs[firstseg].tangent0.x / newsegs[firstseg].tangent0.y * newsegs[lastseg].tangent1.y / newsegs[lastseg].tangent1.x,
		-- a = gi.VecAngleCos(newsegs[firstseg].tangent0, newsegs[lastseg].tangent1),
		radius = {
			A = radiusA,
			E = radiusE,
			min = radius.min,
			max = radius.max,
		},
		angle = {
			sum = math.abs(angle.sum),
			max = math.max(angle.max, -angle.min),
		},
		trackType = firstseg and newsegs[firstseg].trackType,
		streetType = firstseg and newsegs[firstseg].streetType,
		notord = #notord,
	}
end


local function vec3Mul(v,f)
	return api.type.Vec3f.new(v.x*f, v.y*f, v.z*f)
end

function gi.VecNorm(v1,v2)
	local d
	if v2 then
		d = v2-v1
	else
		d = v1
	end
	return d*d
end

function gi.VecDist(v1,v2)
	return math.sqrt(gi.VecNorm(v1,v2))
end

function gi.VecAngleCos(v1,v2)
	return v1*v2/gi.VecDist(v1)/gi.VecDist(v2)
end

function gi.getVecZTangent(v)
	return v.z / math.sqrt(v.x^2 + v.y^2)
end

function gi.edgeTangentsParallel2(tangent0, tangent1)
	local d = tangent0.y * tangent1.x - tangent0.x * tangent1.y
	return math.abs(d) < .005
end

function gi.edgeTangentsParallel3(tangent0, tangent1)
	local d = tangent0.x / tangent0.y * tangent1.y / tangent1.x - 1
	return math.abs(d) < .0001
end

function gi.edgeTangentsParallel(tangent0, tangent1, tol)
	return gi.VecAngleCos(tangent0, tangent1) > (tol or .999999)
end

function gi.edgeIsStraightXY(edge, tol)
	local d = edge.node1 - edge.node0 - edge.tangent0
	return d.x^2+d.y^2 < (tol or 1e-8)*(edge.tangent0.x^2+edge.tangent0.y^2) and gi.edgeTangentsParallel(edge.tangent0XY, edge.tangent1XY)
end

function gi.edgeIsStraightXYZ(edge)
	local d = edge.node1 - edge.node0 - edge.tangent0
	return gi.VecNorm(d) < 1e-8*gi.VecNorm(edge.tangent0) and gi.edgeTangentsParallel(edge.tangent0, edge.tangent1)
end


function gi.calcAngle(edge)
	local p0=edge.node0
	local p1=edge.node1
	local t0=edge.tangent0
	local t1=edge.tangent1
	local a = math.acos( (t0.x*t1.x+t0.y*t1.y) / math.sqrt( (t0.x^2 + t0.y^2) * (t1.x^2 + t1.y^2) ) )
	if ( ( t1.x*(p0.x-p1.x) + t1.y*(p0.y-p1.y) ) / (t0.y*t1.x-t0.x*t1.y) ) <0 then a = -a end
	return a
end

function gi.calcRadiusAndAngle(edge)
	local p0=edge.node0
	local p1=edge.node1
	local t0=edge.tangent0
	local t1=edge.tangent1
	local r = ( ( t1.x*(p0.x-p1.x) + t1.y*(p0.y-p1.y) ) / (t0.y*t1.x-t0.x*t1.y) ) * math.sqrt(t0.x^2 + t0.y^2)
	local a = math.acos( (t0.x*t1.x+t0.y*t1.y) / math.sqrt( (t0.x^2 + t0.y^2) * (t1.x^2 + t1.y^2) ) )
	if r<0 then a = -a end  -- negative angles can compensate positives
	return r,a
end


function gi.hermite(p0, p1, m0, m1, t)
    local t2 = t * t
    local t3 = t2 * t
    local h00 = 2 * t3 - 3 * t2 + 1
    local h01 = t3 - 2 * t2 + t
    local h10 = -2 * t3 + 3 * t2
    local h11 = t3 - t2
    return vec3Mul(p0,h00) + vec3Mul(m0,h01) + vec3Mul(p1,h10) + vec3Mul(m1,h11)
end

function gi.hermiteD(edge, t)
	local p0=edge.node0
	local p1=edge.node1
	local m0=edge.tangent0
	local m1=edge.tangent1
	local t2 = t * t
	return vec3Mul(p0,6*t2-6*t) + vec3Mul(m0,3*t2-4*t+1) + vec3Mul(p1, -6*t2+6*t) + vec3Mul(m1,3*t2-2*t)
end

function gi.hermiteDD(edge, t)
	local p0=edge.node0
	local p1=edge.node1
	local m0=edge.tangent0
	local m1=edge.tangent1
	return vec3Mul(p0,12*t-6) + vec3Mul(m0,6*t-4) + vec3Mul(p1,-12*t+6) + vec3Mul(m1,6*t-2)
end

function gi.hermiteCurvature(edge, t)  -- 1/Radius
	local d = gi.hermiteD(edge, t)
	local dd = gi.hermiteDD(edge, t)
	return (d.x*dd.y-d.y*dd.x) / (d.x^2+d.y^2)^1.5
end

function gi.hermiteMidMaxSlope(edge)
	local p0=edge.node0
	local p1=edge.node1
	local m0=edge.tangent0
	local m1=edge.tangent1
	local t = (6*p0.z-6*p1.z+4*m0.z+2*m1.z) / (12*p0.z-12*p1.z+6*m0.z+6*m1.z)
	if t>0 and t<1 then
		return gi.getVecZTangent(gi.hermiteD(edge, t))
	else
		return nil
	end
end

function gi.hermiteMidMaxHeight(edge)
	local p0=edge.node0
	local p1=edge.node1
	local m0=edge.tangent0
	local m1=edge.tangent1
	local a = 6*p0.z+3*m0.z-6*p1.z+3*m1.z
	local b = -6*p0.z-4*m0.z+6*p1.z-2*m1.z
	local c = m0.z
	local q = b^2-4*a*c
	if q<0 then
		return nil, nil
	end
	local t1 = (-b+math.sqrt(q))/2/a
	local t2 = (-b-math.sqrt(q))/2/a
	local z1,z2
	if t1>0 and t1<1 then
		z1 = gi.hermite(p0, p1, m0, m1, t1).z
	end
	if t2>0 and t2<1 then
		z2 = gi.hermite(p0, p1, m0, m1, t2).z
	end
	return z1,z2
end


return gi