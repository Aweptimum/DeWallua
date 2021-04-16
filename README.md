# DeWallua
## An implementation of the DeWall algorithm in pure lua

### TODO:
1. [ ] Fix the behavior of `counter`  
2. [ ] Implement skipping faces on the convex hull. For polygons, this means make_first_simplex should run instead of skipping it if the input AFL is seeded.
3. [ ] make_first_simplex needs the same constraints that make_simplex has.
4. [ ] Finish adding unconstrained, rename constrained to "polygon", make constrained refer to simple lines that appear in the AFL with no hull.

### Usage:
Clone the DeWallua folder into your project and require it with:  
```lua
local DeWall = require('DeWallua')
```

Note: Don't actually use it right now, not as-is. It has a lot of debugging statements that need to be deleted/commented out.

At the moment, the API only offers `constrained` (which is a misnomer). It will triangulate a polygon and takes a single argument: a list of points that make up a convex/concave poylgon in ccw order. It returns a list of simplices. 

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

local simplices = DeWall.constrained( vertices )
```

It's reasonably performant, especially with LuaJIT.
