#!/usr/bin/lua

local fx = require( "fx" )()
local g = require( "fx.glue" )


local failed = 0

local function is( ... )
  local t = { n = select( '#', ... ), ... }
  return function( ... )
    local ok = select( '#', ... ) == t.n
    for i = 1, t.n do
      ok = ok and select( i, ... ) == t[ i ]
    end
    if ok then
      print( "[ ok ]", ... )
    else
      print( "[FAIL]", ... )
      failed = failed + 1
    end
    return ...
  end
end


local function e()
end

local function f()
  return 1, 2, 3, 4
end

local function inc( x )
  return (x or 0)+1
end

local function m1( a, b, ... )
  print( "m1", a, b, ... )
  return a+b, a*b
end

local function m2( ... )
  print( "m2", ... )
  return select( '#', ... )
end


print( "vmap" )
is( 2, 3, 4, 5 )( compose( g.vmap( inc ), f )() )
is()( compose( g.vmap( inc ), e )() )
is( 1, 3, 4, 5 )( compose( g.vmap( inc, 2 ), f )() )
is( 1, 3, 4, 4 )( compose( g.vmap( inc, 2, -2 ), f )() )
is( 1, 3, 4, 5, 1 )( compose( g.vmap( inc, 2, 5 ), f )() )

print( "vtransform" )
is( 3, 5, 7, 12 )( compose( g.vtransform( m1, m1, m1 ), f )() )
is( 4, 3, 2, 1, 0 )( compose( g.vtransform( m2,m2,m2,m2,m2 ), f )() )

print( "vdup" )
is( 1,1,2,3,4 )( compose( g.vdup( 1 ), f )() )
is( 1,2,2,3,4 )( compose( g.vdup( 2 ), f )() )
is( 1,2,3,2,3,4 )( compose( g.vdup( 2, 2 ), f )() )
is( 1,2,3,4,4 )( compose( g.vdup( -1 ), f )() )
is( 1,2,3,4,nil,nil )( compose( g.vdup( 5 ), f )() )
is( 1,2,3,4,nil,4,nil )( compose( g.vdup( -1, 2 ), f )() )

print( "vinsert" )
is( 1,2,3,4,"a","b" )( compose( g.vinsert( nil, "a", "b" ), f )() )
is( "a","b",1,2,3,4 )( compose( g.vinsert( 1, "a", "b" ), f )() )
is( 1,2,3,"a","b",4 )( compose( g.vinsert( -1, "a", "b" ), f )() )
is( 1,2,3,4,nil,"a","b" )( compose( g.vinsert( 6, "a", "b" ), f )() )

print( "vremove" )
is( 1,2,3 )( compose( g.vremove( -1 ), f )() )
is( 1,2,3 )( compose( g.vremove( -1, 2 ), f )() )
is( 1,2,3,4 )( compose( g.vremove( 5, 2 ), f )() )
is( 3,4 )( compose( g.vremove( 1, 2 ), f )() )
is( 1,4 )( compose( g.vremove( 2, 2 ), f )() )

print( "vreplace" )
is( "a","b",3,4 )( compose( g.vreplace( 1, "a", "b" ), f )() )
is( 1,"a","b",4 )( compose( g.vreplace( 2, "a", "b" ), f )() )
is( 1,2,3,"a","b" )( compose( g.vreplace( -1, "a", "b" ), f )() )
is( 1,2,3,4,nil,"a","b" )( compose( g.vreplace( 6, "a", "b" ), f )() )

print( "vreverse" )
is( 4,3,2,1 )( compose( g.vreverse(), f )() )
is( 2,1,3,4 )( compose( g.vreverse( 1, 2 ), f )() )
is( 1,4,3,2 )( compose( g.vreverse( 2 ), f )() )
is( 1,3,2,4 )( compose( g.vreverse( 2, -2 ), f )() )
is( 1,nil,nil,4,3,2 )( compose( g.vreverse( 2, 6 ), f )() )

print( "vrotate" )
is( 4,1,2,3 )( compose( g.vrotate(), f )() )
is( 1,3,4,2 )( compose( g.vrotate( 2, 2 ), f )() )
is( 1,4,2,3 )( compose( g.vrotate( 2, -2 ), f )() )
is( 1,2,3,4 )( compose( g.vrotate( 2, 3 ), f )() )
is( 1,4,2,3 )( compose( g.vrotate( 2, 4 ), f )() )
is( 1,3,4,2 )( compose( g.vrotate( 2, -4 ), f )() )

print( "vtake" )
is()( compose( g.vtake( 0 ), f )() )
is( 1 )( compose( g.vtake( 1 ), f )() )
is( 1,2 )( compose( g.vtake( 2 ), f )() )
is( 1,2,3 )( compose( g.vtake( -2 ), f )() )
is( 1,2,3,4,nil )( compose( g.vtake( 5 ), f )() )

print( "vnot" )
is( false,2,3,4 )( compose( g.vnot( 1 ), f )() )
is( 1,false,3,4 )( compose( g.vnot( 2 ), f )() )
is( 1,2,3,false )( compose( g.vnot( -1 ), f )() )
is( 1,2,3,4,true )( compose( g.vnot( 5 ), f )() )

if failed > 0 then
  error( failed.." failed test cases!", 0 )
end

