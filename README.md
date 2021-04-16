# DeWallua
 Implementation of the DeWall Algorithm in Lua

TODO:
1. Fix the behavior of `counter`  
2. Implement skipping faces on the convex hull. For polygons, this means make_first_simplex should run instead of skipping it if the input AFL is seeded.
3. make_first_simplex needs the same constraints that make_simplex has.
4. Finish adding unconstrained, rename constrained to "polygon", make constrained refer to simple lines that appear in the AFL with no hull.
