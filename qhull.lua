local Vec = _Require_relative(..., "vector-light")

-- Get a punch of points that look like this: {x = n, y = o}

-- Localization
-- Push/pop
local push, pop = table.insert, table.remove
-- Math
local abs,atan2 = math.abs, math.atan2

-- swapop
-- Remove an element without creating a "hole" or returning the tail
local function swapop(table, index)
    table[index], table[#table] = table[#table], table[index]
	return pop(table)
end

-- Generate point-index array
local function new_p_array(points)
	local p_array = {}
	for i = 1,#points do
		p_array[i] = i -- order doesn't matter, value is pointer to points table
	end
	return p_array
end

-- Given an array of points, find the minimum
local function min_point(points, p_array)
	local mini
	for i = 1, #p_array do
		if not mini or points[p_array[i]].x < points[p_array[mini]].x then
			mini = i
		elseif points[p_array[i]].x == points[p_array[mini]].x then
			mini = points[p_array[i]].y < points[p_array[mini]].y and i or mini
		end
	end
	return swapop(p_array, mini)
end
-- Given an array of points, find the maximum
local function max_point(points, p_array)
	local maxi
	for i = 1, #p_array do
		if not maxi or points[p_array[i]].x > points[p_array[maxi]].x then
			maxi = i
		elseif points[p_array[i]].x == points[p_array[maxi]].x then
			maxi = points[p_array[i]].y > points[p_array[maxi]].y and i or maxi
		end
	end
	return swapop(p_array, maxi)
end
-- Given an array of points, return the two with min/max x values
local function min_max_points(points, p_array)
    return min_point(points, p_array), max_point(points, p_array)
end

-- Test if 3 points make a ccw turn
local function is_ccw(p, q, r)
	return Vec.det(q.x-p.x, q.y-p.y,  r.x-p.x, r.y-p.y) >= 0
end

-- Given points and min/max points,
-- Partition points into two subsets on either side of min/max
local function points_partition(points,p_array, pmin,pmax)
	-- Init lists of indices pointing to vertices:
	-- p_1 = subset of points "left" of plane (ccw)
	-- p_2 = subset of points "right" of plane (cw)
	local p_test
	local p_1, p_2 = {}, {}
	for i = 1, #p_array do
		p_test = points[p_array[i]]
		if is_ccw(points[pmin], points[pmax], p_test) then -- wins if collinear
			push(p_1, p_array[i])
		else
			push(p_2, p_array[i])
		end
	end
	return p_1, p_2
end

-- Planar distance function
local function point_plane_dist(points, p, pmin, pmax)
	local plane_x, plane_y = Vec.sub(points[pmax].x, points[pmax].y, points[pmin].x, points[pmin].y)
	local p_vec_x, p_vec_y = Vec.sub(points[p].x, points[p].y, points[pmin].x, points[pmin].y)
	-- Reject p_vec onto plane vector and return length
	return Vec.len( Vec.reject(p_vec_x, p_vec_y, plane_x, plane_y) )
end

-- Returns point in points subdomain closest to plane a
local function point_plane_max(points, p_array, pmin, pmax)
	local p, dist, max_dist
	for i = 1, #p_array do
		--if is_ccw(points[pmin],points[pmax], points[p_array[i]]) then
			dist = point_plane_dist(points,p_array[i],pmin,pmax)
			if not p or dist > max_dist then
				p = i
				max_dist = dist
			end
		--end
	end
	return swapop(p_array,p) -- return index of furthest point
end

-- Given points and simplex
-- Delete points in simplex, partition remaining into 2 subsets
local function simplex_partition(points,p_array, p1,pmax,p2)
	local p_test
	local p_1, p_2 = {}, {}
	for i = #p_array,1,-1 do
		p_test = p_array[i]
		if is_ccw(points[p1], points[pmax], points[p_test]) then -- wins if collinear
			push(p_1, swapop(p_array, i))
		elseif is_ccw(points[pmax], points[p2], points[p_test]) then
			push(p_2, swapop(p_array, i))
		else
			swapop(p_array, i)
		end
	end
	return p_1, p_2
end

local function find_hull(hull, points, p_array, p1, p2)
	if #p_array == 0 then return end
	-- Get max point in p_array
	local p_max = point_plane_max(points, p_array, p1, p2)
	-- Add max point to hull
	push(hull, points[p_max])
	-- Partition remaining points
	local p_1, p_2 = simplex_partition(points, p_array, p1,p_max,p2)
	-- Recurse for two new lines: p1-pmax, pmax-p2
	find_hull(hull, points, p_1, p1, p_max)
	find_hull(hull, points, p_2, p_max, p2)
end

local function sort_hull(points)
	-- Find reference point to calculate cw/ccw from (left-most x, lowest y)
	local p_ref = points[1]
	for i = 2, #points do
		if points[i].y < p_ref.y then
			p_ref = points[i]
		elseif points[i].y == p_ref.y then
			if points[i].x < p_ref.x then
				p_ref = points[i]
			end
		end
	end

	-- table.sort function - sorts points in ccw order
	-- p_ref and points_indices are upvalues (within scope); can be accessed from table.sort
	local function sort_ccw_i(v1,v2)
		-- v1 and v2 are indices of vertices from points_indices
		-- if v1 is p_ref, then it should win the sort automatically
		if v1.x == p_ref.x and v1.y == p_ref.y then
			return true
		elseif v2.x == p_ref.x and v2.y == p_ref.y then
		-- if v2 is p_ref, then v1 should lose the sort automatically
			return false
		end
		-- Else compute and compare polar angles
		local a1 = atan2(v1.y - p_ref.y, v1.x - p_ref.x) -- angle between x axis and line from p_ref to v1
		local a2 = atan2(v2.y - p_ref.y, v2.x - p_ref.x) -- angle between x axis and line from p_ref to v1
		if a1 < a2 then
            return true -- true means first arg wins the sort (v1 in our case)
        elseif a1 == a2 then -- points have same angle, so choose the point furthest from p_ref
            local m1 = Vec.dist(v1.x,v1.y, p_ref.x,p_ref.y)
            local m2 = Vec.dist(v2.x,v2.y, p_ref.x,p_ref.y)
            if m1 > m2 then
                return true -- v1 is further away, so it wins the sort
            end
        end
	end
	-- Sort points
	table.sort(points, sort_ccw_i)
	return points
end

local function qhull(points)
	local hull = {}
	local p_array = new_p_array(points)
	local pmin, pmax = min_max_points(points, p_array)
	-- Add to hull
	push(hull, points[pmin]); push(hull,points[pmax])
	-- Partition points and recursively generate hull for both subdomains
	local p_1, p_2 = points_partition(points, p_array, pmin, pmax)
	find_hull(hull, points, p_1, pmin, pmax)
	find_hull(hull, points, p_2, pmax, pmin)
	return sort_hull(hull)
end

return qhull