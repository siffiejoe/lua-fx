#!/usr/bin/lua

local fx = require( "fx" )()


local letters = { "a", "b", "c", "d", "e", "f" }
local numbers = { 1, 2, 3, 4, 3, 2, 1 }



local appending = curry( 2, function( n, state, ... )
  state[ #state+1 ] = select( n, ... )
  return state
end )

local function xduce( xform, red, init, ... )
  return reduce( xform( red ), init, ... )
end



local function test_fx()
  local ft = {}
  local x = fx( ft )
  assert( is_raweq( fx, x ) )
  assert( is( fx, ft ) )
  assert( none( is_eq( ft ) )( fx ) )
  assert( none( fx._ )( ft._ ) )
  assert( none( fx._ )( _G._ ) )
end


local function test_curry()
  local f = curry( 3, function( a, b, c )
    return a + b + c
  end )
  assert( is_function( f ) )
  assert( is( f( 1, 2, 3 ), 6 ) )
  assert( is( f( 1, 2, 3, 4 ), 6 ) )
  assert( is_function( f() ) )
  assert( is_function( f( 1 ) ) )
  assert( is_function( f( 1, 2 ) ) )
  assert( is( f( 1, 2 )( 3 ), 6 ) )
  assert( is( f( 1 )( 2, 3 ), 6 ) )
  assert( is( f( 1 )( 2 )( 3 ), 6 ) )
  assert( is( f()( 1, 2, 3 ), 6 ) )
  assert( is( f( 1 )()( 2, 3 ), 6 ) )
  local g = curry( 3, "x,y,z => x+y+z" )
  assert( is_function( g ) )
  assert( is_function( g( 1, 2 ) ) )
  assert( is( g( 1, 2 )( 3 ), 6 ) )
  local h = curry( 4, function( ... )
    return ...
  end )
  assert( is_function( h ) )
  assert( is_function( h( 1 ) ) )
  assert( is_function( h( 1, 2, 3 ) ) )
  assert( resp( 1,2,3,4 )( h( 1,2,3,4 ) ) )
  assert( resp( 1,2,3,4 )( h( fx._,2,3,4 )( 1 ) ) )
  assert( resp( 1,2,3,4 )( h( 1,2 )( fx._,4 )( 3 ) ) )
  assert( resp( 1,2,3,4 )( h( fx._,2 )( fx._,3 )( 1,4 ) ) )
  assert( resp( 1,2,3,4 )( h( fx._,2 )( 1,fx._ )( 3,4 ) ) )
  assert( resp( 1,2,3,4 )( h( fx._,fx._ )( 1,fx._,3 )( 2,4 ) ) )
  assert( resp( 1,2,3,4,5 )( h( fx._,2,3,4,5 )( 1 ) ) )
  assert( is_function( curry( 2, h( 1,2,3 ) )( 4 ) ) )
  assert( resp( 1,2,3,4,5 )( curry( 2, h( 1,2,3 ) )( 4 )( 5 ) ) )
  assert( resp( 1,2,3,4 )( curry( 1, h( 1,2 ) )( 3 )( 4 ) ) )
  assert( resp( 1,2,3,4 )( curry( 2, h( 1,2 ) )( 3 )( 4 ) ) )
  assert( resp( 1,2,3,4,5 )( curry( 2, h( fx._,2,3,4 ) )( 1 )( 5 ) ) )
  assert( resp( 1,2,3,4 )( curry( 1, h( fx._,2,3 ) )( 1 )( 4 ) ) )
  if _VERSION ~= "Lua 5.1" then
    local y = curry( 3, function( a, b, c )
      coroutine.yield( "yield" )
      return a + b + c
    end )
    assert( yields( y, { 1,2,3 }, "yield", {}, 6 ) )
    assert( yields( y( 1 ), { 2,3 }, "yield", {}, 6 ) )
  end
end


local function test_compose()
  local add = curry( 2, function( a, b ) return a + b end )
  local mul = curry( 2, function( a, b ) return a * b end )
  local f = compose( add( -3 ), mul( 5 ), add( 2 ) )
  local g = compose( mul( 5 ), add( 2 ) )
  local h = compose( add( 2 ) )
  local k = compose( add( 3 ), f )
  local a1 = add( 1 )
  local l = compose( a1, a1, a1, a1, a1, a1, a1, a1, a1, a1 )
  local m = compose( l, l, l, l, l, l, l, l, l, l, l, l, l, l, l, l,
                     l, l, l, l, l, l, l, l, l, l, l )
  assert( is_function( f ) )
  assert( returns( 22, f, 3 ) )
  assert( returns( 25, g, 3 ) )
  assert( returns( 5, h, 3 ) )
  assert( returns( 25, k, 3 ) )
  assert( returns( 273, m, 3 ) )
  if _VERSION ~= "Lua 5.1" then
    assert( resp( is_string, 4 )( debug.getupvalue( k, 1 ) ) )
    assert( resp( is_string, is_lt( 270 ) )( debug.getupvalue( m, 1 ) ) )
    local ymul = curry( 2, function( a, b )
      coroutine.yield( "ymul" )
      return a * b
    end )
    local yadd = function( a, b, c )
      coroutine.yield( "yadd" )
      return a + b + c
    end
    local y = compose( add( -3 ), ymul( 5 ), yadd )
    assert( yields( y, { 1,2,3 }, "yadd", {}, "ymul", {}, 27 ) )
  end
  local n = compose( "x,y => x-3, y+4", "a,b,c=>a+c,b+c" )
  assert( returns( resp( 1,9 ), n, 1, 2, 3 ) )
  assert( raises( is_like"bad argument #2", compose, a1, "x-", a1 ) )
  assert( raises( is_like"bad argument #2", compose, a1, "=>x-y", a1 ) )
  assert( raises( is_like"bad argument #2", compose, a1, " => x-y", a1 ) )
end


local function test_has()
  local is_table_module = has"insert,remove,concat,sort"
  local is_global_table = has"print|_VERSION;table###pairs"
  local is_indexable = has"__index"
  assert( is_table_module( table ) )
  assert( not is_table_module( string ) )
  assert( is_global_table( _G ) )
  assert( not is_global_table( string ) )
  assert( is_indexable( "" ) )
  assert( is_indexable( {} ) )
  assert( not is_indexable( false ) )
  assert( has"__add"( 12 ) )
  assert( not has"__add"( "" ) )
end


local function test_map()
  local function dp( v, w ) return 2 * v + w end
  assert( returns( is_eq{ 3,5,7,9,7,5,3 }, map, dp, numbers, 1 ) )
  local function dpy( v, w )
    coroutine.yield( "yield", v )
    return 2 * v + w
  end
  if _VERSION ~= "Lua 5.1" then
    assert( yields( map, { dpy,numbers,1 }, resp( "yield",1 ),
                         {}, resp( "yield",2 ),
                         {}, resp( "yield",3 ),
                         {}, resp( "yield",4 ),
                         {}, resp( "yield",3 ),
                         {}, resp( "yield",2 ),
                         {}, resp( "yield",1 ),
                         {}, is_eq{ 3,5,7,9,7,5,3 } ) )
  end
  local function inc( x, v ) return x+v end
  local Identity_meta = {}
  local function Identity( x )
    return setmetatable( { x=x }, Identity_meta )
  end
  Identity_meta["__map@fx"] = function( f, t, ... )
    return Identity( f( t.x, ... ) )
  end
  assert( returns( is_eq( Identity( 27 ) ),
                   map, inc, Identity( 17 ), 10 ) )
  assert( returns( is_function, map, dp ) )
  assert( returns( is_eq{ 3,5,7,9,7,5,3 }, xduce, map( dp ),
                   appending( 1 ), {}, numbers, 1 ) )
  assert( returns( is_eq{ 3,5,7,9,7,5,3 }, reduce,
                   map( dp, appending( 1 ) ), {}, numbers, 1 ) )
  assert( returns( is_eq{ 2,4,6,8,6,4,2 },
                   xduce, map"_,y => 2*y", appending( 1 ), {},
                   ipairs( numbers ) ) )
  if _VERSION ~= "Lua 5.1" then
    assert( yields( xduce, { map( dpy ),appending( 1 ),{},numbers,1 },
                    resp( "yield",1 ),
                    {}, resp( "yield",2 ),
                    {}, resp( "yield",3 ),
                    {}, resp( "yield",4 ),
                    {}, resp( "yield",3 ),
                    {}, resp( "yield",2 ),
                    {}, resp( "yield",1 ),
                    {}, is_eq{ 3,5,7,9,7,5,3 } ) )
  end
end


local function test_filter()
  local function rem( v, d, r )
    return v % d == r
  end
  assert( returns( is_eq{2,4,2}, filter, rem, numbers, 2, 0 ) )
  local function remy( v, d, r )
    coroutine.yield( "yield", v )
    return v % d == r
  end
  if _VERSION ~= "Lua 5.1" then
    assert( yields( filter, { remy,numbers,2,1 }, resp( "yield",1 ),
                            {}, resp( "yield",2 ),
                            {}, resp( "yield",3 ),
                            {}, resp( "yield",4 ),
                            {}, resp( "yield",3 ),
                            {}, resp( "yield",2 ),
                            {}, resp( "yield",1 ),
                            {}, is_eq{ 1,3,3,1 } ) )
  end
  assert( returns( is_function, filter, rem ) )
  assert( returns( is_eq{ 1,3,3,1 }, xduce, filter( rem ),
                   appending( 1 ), {}, numbers, 2, 1 ) )
  assert( returns( is_eq{ 1,3,3,1 }, reduce,
                   filter( rem, appending( 1 ) ), {}, numbers, 2, 1 ) )
  assert( returns( is_eq{ 2,4,2 }, xduce, filter"_,y => y%2==0",
                   appending( 2 ), {}, ipairs( numbers ) ) )
  if _VERSION ~= "Lua 5.1" then
    assert( yields( xduce,
                    { filter( remy ),appending( 1 ),{},numbers,2,1 },
                    resp( "yield", 1 ),
                    {}, resp( "yield",2 ),
                    {}, resp( "yield",3 ),
                    {}, resp( "yield",4 ),
                    {}, resp( "yield",3 ),
                    {}, resp( "yield",2 ),
                    {}, resp( "yield",1 ),
                    {}, is_eq{ 1,3,3,1 } ) )
  end
end


local function test_take()
  assert( returns( is_eq{ "a","b","c" }, take, 3, letters ) )
  local function lt4( v ) return v < 4 end
  assert( returns( is_eq{ 1,2,3 }, take, lt4, numbers ) )
  assert( returns( is_eq{ 1,2 }, take, "x,y => x<y", numbers, 3 ) )
  local function lt4y( v )
    coroutine.yield( "yield", v )
    return v < 4
  end
  if _VERSION ~= "Lua 5.1" then
    assert( yields( take, { lt4y,numbers }, resp( "yield",1 ),
                          {}, resp( "yield",2 ),
                          {}, resp( "yield",3 ),
                          {}, resp( "yield",4 ),
                          {}, is_eq{ 1,2,3 } ) )
  end
  assert( returns( is_function, take, 2 ) )
  assert( returns( is_function, take, lt4 ) )
  assert( returns( is_eq{ "a","b" }, reduce,
                   take( 2, appending( 1 ) ), {}, letters ) )
  assert( returns( is_eq{ "a","b" }, xduce, take( 2 ), appending( 1 ),
                   {}, letters ) )
  assert( returns( is_eq{ 1,2 }, xduce, take( "x,y => x<y" ),
                   appending( 1 ), {}, numbers, 3 ) )
  assert( returns( is_eq{ 1,2,3 }, xduce, take( "_,y => y<4" ),
                   appending( 2 ), {}, ipairs( numbers ) ) )
  local function ones() return 1 end
  assert( returns( is_eq{ 1,1,1 }, xduce, take( 3 ),
                   appending( 1 ), {}, ones ) )
  if _VERSION ~= "Lua 5.1" then
    assert( yields( xduce, { take( lt4y ),appending( 1 ),{},numbers },
                    resp( "yield", 1 ),
                    {}, resp( "yield",2 ),
                    {}, resp( "yield",3 ),
                    {}, resp( "yield",4 ),
                    {}, is_eq{ 1,2,3 } ) )
  end
end


local function test_drop()
  assert( returns( is_eq{ "d","e","f" }, drop, 3, letters ) )
  local function lt( x, y ) return x < y end
  assert( returns( is_eq{ 4,3,2,1 }, drop, lt, numbers, 4 ) )
  assert( returns( is_eq{ 4,3,2,1 }, drop, "x,y => x<y", numbers, 4 ) )
  local function lty( x, y )
    coroutine.yield( "yield", x )
    return x < y
  end
  if _VERSION ~= "Lua 5.1" then
    assert( yields( drop, { lty,numbers,4 }, resp( "yield",1 ),
                          {}, resp( "yield",2 ),
                          {}, resp( "yield",3 ),
                          {}, resp( "yield",4 ),
                          {}, is_eq{ 4,3,2,1 } ) )
  end
  assert( returns( is_function, drop, 2 ) )
  assert( returns( is_function, drop, lt ) )
  assert( returns( is_eq{ "e","f" }, xduce, drop( 4 ), appending( 1 ),
                   {}, letters ) )
  assert( returns( is_eq{ "e","f" }, reduce,
                   drop( 4, appending( 1 ) ), {}, letters ) )
  assert( returns( is_eq{ 4,3,2,1 }, xduce, drop( "x,y => x<y" ),
                   appending( 1 ), {}, numbers, 4 ) )
  assert( returns( is_eq{ 4,3,2,1 }, xduce, drop( "_,y => y<4" ),
                   appending( 2 ), {}, ipairs( numbers ) ) )
  if _VERSION ~= "Lua 5.1" then
    assert( yields( xduce, { drop( lty ),appending( 1 ),{},numbers,4 },
                    resp( "yield", 1 ),
                    {}, resp( "yield",2 ),
                    {}, resp( "yield",3 ),
                    {}, resp( "yield",4 ),
                    {}, is_eq{ 4,3,2,1 } ) )
  end
end


local function test_reduce()
  local function a( s, x, y )
    return s+x+y, x > 2 and fx._
  end
  local function b( s, _, x )
    return s+x, x > 2 and fx._
  end
  assert( returns( 9, reduce, a, 0, numbers, 1 ) )
  assert( returns( 6, reduce, b, 0, ipairs( numbers ) ) )
  assert( returns( 16, reduce, "s,x => s+x", 0, numbers ) )
  assert( returns( is_function, reduce, a ) )
  assert( returns( is_function, reduce, a, 0 ) )
  if _VERSION ~= "Lua 5.1" then
    local function y1( s, x, y )
      coroutine.yield( "yield", x )
      return s+x+y
    end
    assert( yields( reduce, { y1,0,numbers,1 }, resp( "yield",1 ),
                            {}, resp( "yield",2 ),
                            {}, resp( "yield",3 ),
                            {}, resp( "yield",4 ),
                            {}, resp( "yield",3 ),
                            {}, resp( "yield",2 ),
                            {}, resp( "yield",1 ),
                            {}, 23 ) )
    local function y2( s, x )
      coroutine.yield( "yield", x )
      return s+x
    end
    local function yiter( limit )
      limit = limit or 3
      return function( _, var )
        var = var + 1
        if var <= limit then
          coroutine.yield( "iyield", var )
          return var
        end
      end, nil, 0
    end
    assert( yields( reduce,
                    { y2,0,yiter( 3 ) }, resp( "iyield",1 ),
                    {}, resp( "yield",1 ),
                    {}, resp( "iyield", 2 ),
                    {}, resp( "yield", 2 ),
                    {}, resp( "iyield", 3 ),
                    {}, resp( "yield", 3 ),
                    {}, 6 ) )
  end
end

