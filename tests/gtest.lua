#!/usr/bin/lua

local compose = require( "fx" ).compose
local g = require( "fx.glue" )


local function f()
  return 1, 2, 3, 4
end



local function test_vmap()
  local function e()
  end
  local function inc( x )
    return (x or 0)+1
  end
  assert( returns( is_function, g.vmap, inc ) )
  assert( returns( resp( 2,3,4,5 ), compose( g.vmap( inc ), f ) ) )
  assert( returns( resp(), compose( g.vmap( inc ), e ) ) )
  assert( returns( resp( 1,2,3,4 ), compose( g.vmap( inc, 5 ), f ) ) )
  assert( returns( resp( 1,3,4,5 ), compose( g.vmap( "x => x+1", 2 ), f ) ) )
  assert( returns( resp( 1,3,4,4 ), compose( g.vmap( inc, 2, -2 ), f ) ) )
  assert( returns( resp( 1,3,4,5,1 ), compose( g.vmap( inc, 2, 5 ), f ) ) )
end


local function test_vtransform()
  local function m1( a, b, ... )
    return a+b, a*b
  end
  local function m2( ... )
    return select( '#', ... )
  end
  assert( returns( is_function, g.vtransform, m1 ) )
  assert( returns( resp( 3,5,7,12 ), compose( g.vtransform( m1, "x,y => x+y, x*y", m1 ), f ) ) )
  assert( returns( resp( 4,3,2,1,0 ), compose( g.vtransform( m2,m2,m2,m2,m2 ), f ) ) )
end


local function test_vinsert()
  assert( returns( is_function, g.vinsert, nil, "a" ) )
  assert( returns( resp( 1,2,3,4,"a","b" ), compose( g.vinsert( nil, "a", "b" ), f ) ) )
  assert( returns( resp( "a","b",1,2,3,4 ), compose( g.vinsert( 1, "a", "b" ), f ) ) )
  assert( returns( resp( 1,2,3,"a","b",4 ), compose( g.vinsert( -1, "a", "b" ), f ) ) )
  assert( returns( resp( 1,2,3,4,nil,"a","b" ), compose( g.vinsert( 6, "a", "b" ), f ) ) )
end


local function test_vreplace()
  assert( returns( is_function, g.vreplace, 1, "a" ) )
  assert( returns( resp( "a","b",3,4 ), compose( g.vreplace( 1, "a", "b" ), f ) ) )
  assert( returns( resp( 1,"a","b",4 ), compose( g.vreplace( 2, "a", "b" ), f ) ) )
  assert( returns( resp( 1,2,3,"a","b" ), compose( g.vreplace( -1, "a", "b" ), f ) ) )
  assert( returns( resp( 1,2,3,4,nil,"a","b" ), compose( g.vreplace( 6, "a", "b" ), f ) ) )
end


local function test_vreverse()
  assert( returns( is_function, g.vreverse ) )
  assert( returns( resp( 4,3,2,1 ), compose( g.vreverse(), f ) ) )
  assert( returns( resp( 2,1,3,4 ), compose( g.vreverse( 1, 2 ), f ) ) )
  assert( returns( resp( 1,4,3,2 ), compose( g.vreverse( 2 ), f ) ) )
  assert( returns( resp( 1,3,2,4 ), compose( g.vreverse( 2, -2 ), f ) ) )
  assert( returns( resp( 1,nil,nil,4,3,2 ), compose( g.vreverse( 2, 6 ), f ) ) )
end


local function test_vrotate()
  assert( returns( is_function, g.vrotate ) )
  assert( returns( resp( 4,1,2,3 ), compose( g.vrotate(), f ) ) )
  assert( returns( resp( 1,3,4,2 ), compose( g.vrotate( 2, 2 ), f ) ) )
  assert( returns( resp( 1,4,2,3 ), compose( g.vrotate( 2, -2 ), f ) ) )
  assert( returns( resp( 1,2,3,4 ), compose( g.vrotate( 2, 3 ), f ) ) )
  assert( returns( resp( 1,4,2,3 ), compose( g.vrotate( 2, 4 ), f ) ) )
  assert( returns( resp( 1,3,4,2 ), compose( g.vrotate( 2, -4 ), f ) ) )
end

