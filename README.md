# DeWallua
An implementation of the DeWall algorithm in pure lua, found here: http://vcg.isti.cnr.it/publications/papers/dewall.pdf

### TODO:
1. Clean!

### Installation:
**Note: Don't actually use it right now as-is. It has a lot of debugging statements that need to be deleted/commented out.

Clone the DeWallua folder into your project and require it with:  
```lua
local DeWall = require('DeWallua')
```

### Usage:
At the moment, the API offers `constrained` and `unconstrained`. 

`unconstrained` takes two arguments. The first is the list of points to triangulate (in `{x = x_val, y=y_val}` format). The second (optional) argument is a list of faces to insert into the triangulation. The faces' endpoints must be present in `points` and must be specified as a list of index-pairs like so:
```lua
faces = {{1,2}, {5,6}}
```

`constrained` takes a single argument: a list of ccw-ordered points that make up a convex/concave poylgon.
It will triangulate the polygon staying within its bounds.

Both functions return a list of simplices in `{x1,y1,x2,y2,x3,y3}` format and leave their arguments intact.

An example:
```lua
local vertices = {
	{x =  0, y = 0}, 
	{x =  0, y = 1}, 
	{x = -1, y = 1}, 
	{x = -1, y = 2}, 
	{x = -2, y = 2}, 
	{x = -2, y = 0}, 
}

local simplices = DeWall.unconstrained( vertices )
tprint( simplices )
-- Prints these indexes as their equivalent x,y points:
-- {{1,3,2}, {3,2,4}, {1,3,6}, {3,6,4}, {5,3,4}}

local simplices = DeWall.constrained( vertices )
tprint( simplices )
-- Prints these indexes as their equivalent x,y points:
-- {{1,3,2}, {1,3,6}, {3,6,4}, {5,3,4}}

-- Notice there's one less triangle now -
-- the triangle made by points {3,2,4} lies outside the shape 
```

### How it Works
An overview of the algorithm:

1) Compute the convex hull of the given points, `P` (or use the verts themselves)
2) Compute the cutting plane, `a` (take the average of all numbers along an axis)
3) Divide the input points, `P`, along a into two subsets: `P1` and `P2`
4) Choose the point in `P1` and `P2` closest to the cutting plane, `p1` and `p2`
5) Choose the point in `P`, `p3`, that makes triangle `p1`-`p2`-`p3` with the smallest circumcircle
6) Add all edges not present into their corresponding Active-Face-List, `AFL`, (else remove the duplicate)
7) For each face in the `AFL` that intersects the cutting plane, use it to build a new minimum triangle
8) Continue until no more edges remain intersecting `a`
9) Repeat the process recursively, subdividing `P1` and `P2` further until all `AFL`'s are empty.

#### Make_Simplex()
This function is the real heart of the algorithm (and might be doing too much)
Here's what it does:
1) Given a face (f), check if it isn't already present in the hull of the given points (skip if so)
2) Iterate through points in the counter (skip if the current point is in the given face)
3) Test each point, i, for two things:
	* Is i in the correct halfspace defined by f
	* Is i constrained to the hull? (Does connecting f to i create self-intersections?)
4) Calculate the circumcircle of the triangle formed by f and i
5) If the circumradius is smaller than the current radius, i becomes the new candidate point
6) Return the simplex formed by f and the candidate point that yields the minimum circumradius