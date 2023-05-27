local list = require "TSBI_listutil"

local gi = {}

gi.calc = function(param)
	--debugPrint(param)
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
	
	local ne = 0
	local newsegs = {}
	local connecnode1, connecnode2  -- 2 tries of detecting the "node-chain"
	local firstseg, lastseg
	local outoforder = {}
	local noentn = 0
	local lists = {
		leng = list.newList(),
		speedLimitSeg = list.newList(),
		curveSpeedLimitSeg = list.newList(),
		curSpeedSeg = list.newList(),
		radius = list.newList(),
		angle = list.newList(),
		slope = list.newList(),
	}
	local trackType, streetType
	
	for i,seg in pairs(prop.addedSegments) do
		local segent = seg.entity
		if not prop.new2oldSegments[segent] then  -- not part of replacing edges
			
			local node0ent = seg.comp.node0
			local node1ent = seg.comp.node1
			
			local newseg = {
				entity = segent,
				tangent0 = seg.comp.tangent0,
				tangent1 = seg.comp.tangent1,
				node0 = getNodePos(node0ent),
				node1 = getNodePos(node1ent),
				node0ent = node0ent,
				node1ent = node1ent,
			}
			--debugPrint(newseg)
			table.insert(newsegs, newseg)
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
			
			list.newVal(lists.slope, math.abs(gi.getVecZTangent(newseg.tangent0)) )
			list.newVal(lists.slope, math.abs(gi.getVecZTangent(newseg.tangent1)) )
			-- print(gi.getVecZTangent(newseg.tangent0))
			-- print(gi.getVecZTangent(newseg.tangent1))
			
			local radius, angle = gi.calcRadiusAndAngle(newseg)
			--print("Radius:", radius, "Angle:", math.deg(angle))
			list.newVal(lists.radius, math.abs(radius))
			list.newVal(lists.angle, angle)
			
			local tn = entity2tn[segent]
			--print(segent, tn, "edges:"..#tn.edges, "nodes:"..#tn.nodes)
			
			if tn then
				list.newVal(lists.leng, tn.edges[1].geometry.length)
				
				local speedLimit = list.newList()
				local curveSpeedLimit = list.newList()
				local curSpeed = list.newList()
				for i,edge in pairs(tn.edges) do  -- streets: >1 "edge" in 1 segment
					list.newVal(speedLimit, edge.speedLimit)
					list.newVal(curveSpeedLimit, edge.curveSpeedLimit)
					list.newVal(curSpeed, edge.curSpeed)
					ne = ne + 1
				end
				list.newVal(lists.speedLimitSeg, speedLimit.max)  -- max because sidewalks have 0
				list.newVal(lists.curveSpeedLimitSeg, curveSpeedLimit.max)
				list.newVal(lists.curSpeedSeg, curSpeed.max)
				
			else
				-- print("No entity2tn!",segent)
				noentn = noentn+1
			end
			
			trackType = seg.trackEdge.trackType
			streetType = seg.streetEdge.streetType
		end
	end
	
	--debugPrint(lists.radius)
	--debugPrint(lists.angle)
	--debugPrint(lists.curveSpeedLimitSeg)
	
	local ns = #newsegs
	--debugPrint(newsegs)
	
	local notord = {}
	if #outoforder>0 then
		-- print("REORDER", #outoforder)
		-- debugPrint(outoforder)
		
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
				else
					--print("Segment NOT ORDERED", seg )
					table.insert(notord, seg)
				end
			end
			outoforder = notord
			counter = counter + 1
			if counter>maxcount and #outoforder>0 then 
				--print("Break while")
				break
			end
		end
		
		if #notord==0 then
			--print("Segments ordered!", "counter",counter)
		else
			--debugPrint(param)
			--debugPrint(newsegs)
			print("Track Info","Segments could NOT be ORDERED","#seg",ns, "counter",counter)
			debugPrint(notord)
			print("firstseg: "..firstseg,"lastseg: "..lastseg,"c1: "..connecnode1,"c2: "..connecnode2)
		end
	end
	
	return {
		leng = lists.leng.sum, 
		ne = ne,
		ns = ns,
		slopestart = ns>0 and gi.getVecZTangent(newsegs[firstseg].tangent0),
		slopeend = ns>0 and gi.getVecZTangent(newsegs[lastseg].tangent1),
		slopemax = lists.slope.max,
		heightstart = ns>0 and newsegs[firstseg].node0.z,
		heightend = ns>0 and newsegs[lastseg].node1.z,
		speedLimit = lists.speedLimitSeg.min,
		curveSpeedLimit = lists.curveSpeedLimitSeg.min,
		curSpeed = lists.curSpeedSeg.min,
		radius = {
			--av = math.abs(lists.radius.sum/ns),
			--dif = lists.radius.max - lists.radius.min,
			div = lists.radius.max/lists.radius.min-1,
			min = lists.radius.min,
			max = lists.radius.max,
		},
		angle = {
			sum = math.abs(lists.angle.sum),
			max = math.max(lists.angle.max, -lists.angle.min),
		},
		trackType = trackType,
		streetType = streetType,
		notord = #notord,
		noentn = noentn,
	}
end

gi.getVecZTangent = function(v)
	return v.z / math.sqrt(v.x^2 + v.y^2 ) --+ v.z^2)
end

gi.calcRadiusAndAngle = function(c)
	local p0=c.node0
	local p1=c.node1
	local t0=c.tangent0
	local t1=c.tangent1
	local r = ( ( t1.x*(p0.x-p1.x) + t1.y*(p0.y-p1.y) ) / (t0.y*t1.x-t0.x*t1.y) ) * math.sqrt(t0.x^2 + t0.y^2) --math.abs
	local a = math.acos( (t0.x*t1.x+t0.y*t1.y) / math.sqrt( (t0.x^2 + t0.y^2) * (t1.x^2 + t1.y^2) ) )
	if r<0 then a = -a end  -- negative angles can compensate positives
	return r,a
end

return gi