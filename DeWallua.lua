local Vec	= require(table.concat({DEWALL_PATH, 'vector-light'}, '.'))
local qhull	= require(table.concat({DEWALL_PATH, 'qhull'}, '.'))
-- [[---------------------]]        Utility Functions        [[---------------------]] --
local sqrt, abs = math.sqrt, math.abs
-- Push/pop
local push, pop = table.insert, table.remove
local pack = table.pack or function(...) return {...} end
-- Print table w/ formatting
function tprint (tbl, height, indent)
	if not tbl then return end
	if not height then height = 0 end
	if not indent then indent = 0 end
	for k, v in pairs(tbl) do
		height = height+1
		local formatting = string.rep("  ", indent) .. k .. ": "
		if type(v) == "table" then
			print(formatting, indent*8, 16*height)
			tprint(v, height+1, indent+1)
		elseif type(v) == 'function' then
			print(formatting .. "function", indent*8, 16*height)
		elseif type(v) == 'boolean' then
			print(formatting .. tostring(v), indent*8, 16*height)
		else
			print(formatting .. v, indent*8, 16*height)
		end
	end
end

---@class Points
local Pointers = {}
Pointers.__index = Pointers
local function new_points (self, points, subset)
	local instance = setmetatable({}, self)
	instance.points = points
	if subset then
		for i = 1, #subset do
			instance:addPointer(subset[i])
		end
	else
		for i = 1, #points do
			instance:addPointer(i)
		end
	end
	return instance
end
setmetatable(Pointers, {__call = new_points})

function Pointers:copy(subset)
	return Pointers(self.points, subset)
end

function Pointers:addPointer(i)
	push(self, i)
end

local function points_iter(points, i)
	i = i + 1
	print(points[i])
	tprint(points.points[points[i]])
	if i <= #points then
		local pointer = points[i]
		return pointer, points.points[pointer]
	end
end

function Pointers:iterPoints()
	return points_iter, self, 0
end

function Pointers:cuttingPlane(axis)
	axis = axis or 'x'
	local plane = {}
	local a = 0
	for _, point in self:iterPoints() do
		print(_)
		a = (a + point[axis])
	end
	plane[axis] = a / #self
	return plane
end

function Pointers:partition(plane)
	local axis, a = next(plane)
	-- p1 = subset of points left of a
	-- p2 = subset of points right of a
	local p1, p2 = self:copy({}), self:copy({})
	for pointer, point in self:iterPoints() do
		if point[axis] >= a then-- to the right, wins if x = a
			p2:addPointer(pointer)
		else -- it's to the left
			p1:addPointer(pointer)
		end
	end
	return p1, p2
end

function Pointers:planeMin(plane)
	local axis, a = next(plane)
	local p_min
	for pointer, point in self:iterPoints() do -- Sorry if the below condition is unreadable, it's indexing points by indexing p_1
		if not p_min or abs(point[axis] - a) < abs(point[axis] - a) then
			p_min = pointer
		end
	end
	return p_min
end

function Pointers:closestPointer(pntr)
	local p_min, len, test_len
	local p = self.points[pntr]
	for pointer, point in self:iterPoints() do -- Sorry if the below condition is unreadable, it's indexing points by indexing p_1
		test_len = Vec.len(Vec.sub(p.x, p.y, point.x, point.y))
		if not p_min or test_len < len then
			p_min = pointer
			len = test_len
		end
	end
	return p_min
end

-- [[---------------------]]        Simplex Functions        [[---------------------]] --
local function wrap(v, hi, lo)
	return (v - lo) % (hi - lo) + lo
end

-- A collection of d points with a point in one halfspace
local function new_face(...)
	local face = pack(...)
	--face.half = pop(face)
	return face
end

-- A collection of d+1 points
local function new_simplex(...)
	return pack(...)
end

-- Decompose a simplex into faces
-- Face iterator
local function face_iter(simplex, i)
	i = i + 1
	local face = new_face(simplex[i], simplex[wrap(i+1,4,1)], simplex[wrap(i+2,4,1)])
	if i <= #simplex then return i, face end
