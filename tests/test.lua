#!/usr/bin/lua

local fx = require( "fx" )()

local letters = { "a", "b", "c", "d", "e", "f" }
local numbers = { 1, 2, 3, 4, 3, 2, 1 }


local function yielding_iterator( limit )
  limit = limit or 3
  return function( st, var )
    var = var + 1
    if var <= limit then
      print( coroutine.yield( "iterator yield", st, var, 1 ) )
      print( coroutine.yield( "iterator yield", st, var, 2 ) )
      return var, var
    end
  end, {}, 0
end

local function resume_x_helper( th, i, status, ... )
  if status then
    print( ... )
    return resume_x_helper( th, i+1, coroutine.resume( th, "resume", i ) )
  else
    if not (...):match( "dead coroutine" ) then
      print( ... )
    end
  end
end

local function resume_x( f )
  local th = coroutine.create( f )
  return resume_x_helper( th, 2, coroutine.resume( th, "resume", 1 ) )
end


local function print_array( t, ... )
  print( t, "(len: "..#t..")", ... )
  local nt = {}
  for i, v in ipairs( t ) do
    nt[ i ] = tostring( v )
  end
  if next( nt ) == nil then
    print( "", "[]" )
  else
    print( "", "[ "..table.concat( nt, ", " ).." ]" )
  end
end


local function yielding( reducer )
  return function( state, ... )
    print( coroutine.yield( "transducer yield" ) )
    return reducer( state, ... )
  end
end

local applying = curry( 2, function( f, state, ... )
  f( ... )
  return state
end )

local appending = curry( 2, function( n, state, ... )
  state[ #state+1 ] = select( n, ... )
  return state
end )

local assigning = curry( 3, function( k, v, state, ... )
  state[ select( k, ... ) ] = select( v, ... )
  return state
end )

local function xduce( xform, red, init, ... )
  return reduce( xform( red ), init, ... )
end

local each = curry( 2, function( f, ft, ... )
  reduce( applying( f ), nil, ft, ... )
end )


local function __________()
  print( ("="):rep( 70 ) )
end


__________()

local ft = {}
print( "fx", fx( ft ), fx )
for k,v in pairs( ft ) do
  print( k, v )
end
__________()


print( "fx.curry() ..." )
print( fx._, _G._ )
local f = curry( 3, function( a, b, c )
  return a + b + c
end )
print( "curry", f( 1, 2, 3 ) )
print( "curry", f( 1, 2, 3, 4 ) )
print( "curry", f( 1, 2 )( 3 ) )
print( "curry", f( 1 )( 2, 3 ) )
print( "curry", f( 1 )( 2 )( 3 ) )
print( "curry", f()( 1, 2, 3 ) )
print( "curry", f( 1 )()( 2, 3 ) )
local p = curry( 6, print )
p( "curry", 1, 2, 3, 4, 5 )
p( fx._, 1, 2, 3, 4, 5 )( "curry" )
p( fx._, 1, 2 )( fx._, 3, 4 )( "curry", 5 )
p( fx._, 1, 2 )( "curry", 3 )( fx._, 5 )( 4 )
p( fx._, fx._, 2 )( "curry", fx._, 3 )( 1, 4, 5 )
p( "curry", 1, 2 )( fx._, 4, 5 )( 3 )
p( fx._, 1, 2, 3, 4, 5, 6 )( "curry" )
curry( 4, p( "curry", 1, 2, 3 ) )( 4 )( 5 )( 6 )( 7 )
curry( 1, p( "curry", 1, 2, 3 ) )( 4 )( 5 )
curry( 1, p( "curry", 1, 2, 3, 4 ) )( 5 )
curry( 4, p( fx._, 1, 2, 3, 4 ) )( "curry" )( 5 )( 6 )( 7 )
curry( 1, p( fx._, 1, 2, 3, 4 ) )( "curry" )( 5 )
local g = curry( 3, function( a, b, c )
  print( coroutine.yield( "function yield" ) )
  return a + b + c
end )
resume_x( function( ... )
  print( ... )
  print( "curry", g( 2, 4, 6 ) )
  print( "curry", g( 2, 4, 6, 8 ) )
  print( "curry", g( 2, 4 )( 6 ) )
  print( "curry", g( 2 )( 4, 6 ) )
  print( "curry", g( 2 )( 4 )( 6 ) )
  print( "curry", g()( 2, 4, 6 ) )
  print( "curry", g( 2 )()( 4, 6 ) )
  return "return"
end )
__________()


print( "fx.compose() ..." )
local add = curry( 2, function( a, b ) return a+b end )
local mul = curry( 2, function( a, b ) return a*b end )
local f = compose( add( -3 ), mul( 5 ), add( 2 ) )
local g = compose( mul( 5 ), add( 2 ) )
local h = compose( add( 2 ) )
local k = compose( add( 3 ), f )
local a1 = add( 1 )
local l = compose( a1, a1, a1, a1, a1, a1, a1, a1, a1, a1 )
local m = compose( l, l, l, l, l, l, l, l, l, l, l, l, l, l, l, l, l,
                   l, l, l, l, l, l, l, l, l, l )
print( "compose", f( 3 ) )
print( "compose", g( 3 ) )
print( "compose", h( 3 ) )
print( "compose", k( 3 ), debug.getupvalue( k, 1 ) )
print( "compose", m( 3 ), debug.getupvalue( m, 1 ) )
local ymul = curry( 2, function( a, b )
  print( coroutine.yield( "mul yield", 1 ) )
  return a*b
end )
local yadd = function( a, b, c )
  print( coroutine.yield( "add yield", 1 ) )
  return a+b+c
end
local k = compose( add( -3 ), ymul( 5 ), yadd )
resume_x( function( ... )
  print( ... )
  print( "compose", k( 1, 2, 3 ) )
  return "return"
end )
local n = compose( "x,y => x-3, y+4", "a,b,c=>a+c,b+c" )
print( "compose", n( 5, 7, 9 ) )
print( pcall( compose, add( 1 ), "x-", add( 1 ) ) )
print( pcall( compose, add( 1 ), "=>x-y", add( 1 ) ) )
print( pcall( compose, add( 1 ), " => x-y", add( 1 ) ) )
__________()


print( "fx.has() ..." )
local is_table = has"insert,remove,concat,sort"
local is_G = has"print|_VERSION;table###pairs"
local has_index = has"__index"
print( is_table( table ), is_table( string ) )
print( is_G( _G ), is_G( string ) )
print( has_index( "" ), has_index( {} ), has_index( false ) )
print( has"__add"( 12 ), has"__add"( "" ) )
__________()


print( "fx.map() ..." )
local t = { 1, 2, 3, 6, 8, 12, 14 }
local function doublep( v, w ) return 2*v+w end
local function double2( _, v ) return 2*v end
print_array( map( doublep, t, 1 ) )
local function doublepy( v, w )
  print( coroutine.yield( "function yield" ) )
  return 2*v+w
end
local function double2y( _, v )
  print( coroutine.yield( "function yield" ) )
  return 2*v
end
resume_x( function( ... )
  print( ... )
  print_array( map( doublepy, t, 2 ) )
  return "return"
end )
local function inc( x, v ) return x+v end
local Identity_meta = {}
local function Identity( x )
  return setmetatable( { x }, Identity_meta )
end
Identity_meta["__map@fx"] = function( f, t, ... )
  return Identity( f( t[ 1 ], ... ) )
end
function Identity_meta:__tostring()
  return "Identity( "..tostring( self[ 1 ] ).." )"
end
print( map( inc, Identity( 17 ), 10 ) )
print_array( xduce( map( doublep ), appending( 1 ), {}, t, 1 ) )
print_array( xduce( map( double2 ), appending( 1 ), {}, ipairs( t ) ) )
local ydp = compose( map( doublepy ), yielding )
resume_x( function( ... )
  print( ... )
  print_array( xduce( ydp, appending( 1 ), {}, t, 1 ) )
  return "return"
end )
__________()


print( "fx.filter() ..." )
local t = { 1, 2, 3, 4, 5 }
local function hasremainder( v, d, r )
  return v % d == r
end
local function isodd2( _, v )
  return v % 2 == 1
end
print_array( filter( hasremainder, t, 2, 0 ) )
local function hasremaindery( v, d, r )
  print( coroutine.yield( "function yield" ) )
  return v % d == r
end
local function isodd2y( _, v )
  print( coroutine.yield( "function yield" ) )
  return v % 2 == 1
end
resume_x( function( ... )
  print( ... )
  print_array( filter( hasremaindery, t, 2, 1 ) )
  return "return"
end )
print_array( xduce( filter( hasremainder ), appending( 1 ), {}, t, 2, 0 ) )
print_array( xduce( filter( isodd2 ), appending( 2 ), {}, ipairs( t ) ) )
local yhr = compose( filter( hasremaindery ), yielding )
local yio = compose( filter( isodd2y ), yielding )
resume_x( function( ... )
  print( ... )
  print_array( xduce( yhr, appending( 1 ), {}, t, 2, 1 ) )
  return "return"
end )
resume_x( function( ... )
  print( ... )
  print_array( xduce( yio, appending( 2 ), {}, yielding_iterator( 3 ) ) )
  return "return"
end )
__________()


print( "fx.take() ..." )
local function lt_4( _, v ) return v < 4 end
local function lt_y( v, x )
  print( coroutine.yield( "function yield" ) )
  return v < x
end
print_array( take( 3, letters ) )
resume_x( function( ... )
  print( ... )
  print_array( take( lt_y, numbers, 4 ) )
  return "return"
end )
local function ones() return 1 end
print_array( xduce( take( 3 ), appending( 1 ), {}, letters ) )
print_array( xduce( take( lt_4 ), appending( 2 ), {}, ipairs( numbers ) ) )
print_array( xduce( take( 3 ), appending( 1 ), {}, ones ) )
local take3y = compose( yielding, take( 3 ), yielding )
local takelty = compose( take( lt_4 ), yielding )
resume_x( function( ... )
  print( ... )
  print_array( xduce( take3y, appending( 1 ), {}, letters ) )
  return "return"
end )
resume_x( function( ... )
  print( ... )
  print_array( xduce( takelty, appending( 2 ), {}, yielding_iterator( 5 ) ) )
  return "return"
end )
__________()


print( "fx.drop() ..." )
print_array( drop( 3, letters ) )
resume_x( function( ... )
  print( ... )
  print_array( drop( lt_y, numbers, 4 ) )
  return "return"
end )
print_array( xduce( drop( 3 ), appending( 1 ), {}, letters ) )
print_array( xduce( drop( lt_4 ), appending( 2 ), {}, ipairs( numbers ) ) )
local drop3y = compose( drop( 3 ), yielding )
local droplty = compose( drop( lt_4 ), yielding )
resume_x( function( ... )
  print( ... )
  print_array( xduce( drop3y, appending( 1 ), {}, letters ) )
  return "return"
end )
resume_x( function( ... )
  print( ... )
  print_array( xduce( droplty, appending( 2 ), {}, yielding_iterator( 5 ) ) )
  return "return"
end )
__________()


print( "fx.reduce() ..." )
local function add( s, x, y )
  return s+x+y, x > 2 and fx._
end
local function add2( s, _, x )
  return s + x, x > 2 and fx._
end
print( "sum", reduce( add, 0, { 1, 2, 3, 4 }, 5 ) )
print( "sum", reduce( add2, 0, ipairs( { 1,2,3,4 } ) ) )
local function yielding_add( s, x, y )
  print( coroutine.yield( "function yield", "s", s, "x", x, 1 ) )
  print( coroutine.yield( "function yield", "s", s, "x", x, 2 ) )
  return s + x + y
end
local function yielding_add2( s, _, x )
  print( coroutine.yield( "function yield", "s", s, "x", x, 1 ) )
  print( coroutine.yield( "function yield", "s", s, "x", x, 2 ) )
  return s + x
end
resume_x( function( ... )
  print( ... )
  print( "sum", reduce( yielding_add, 0, { 1,2,3 }, 5 ) )
  return "return"
end )
resume_x( function( ... )
  print( ... )
  print( "sum", reduce( yielding_add2, 0, yielding_iterator( 3 ) ) )
  return "return"
end )
__________()


print( "Simulating icollect() and collect() ..." )
local icollect = curry( 3, function( t, n, f, s, var )
  return reduce( appending( n ), t, f, s, var )
end )
local collect = curry( 4, function( t, i, j, f, s, var )
  return reduce( assigning( i, j ), t, f, s, var )
end )
print( "keys()" )
local t = icollect( {}, 1, pairs{ "a", "b", "c" } )
each( print, ipairs( t ) )
print( "values()" )
t = icollect( {}, 2, pairs{ "a", "b", "c" } )
each( print, ipairs( t ) )
print( "invert()" )
t = collect( {}, 2, 1, pairs{ "a", "b", "c" } )
each( print, pairs( t ) )
__________()