end
-- Callable (like ipairs)
local function simplex_faces(simplex)
	return face_iter, simplex, 0
end

-- [[---------------------]]       DeWall Triangulation      [[---------------------]] --

-- Based off of DeWall algorithm, pseudocode found here on page 18:
-- http://vcg.isti.cnr.it/publications/papers/dewall.pdf
-- Description of algorithm is in section 3.1

-- TODO:
-- CLEAN

-- Get circumcircle of triangle formed by 3 points
local function triangle_circumcircle(a,b,c)
	local A, B, C = Vec.dist(a.x,a.y, b.x,b.y), Vec.dist(b.x,b.y, c.x,c.y), Vec.dist(c.x,c.y, a.x,a.y)
	local s = (A + B + C) / 2
	-- the equation for the radius is the below return value
	return (A * B * C) / (4 * sqrt(s * (s-A) * (s-B) * (s-C)))
end

-- Get sign of a number
local function sign(number)
    return number > 0 and 1 or (number == 0 and 0 or -1)
end

-- Same as same_edge, uses indices instead of x/y comparison
-- p,q and r,s are numbers
local function same_edge_index(p,q, r,s)
	return (
		(p == r and q == s)
	or
		(p == s and q == r)
	)
end

-- Test if 3 points make a ccw turn (same as collinear function, but checks for >= 0)
local function is_ccw(p, q, r)
	return Vec.det(q.x-p.x, q.y-p.y,  r.x-p.x, r.y-p.y) >= 0
end

-- Test if points c and d lie on different sides of ab
local function outer_halfspace(a,b, c,d)
    return is_ccw(a,b,c) ~= is_ccw(a,b,d)
end

-- Find if edge p-q is contained within hull of shape
-- n, o are indices of vertices corresponding to points p,q
-- HONESTLY, if p and q are consecutive then abs(p - q) == 1 should be true (in 2d case)
local function edge_in_hull(vertices,p,q)
	-- Reference vertices using r, s
	-- init first two points
	local r, s = #vertices-1, #vertices
	-- Assuming the points are ordered, we should be able to test
	-- consecutive vertices in the shape rather than
	-- checking if point p1 exists, then point p2
	for i = 1, #vertices do
		if same_edge_index(p,q, vertices[r],vertices[s]) then
			print("edge in hull? "..tostring(true))
			return true
		end
		-- Cycle r to s, s to next
		r, s = s, i
	end
	-- Didn't find matching edge, return false
	return false
end

---@class Counter
local Counter = {}
Counter.__index = Counter
local function new_counter (self, points)
	local instance = {}
	for i = 1, #points do
		instance[i] = 0
	end
	return setmetatable(instance, self)
end
setmetatable(Counter, {__call = new_counter})

function Counter:increment(f)
	local p
	for i = 1, #f-1 do -- last element in f defines half-space; skip it
		p = f[i]
		self[p] = self[p] and self[p] + 1 or 1 -- increment all points associated with face
	end
end

function Counter:decrement(f)
	local p
	for i = 1, #f-1 do -- last element in f defines half-space; skip it
		p = f[i]
		self[p] = (self[p]-1)>0 and self[p]-1 or nil -- decrement, or delete from counter if 0
	end
end

-- A face intersects a vertical line if the signs of the difference of their points' coords
-- with the coordinate of the line, a, are the same.
local function face_intersects(f,vertices, plane)
	local axis, a = next(plane)
	local p,q = vertices[f[1]], vertices[f[2]]
	--print("Cutting plane is: " .. a .. " p, q x's are: " .. p.x .. ", " .. q.x)
	return not (sign(p[axis] - a) == sign(q[axis] - a) )
end

-- A face is a subset of points, p_n, if their indices match
-- Basically the same as same_edge, but operates on indices
local function face_subset(f,p_n)
	local match_1, match_2 = false, false
	for i=1,#p_n do
		-- Check if point 1 of f matches index in p_n
		if f[1] == p_n[i] then
			match_1 = true
		-- Check if point 2 of f matches index in p_n
		elseif f[2] == p_n[i] then
			match_2 = true
		end
	end
	return match_1 and match_2
end

-- Find if a vector, b, is in the acute bound of vectors a and c
-- See: https://stackoverflow.com/a/17497339/12135804
-- Return true if b is ON the bound as a separate value.
-- (When the cross product of ab or ac is 0 and the corresponding dot_prod is +)
-- Separate value needed to override the flip test
local function vec_in_bounds(ax,ay, bx,by, cx,cy)
	-- Calculate A's rotation to B and C, then C's rotation to B and A
	local AxB = Vec.det(ax,ay, bx,by)
	local AxC = Vec.det(ax,ay, cx,cy)
	local CxB = Vec.det(cx,cy, bx,by)
	local CxA = Vec.det(cx,cy, ax,ay)
	-- Get dot products
	local AdB = Vec.dot(ax,ay, bx,by)
	local CdB = Vec.dot(cx,cy, bx,by)
	--print(string.format("A: <%.f,%.f>, B: <%.f,%.f>, C: <%.f,%.f>",ax,ay,bx,by,cx,cy) )
	--print(string.format("AxB: %.f, AdB: %.f, CxB: %.f, CdB: %.f",AxB, AdB, CxB, CdB))
	return (AxB * AxC >= 0 and CxB * CxA >= 0), ( (AxB == 0 and AdB > 0 ) or (CxB == 0 and CdB > 0) )
end
-- Given a line defined by two indices of a vertex list,
-- test if the line pr is within the angular bound of the 2 edges adjacent to p
-- and, likewise, if it is within the angular bound of the two edges adjacent to r.
-- For a better explanation, see me talking to myself on stackoverflow: https://stackoverflow.com/a/66403123/12135804
-- Vertices is list of ccw ordered points {x= x_val, y= y_val}
-- p and r are both indices of vertices, forming a line pr
local function line_in_shell(verts,p,r)
	-- For both endpoints of the line, test if they're between the bounds of the adjacent lines
	-- For p:
	-- lines ap and pb are the lines to test the rotation of pr against
	-- The points a and b are adjacent indices of p
	local a = p-1 >= 1			and p-1 or #verts
	-- b = p
	local c = p+1 <= #verts  and p+1 or 1
	-- Get vectors from p to a (A), p to b (C), P to R (B (notice the order))
	local A_x, A_y = verts[a].x - verts[p].x, verts[a].y - verts[p].y
	local C_x, C_y = verts[c].x - verts[p].x, verts[c].y - verts[p].y
	local B_x, B_y = verts[r].x - verts[p].x, verts[r].y - verts[p].y
	-- Check if pr is in the acute bound of ap, pb
	-- p_in_bounds
	local p_in_bounds, p_on_bounds = vec_in_bounds(A_x,A_y, B_x,B_y, C_x,C_y)
	--print ("Is p in_bounds: " .. tostring(p_in_bounds))

	-- If not ccw, flip p_in_bounds - we need to check the obtuse bound
	local convex = is_ccw(verts[a], verts[p], verts[c])
	--print(string.format("p_in_bounds: %s, p_on_bounds: %s, convex: %s", p_in_bounds,p_on_bounds, convex) )

	-- Flip test as needed - in bounds is actually true if it is equal to the convex flag
	-- Automatically return true if CxB/CxA is 0 and the corresponding dot_prod is > 0
	p_in_bounds = p_on_bounds or (convex and p_in_bounds) or (not convex and not p_in_bounds)

	--print(string.format("Is line %d-%d (p-r) in_bounds: %s",p,r, p_in_bounds) )
	-- For r:
	-- Do it all over again! Whoo!
	-- The points a and b are adjacent indices of r
	a = r-1 >= 1			and r-1 or #verts
	-- b = r
	c = r+1 <= #verts  	and r+1 or 1
	-- Get vectors from r to a (A), r to b (C), R to P (B (notice the order))
	A_x, A_y = verts[a].x - verts[r].x, verts[a].y - verts[r].y
	C_x, C_y = verts[c].x - verts[r].x, verts[c].y - verts[r].y
	B_x, B_y = verts[p].x - verts[r].x, verts[p].y - verts[r].y
	-- Check if rp is in the acute bound of ar, rb
	local r_in_bounds, r_on_bounds = vec_in_bounds(A_x,A_y, B_x,B_y, C_x,C_y)
	--print ("Is r in_bounds: " .. tostring(r_in_bounds))
	-- If not ccw, flip r_in_bounds - we need to check the obtuse bound
	convex = is_ccw(verts[a], verts[r], verts[c])
	--print ("Is r convex: " .. tostring(convex))
	--print(string.format("r_in_bounds: %s, r_on_bounds: %s, convex: %s", r_in_bounds, r_on_bounds, convex) )
	-- Flip test as needed - in bounds is actually true if it is equal to the convex flag
	r_in_bounds = r_on_bounds or (convex and r_in_bounds) or (not convex and not r_in_bounds)
	--print(string.format("Is line %d-%d (r-p) in_bounds: %s",r,p, r_in_bounds) )
	-- If both bounding conditions are true, then pr lies inside of the polygon
	return p_in_bounds and r_in_bounds
end

-- p-q are the face the simplex is being built from
-- i is the 3rd POTENTIAL point for the simplex we're checking
-- w is the 3rd point of the simplex that face p-q CAME FROM (if p-q came from a simplex)
local function is_point_in_halfspace(points, p,q,w,i)
    -- If w is 0/nil, then it's part of the convex hull
    -- Else check if w is in the outer-halfspace wrt i
    return ((w == 0) or outer_halfspace(points[p],points[q], points[w],points[i]) )
end

-- If make_simplex's unconstraint flag is false, run this test
-- p-q are the face the simplex is being built from
-- i is the 3rd POTENTIAL point for the simplex we're checking
-- Notes:
-- If lines p-i and q-i are BOTH within the bounds of their neighboring points, then the line is (most likely) IN the polygon
-- TODO: Need to detect if p-i and q-i cross the bounds of the polygon. It is possible for two "ears" of a polygon
-- to be placed such that a line between them passses this test, but it violates the polygon boundary.
-- Think of a line between the ends of a bicycle's handlebars - it crosses the handlebar boundary twice.
local function is_simplex_constrained(points, p,q,i)
    return line_in_shell(points, p, i) and line_in_shell(points, q, i)
end

-- Given a face, f, find the point, r, in points that makes the triangle with the minimum circumcircle
-- Args:
-- points is list of {x = x, y = y}, counter is list # of available adjacent triangulations per point,
-- f is a single pair of vertex indices that corresponds to points list, t is the simplex f came from
-- Conditions:
-- 1. Taking f as a plane, r must lie on the side of f that does not contain the simplex f came from
--		(Test w/ are_lines_intersecting - true means the point is on the opposite side of the simplex)
-- 2. Only pick points with a counter greater than 0
-- 3. For a concave polygon, lines pr and qr must lie INSIDE the concave hull
local function make_simplex(hull, points,counter, f, unconstrained, first)
	first = first or false
	print("counter is: ")
	tprint(counter, 0, 3)
	print("f is: "..f[1]..", "..f[2]..", "..tostring(f[3]))
	-- p and q are indices in face f
	local p, q, w = f[1], f[2], f[3]
	-- Check if face is in hull, return nil if it is (skip check if first simplex)
	if not first and edge_in_hull(hull, p,q) then return nil end
	local r, min_r, temp_r
	for i, _ in pairs( counter ) do -- ONLY CHECK POINTS IN COUNTER
		-- Only test i if it isn't p/q
		if i ~= p and i ~= q and i ~= w then
			print('testing vertex #: ' .. i)
			-- Test two things:
			-- If i is in the outer half-space of pq, and if pr and qr are within the polygon
			--print(string.format("P: %i, Q: %i, W: %i, I: %i", p,q,w,i))
			print("halfspace? "..tostring(is_point_in_halfspace(points,p,q,w,i)))
			if is_point_in_halfspace(points,p,q,w,i) and (unconstrained or is_simplex_constrained(points, p,q,i)) then
				-- Find triangle with smallest circumcircle
				temp_r = triangle_circumcircle(points[p], points[q], points[i])
				print("circumcircle is " .. temp_r)
				if not min_r or temp_r < min_r then
					-- radius is smaller, so keep it, and set r to i
					min_r = temp_r
					r = i
				end
			end
		end
	end
	print("Make simplex: " .. p .. ", " .. q .. ", " .. tostring(r))
	-- Return simplex of 3 indices
	return r and new_simplex(p,q,r) or nil
end

-- Given subsets p_1 and p_2, make the first simplex for the wall
-- p_1 and p_2 are a list of indices of vertices, NOT points
-- this means we need to index vertices by vertices[p_n[i]] to get the points we need
local function make_first_simplex(hull, points, counter, p1, p2, plane, unconstrained)
	-- Find nearest points to plane in p_1 and p_2
	local p1Min = p1:planeMin(plane)
	local p2Min = p2:closestPointer(p1Min)
	local f = { p1Min, p2Min, 0 }
	-- Now make_simplex
	return make_simplex(hull, points, counter, f, unconstrained, true)
end

-- For each face in t, insert it into AFL if it does not exist, otherwise, delete it.
-- Increment the counters of each face's endpoints if it's a new face.
-- t is a simplex/triangle of 3 indices pointing to the points array
-- counter controls indicent faces to p
-- AFL is the current active-faces-list
local function AFL_update(f, counter, AFL)
	-- f is a list of 2 point indices
	-- Reference points in points array using f[1], f[2]
	local p,q,w = f[1], f[2], f[3]
	print("\tAFL update f is: " .. p .. ", " .. q)
	--tprint(AFL, 0, 3)
	-- Init index pair to test f against
	local r,s
	for i = 1, #AFL do
		r,s = AFL[i][1], AFL[i][2]
		if same_edge_index(p,q, r,s) then
			-- Already here, remove the edge using swapop
			AFL[i], AFL[#AFL] = AFL[#AFL], AFL[i]
			-- pop the last face
			pop(AFL)
			-- We can return now
			print("\tRemoving: " .. p .. ", " .. q .. " because of: " .. r .. ", " ..s)
			--tprint(AFL, 0, 2)
			return
		end
	end

	-- Well, we made it here, so we can insert new face into AFL
	-- Insert indices, not points
	push(AFL, {p, q, w})
	-- We can increment the counters for points n and o
	print("\tInserting f: " .. f[1] .. ", " .. f[2])
	--tprint(AFL, 0, 2)
	counter:increment(f)
	return
end

-- Takes a polygon and triangulates it
-- vertices is the list of x/y points that make up a concave polygon
-- Points is the subset of vertices we're working with
-- 		- it is a list of indices corresponding to the working set of vertices
-- AFL_o is the active-face-list from which new triangles are seeded
-- I think seeding AFL with all of the edges in vertices "constrains" it to the polygon, not sure
-- simplices = table of t's
-- f = 'face', a table of two points representing an edge
-- f_prime is also a face, used for inner-loop
-- t = triangle/simplex, a table of 3 values corresponding to indices in polygon.vertices
-- counter = key corresponds to a vertex in polygon.vertices, value is a counter
-- 		when a point in vertices becomes part of a new f, the counter increases by 1
-- 		when a point's incident f is fed into make simplex, the counter decreases by 1
local function dewall_triangulation(unconstrained, hull, points,p_array,counter, AFL_o, simplices, axis)
	-- Init subsets of points
	local AFL_a, AFL_1, AFL_2 = {}, {}, {}
	-- Init local temp vars
	local f, f_prime, t = {}, {}, {}

	-- DeWall Begins!

	-- If axis not specified, default to x
	axis = axis or 'x'
	-- Get cutting plane
	local plane = p_array:cuttingPlane(axis)
	-- Partition points
	local p_1, p_2 = p_array:partition(plane)

	-- If AFL is empty, then we need to make the first simplex
	-- Supplying AFL with polygon edges skips the following block
	-- This should constrain the triangulation to the edges of the polygon (right?)
	if #AFL_o == 0 then
		print("Make first simplex ran")
		t = make_first_simplex(hull, points, counter, p_1, p_2, plane, unconstrained)
		-- Insert t (triangle) into list of simplices
		push(simplices, t)
		-- Loop over simplex: insert each f into AFL_o, increment counter for each
		for i, face in simplex_faces(t) do
			tprint(f)
			-- Increment new faces
			counter:increment(face)
			-- Add to AFL
			push(AFL_o, face)
		end
	end

	--tprint(counter)

	-- For each face in AFL, put it in the appropriate sub-AFL
	for i=1,#AFL_o do
		-- Set face
		f = AFL_o[i]
		-- Check for where the face should go
		if face_intersects(f,points, plane) then 	-- If face interesects cutting plane, goes in the wall
			print("Adding f to AFL_a (" .. f[1] .. ", " .. f[2] .. ")" )
			push(AFL_a, f)
		elseif face_subset(f, p_1) then 		-- If face is a subset of p_1, add it to AFL_1
			print("Adding f to AFL_1 (" .. f[1] .. ", " .. f[2] .. ")" )
			push(AFL_1, f)
		elseif face_subset(f, p_2) then 		-- If face is a subset of p_2, add it to AFL_2
			print("Adding f to AFL_2 (" .. f[1] .. ", " .. f[2] .. ")" )
			push(AFL_2, f)
		end
	end

	-- Length of AFL_a is non-zero, so build out simplices from it
	while #AFL_a ~= 0 do
		-- Extract a face from the AFL list for the wall
		f = pop(AFL_a)
		--print("F is : " .. f[1] .. ", " .. f[2] .. ", "..f[3])
		-- Create a simplex using the face f
		t = make_simplex(hull,points,counter, f, unconstrained)
		-- Decrement counter no matter what
		counter:decrement(f)
		if t then
			-- Union the simplex t with the rest of the simplices
			push(simplices, t)
			-- loop over faces in simplex t as f_prime, add vertex to test halfspace against
			for i, f_prime in simplex_faces(t) do
				-- Check f_prime doesn't match f
				if not same_edge_index(f_prime[1], f_prime[2], f[1], f[2]) then
					print("\tF_prime: " .. f_prime[1] .. ", " .. f_prime[2])
					-- Check for where the faces in AFL should go
					if face_intersects(f_prime,points, plane) then 	-- If face interesects the plane, update the wall
						print("\tUpdating AFL_a")
						AFL_update(f_prime,counter, AFL_a)
					elseif face_subset(f_prime, p_1) then 		-- If face is a subset of p_1, update AFL_1
						print("\tUpdating AFL_1")
						AFL_update(f_prime,counter, AFL_1)
					elseif face_subset(f_prime, p_2) then 		-- If face is a subset of p_2, update AFL_2
						print("\tUpdating AFL_2")
						AFL_update(f_prime,counter, AFL_2)
						tprint(AFL_2)
					else
						print("uh oh")
						local a, __ = next(plane)
						print("AFL_a"); print("A is: "..a..", "..points[f_prime[1]].x..points[f_prime[2]].x); tprint(AFL_a)
						print("AFL_1"); tprint(AFL_1)
						print("AFL_2"); tprint(AFL_2)
					end
				end
				-- Cycle f_prime
				--f_prime[1], f_prime[2], f_prime[3] = f_prime[2], f_prime[3], t[i]
			end
		end
	end

	-- Recurse into P_1, P_2
	if #AFL_1 ~= 0 then print("recursing for AFL_1") end
	if #AFL_2 ~= 0 then print("recursing for AFL_2") end
	-- Flip axis
	axis = axis == 'x' and 'y' or 'x'
	if #AFL_1 ~= 0 then simplices = dewall_triangulation(unconstrained, hull,points,p_1,counter, AFL_1, simplices, axis) end
	if #AFL_2 ~= 0 then simplices = dewall_triangulation(unconstrained, hull,points,p_2,counter, AFL_2, simplices, axis) end
	-- Return simplices
	return simplices
end

-- Convert simplices returned by triangulation into actual polygons
-- Yes, simplices is plural of simplex
-- No, I did not choose 'simplices' because this function sounds like poetry
local function simplices_indices_vertices(vertices, simplices)
	print("Simplices: ")
	tprint(simplices)
	-- Init triangles table of alternating x,y vals per triangle (6 vals each)
	local triangles = {}
    -- Loop over simplices, convert the list of 3 indices to ccw vertices
    -- Use ipairs because we're not doing index-based baffoonery
    for index, simplex in ipairs(simplices) do
		triangles[index] = {}
        for jindex, vertex in ipairs(simplex) do
            --triangles[index][jindex] = {x = vertices[vertex].x, y = vertices[vertex].y}
            push(triangles[index], vertices[vertex].x)
			push(triangles[index], vertices[vertex].y)
        end
    end
	tprint(triangles)
	return triangles
end

-- API Functions
local function unconstrained_delaunay(points, AFL)
	-- Construct the hull
	local hull = Pointers(points, qhull(points))
    -- Init points (index list of vertices) and Active-Face List (list of index-pairs that make edges)
	local pointArray = Pointers(points)
	-- Create counter
	local counter = Counter(points)
	-- Init AFL
    AFL = AFL or {}
    -- Pass args to triangulation function
    local simplices = dewall_triangulation(true, hull, points, pointArray,counter, AFL, {} )
    -- Use simplices to index into vertices and generate list of triangles
    local triangles = simplices_indices_vertices(points, simplices)
    -- Create concave polygon per triangle, store in triangles list?
    print("Creating triangle polygons")
    return triangles
end
-- Given a polygon, triangulate it using DeWall given the condition that
-- no lines must be created outside the polygon
-- Takes a vertex list where values are of the form: {x=val, y=val}
local function constrained_delaunay(points)
	-- Init points (index list of vertices) and Active-Face List (list of index-pairs that make edges)
	local pointArray = Pointers(points)
	-- Create counter
	local counter = Counter(points)
	-- Pass args to triangulation function
	local simplices = dewall_triangulation(false, pointArray, points, pointArray, counter, {}, {} )
	-- Use simplices to index into vertices and generate list of triangles
	local triangles = simplices_indices_vertices(points, simplices)
	-- Create concave polygon per triangle, store in triangles list?
	print("Creating triangle polygons")
	return triangles
end

local function to_vertices(vertices, x, y, ...)
    if not (x and y) then return vertices end
	vertices[#vertices + 1] = {x = x, y = y} -- , dx = 0, dy = 0}   -- set vertex
	return to_vertices(vertices, ...)
end

local function to_tris(simplices)
    for _, simplex in ipairs(simplices) do
		simplex = {to_vertices({}, unpack(simplex))}
	end
end

-- API --
local DeWall = {
	unconstrained = unconstrained_delaunay,
    constrained = constrained_delaunay,
	to_vertices = to_vertices,
	to_tris = to_tris
}
local function draw_simplex(simplex)
	local p = {}
	for _, point in ipairs(simplex) do
		table.insert(p, point.x); table.insert(p, point.y)
	end
	love.graphics.polygon('line', p)
end
local function draw_simplices(simplices)
	for _, simplex in ipairs(simplices) do
		draw_simplex(simplex)
	end
end
return DeWall