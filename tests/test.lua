#!/usr/bin/lua

local fx = require( "fx" )


local letters = { "a", "b", "c", "d", "e", "f", "g", n=6 }
local numbers = { 1, 2, 3, 4, 3, 2, 1, 0, n=7 }
local numbers2 = { 1, 2, 3, 4, 3, 2, 1, 0 }
local function ones() return 1 end


local function shift( xf )
  return fx.compose( fx.map"_, ... => ...", xf )
end

local function icollect_helper( t, i, n, f, s, var_1, ... )
  if var_1 ~= nil then
    local j = i + 1
    t[ j ] = select( n, var_1, ... )
    return icollect_helper( t, j, n, f, s, f( s, var_1 ) )
  end
  t.n = i
  return t, i
end

local function icollect( n, f, s, var )
  return icollect_helper( {}, 0, n, f, s, f( s, var ) )
end



local function test_fx()
  local ft = {}
  local x = fx( ft )
  assert( is_raweq( fx, x ) )
  assert( is( fx, ft ) )
  assert( none( is_eq( ft ) )( fx ) )
  assert( none( fx._ )( ft._ ) )
end


local function test_curry()
  local f = fx.curry( 3, function( a, b, c )
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
  local g = fx.curry( 3, "x,y,z => x+y+z" )
  assert( is_function( g ) )
  assert( is_function( g( 1, 2 ) ) )
  assert( is( g( 1, 2 )( 3 ), 6 ) )
  local h = fx.curry( 4, function( ... )
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
  assert( is_function( fx.curry( 2, h( 1,2,3 ) )( 4 ) ) )
  assert( resp( 1,2,3,4,5 )( fx.curry( 2, h( 1,2,3 ) )( 4 )( 5 ) ) )
  assert( resp( 1,2,3,4 )( fx.curry( 1, h( 1,2 ) )( 3 )( 4 ) ) )
  assert( resp( 1,2,3,4 )( fx.curry( 2, h( 1,2 ) )( 3 )( 4 ) ) )
  assert( resp( 1,2,3,4,5 )( fx.curry( 2, h( fx._,2,3,4 ) )( 1 )( 5 ) ) )
  assert( resp( 1,2,3,4 )( fx.curry( 1, h( fx._,2,3 ) )( 1 )( 4 ) ) )
  if _VERSION ~= "Lua 5.1" then
    local y = fx.curry( 3, function( a, b, c )
      coroutine.yield( "yield" )
      return a + b + c
    end )
    assert( yields( y, { 1,2,3 }, "yield", {}, 6 ) )
    assert( yields( y( 1 ), { 2,3 }, "yield", {}, 6 ) )
  end
end


local function test_compose()
  local add = fx.curry( 2, function( a, b ) return a + b end )
  local mul = fx.curry( 2, function( a, b ) return a * b end )
  local f = fx.compose( add( -3 ), mul( 5 ), add( 2 ) )
  local g = fx.compose( mul( 5 ), add( 2 ) )
  local h = fx.compose( add( 2 ) )
  local k = fx.compose( add( 3 ), f )
  local a1 = add( 1 )
  local l = fx.compose( a1, a1, a1, a1, a1, a1, a1, a1, a1, a1 )
  local m = fx.compose( l, l, l, l, l, l, l, l, l, l, l, l, l, l, l, l,
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
    local ymul = fx.curry( 2, function( a, b )
      coroutine.yield( "ymul" )
      return a * b
    end )
    local yadd = function( a, b, c )
      coroutine.yield( "yadd" )
      return a + b + c
    end
    local y = fx.compose( add( -3 ), ymul( 5 ), yadd )
    assert( yields( y, { 1,2,3 }, "yadd", {}, "ymul", {}, 27 ) )
  end
  local n = fx.compose( "x,y => x-3, y+4", "a,b,c=>a+c,b+c" )
  assert( returns( resp( 1,9 ), n, 1, 2, 3 ) )
  local m = fx.compose( "_, ... => ..." )
  assert( returns( resp( 2,3 ), m, 1, 2, 3 ) )
  assert( returns( is_function, fx.compose, a1, "=>x-y", a1 ) )
  assert( returns( is_function, fx.compose, a1, " => x-y", a1 ) )
  assert( raises( is_like"bad argument #2", fx.compose, a1, "x-", a1 ) )
  assert( raises( is_like"bad argument #2", fx.compose, a1, "a.b => a", a1 ) )
  assert( raises( is_like"bad argument #2", fx.compose, a1, "a,b => do return a end", a1 ) )
end


local function test_has()
  local is_table_module = fx.has"insert,remove,concat,sort"
  local is_global_table = fx.has"print|_VERSION;table###pairs"
  local is_indexable = fx.has"__index"
  assert( is_table_module( table ) )
  assert( not is_table_module( string ) )
  assert( is_global_table( _G ) )
  assert( not is_global_table( string ) )
  assert( is_indexable( "" ) )
  assert( is_indexable( {} ) )
  assert( not is_indexable( false ) )
  assert( fx.has"__add"( 12 ) )
  assert( not fx.has"__add"( {} ) )
  if _VERSION < "Lua 5.4" then
    assert( not fx.has"__add"( "" ) )
  else
    assert( fx.has"__add"( "" ) )
  end
end


local function test_map()
  local function dp( v, w )
    return 2 * v + w
  end
  local Identity_meta = {}
  local function Identity( x )
    return setmetatable( { x=x }, Identity_meta )
  end
  Identity_meta.__index = {
    map = function( self, f, ... )
      return Identity( f( self.x, ... ) )
    end
  }
  -- fx.map is curried
  assert( returns( is_function, fx.map, dp ) )
  -- fx.map works on normal sequences and .n sequences
  assert( returns( is_eq{ 3,5,7,9,7,5,3,n=7 }, fx.map, dp, numbers, 1 ) )
  assert( returns( is_eq{ 3,5,7,9,7,5,3,1,n=8 }, fx.map, dp, numbers2, 1 ) )
  -- fx.map accepts string lambdas
  assert( returns( is_eq{ 3,5,7,9,7,5,3,n=7 }, fx.map, "v,w => 2*v+w", numbers, 1 ) )
  -- fx.map works on functors
  assert( returns( is_eq( Identity( 44 ) ), fx.map, dp, Identity( 17 ), 10 ) )
  -- fx.map works as a transducer
  assert( returns( is_eq{ 3,5,7,9,7,5,3,n=7 }, fx.into, {}, fx.map( dp ), numbers, 1 ) )
  assert( returns( is_eq{ 3,5,7,9,7,5,3,1,n=8 }, fx.into, {}, fx.map"_,y => 2*y+1", ipairs( numbers ) ) )
  -- fx.map works on iterators
  assert( returns( is_eq{ 3,5,7,9,7,5,3,1,n=8 }, icollect, 2, fx.map( "_,y => 2*y+1", ipairs( numbers ) ) ) )
end


local function test_filter()
  local function rem( v, d, r ) return v % d == r end
  -- fx.filter is curried
  assert( returns( is_function, fx.filter, rem ) )
  -- fx.filter works on normal sequences and .n sequences
  assert( returns( is_eq{ 2,4,2,n=3 }, fx.filter, rem, numbers, 2, 0 ) )
  assert( returns( is_eq{ 2,4,2,0,n=4 }, fx.reject, rem, numbers2, 2, 1 ) )
  -- fx.filter accepts string lambdas
  assert( returns( is_eq{ 2,4,2,n=3 }, fx.filter, "v,d,r => v%d == r", numbers, 2, 0 ) )
  -- fx.filter works as a transducer
  assert( returns( is_eq{ 1,3,3,1,n=4 }, fx.into, {}, fx.filter( rem ), numbers, 2, 1 ) )
  assert( returns( is_eq{ 1,3,3,1,n=4 }, fx.into, {}, shift( fx.filter"v => v%2 == 1" ), ipairs( numbers ) ) )
  -- fx.filter works on iterators
  assert( returns( is_eq{ 2,4,2,0,n=4 }, icollect, 2, fx.filter( "_,y => y%2 == 0", ipairs( numbers ) ) ) )
end


local function test_take()
  local function lt4( v ) return v < 4 end
  -- fx.take is curried
  assert( returns( is_function, fx.take, 2 ) )
  assert( returns( is_function, fx.take, lt4 ) )
  -- fx.take works on normal sequences and .n sequences
  assert( returns( is_eq{ "a","b","c",n=3 }, fx.take, 3, letters ) )
  assert( returns( is_eq{ 1,2,3,n=3 }, fx.take, 3, numbers2 ) )
  assert( returns( is_eq{ 1,2,3,n=3 }, fx.take, lt4, numbers ) )
  assert( returns( is_eq{ 1,2,3,n=3 }, fx.take, lt4, numbers2 ) )
  -- fx.take accepts string lambdas
  assert( returns( is_eq{ 1,2,n=2 }, fx.take, "x,y => x < y", numbers, 3 ) )
  -- fx.take works as a transducer
  assert( returns( is_eq{ "a","b",n=2 }, fx.into, {}, fx.take( 2 ), letters ) )
  assert( returns( is_eq{ "a","b",n=2 }, fx.into, {}, shift( fx.take( 2 ) ), ipairs( letters ) ) )
  assert( returns( is_eq{ 1,2,n=2 }, fx.into, {}, fx.take"x,y => x < y", numbers, 3 ) )
  assert( returns( is_eq{ 1,2,n=2 }, fx.into, {}, shift( fx.take"v => v < 3" ), ipairs( numbers ) ) )
  -- fx.take works as a transducer on infinite sequences
  assert( returns( is_eq{ 1,1,n=2 }, fx.into, {}, fx.take( 2 ), ones ) )
  -- fx.take works on iterators
  assert( returns( is_eq{ 1,2,3,n=3 }, icollect, 2, fx.take( 3, ipairs( numbers ) ) ) )
  assert( returns( is_eq{ 1,2,3,n=3 }, icollect, 2, fx.take( "_,x => x < 4", ipairs( numbers ) ) ) )
  -- fx.take works on infinite iterators
  assert( returns( is_eq{ 1,1,1,n=3 }, icollect, 1, fx.take( 3, ones ) ) )
end


local function test_drop()
  local function lt( x, y ) return x < y end
  -- fx.drop is curried
  assert( returns( is_function, fx.drop, 2 ) )
  assert( returns( is_function, fx.drop, lt ) )
  -- fx.drop work on normal sequences and .n sequences
  assert( returns( is_eq{ "d","e","f",n=3 }, fx.drop, 3, letters ) )
  assert( returns( is_eq{ 4,3,2,1,0,n=5 }, fx.drop, 3, numbers2 ) )
  assert( returns( is_eq{ 4,3,2,1,n=4 }, fx.drop, lt, numbers, 4 ) )
  assert( returns( is_eq{ 4,3,2,1,0,n=5 }, fx.drop, lt, numbers2, 4 ) )
  -- fx.drop accepts string lambdas
  assert( returns( is_eq{ 4,3,2,1,n=4 }, fx.drop, "x,y => x<y", numbers, 4 ) )
  -- fx.drop works as a transducer
  assert( returns( is_eq{ "e","f",n=2 }, fx.into, {}, fx.drop( 4 ), letters ) )
  assert( returns( is_eq{ "e","f","g",n=3 }, fx.into, {}, shift( fx.drop( 4 ) ), ipairs( letters ) ) )
  assert( returns( is_eq{ 4,3,2,1,n=4 }, fx.into, {}, fx.drop"x,y => x < y", numbers, 4 ) )
  assert( returns( is_eq{ 4,3,2,1,0,n=5 }, fx.into, {}, shift( fx.drop"v => v < 4" ), ipairs( numbers ) ) )
  -- fx.drop works on iterators
  assert( returns( is_eq{ 4,3,2,1,0,n=5 }, icollect, 2, fx.drop( 3, ipairs( numbers ) ) ) )
  assert( returns( is_eq{ 4,3,2,1,0,n=5 }, icollect, 2, fx.drop( "_,x => x < 4", ipairs( numbers ) ) ) )
end


local function test_reduce()
  local function a( s, x, y )
    return s+x+y, x > 2 and fx._
  end
  local function b( s, _, x )
    return s+x, x > 2 and fx._
  end
  local function c( s, x, y )
    return s+x+y
  end
  local tx = {
    init = function( self ) self.x = 2 end,
    step = function( self, state, x, y )
      return state + x + y + self.x
    end,
    finish = function( _, state ) return state + 1 end,
  }
  -- fx.reduce is curried
  assert( returns( is_function, fx.reduce, a ) )
  assert( returns( is_function, fx.reduce, a, 0 ) )
  -- fx.reduce works on normal sequences and .n sequences
  assert( returns( 23, fx.reduce, c, 0, numbers, 1 ) )
  assert( returns( 9, fx.reduce, a, 0, numbers2, 1 ) )
  -- fx.reduce works on normal sequences and .n sequences with transformers
  assert( returns( 38, fx.reduce, tx, 0, numbers, 1 ) )
  assert( returns( 41, fx.reduce, tx, 0, numbers2, 1 ) )
  -- fx.reduce works on iterators
  assert( returns( 6, fx.reduce, b, 0, ipairs( numbers ) ) )
  assert( returns( 52, fx.reduce, c, 0, ipairs( numbers ) ) )
  -- fx.reduce works on iterators with transformers
  assert( returns( 69, fx.reduce, tx, 0, ipairs( numbers2 ) ) )
  -- fx.reduce accepts string lambdas
  assert( returns( 16, fx.reduce, "s,x => s+x", 0, numbers ) )
end


local function test_transduce()
  local tx = {
    init = function( self ) self.x = 2 end,
    step = function( self, state, x, y )
      return state + x + y + self.x
    end,
    finish = function( _, state ) return state + 1 end,
  }
  local function rd( state, x, y )
    return state + x + y
  end
  local even = fx.filter"k => k % 2 == 0"
  -- fx.transduce is curried
  assert( returns( is_function, fx.transduce, even ) )
  assert( returns( is_function, fx.transduce, even, tx ) )
  -- fx.transduce works on normal sequences and .n sequences
  assert( returns( 11, fx.transduce, even, rd, 0, numbers, 1 ) )
  assert( returns( 12, fx.transduce, even, rd, 0, numbers2, 1 ) )
  -- fx.transduce works on normal sequences and .n sequences with transformers
  assert( returns( 18, fx.transduce, even, tx, 0, numbers, 1 ) )
  assert( returns( 21, fx.transduce, even, tx, 0, numbers2, 1 ) )
  -- fx.transduce works on iterators
  assert( returns( 28, fx.transduce, even, rd, 0, ipairs( numbers ) ) )
  -- fx.transduce works on iterators with transformers
  assert( returns( 37, fx.transduce, even, tx, 0, ipairs( numbers2 ) ) )
  -- fx.transduce accepts string lambdas
  assert( returns( 8, fx.transduce, even, "s,x => s+x", 0, numbers ) )
end


local function test_into()
  local even = fx.filter"k => k % 2 == 0"
  -- fx.into is curried
  assert( returns( is_function, fx.into, {} ) )
  assert( returns( is_function, fx.into, {}, even ) )
  -- fx.into works on normal sequences and .n sequences
  assert( returns( is_eq{ 2,4,2,n=3 }, fx.into, {}, even, numbers ) )
  assert( returns( is_eq{ 2,4,2,0,n=4 }, fx.into, {}, even, numbers2 ) )
  assert( returns( is_eq{ 2,4,2,n=3 }, fx.into, { n=0 }, even, numbers ) )
  assert( returns( is_eq{ 2,4,2,0,n=4 }, fx.into, { n=0 }, even, numbers2 ) )
  -- fx.into works on iterators
  assert( returns( is_eq{ 2,4,6,8,n=4 }, fx.into, {}, even, ipairs( numbers ) ) )
  assert( returns( is_eq{ 2,4,6,8,n=4 }, fx.into, {}, even, ipairs( numbers2 ) ) )
  -- fx.into works on non-empty destinations
  assert( returns( is_eq{ nil,2,4,2,n=4 }, fx.into, { n=1 }, even, numbers ) )
  assert( returns( is_eq{ nil,2,4,2,0,n=5 }, fx.into, { n=1 }, even, numbers2 ) )
  assert( returns( is_eq{ 1,2,4,2,n=4 }, fx.into, { 1,n=1 }, even, numbers ) )
  assert( returns( is_eq{ 1,2,4,2,0,n=5 }, fx.into, { 1,n=1 }, even, numbers2 ) )
end


local function test_all()
  local a, b = { 1, 2, 3, n=3 }, { 1, 2, 3 }
  local function lt( x, y ) return x < y end
  -- fx.all is curried
  assert( returns( is_function, fx.all, lt ) )
  -- fx.all works on normal sequences and .n sequences
  assert( returns( true, fx.all, lt, a, 4 ) )
  assert( returns( true, fx.all, lt, b, 4 ) )
  assert( returns( false, fx.all, lt, numbers, 4 ) )
  assert( returns( false, fx.all, lt, numbers2, 4 ) )
  -- fx.all accepts string lambdas
  assert( returns( true, fx.all, "x,y => x < y", a, 4 ) )
  -- fx.all works as a transducer
  assert( returns( is_eq{ true,n=1 }, fx.into, {}, fx.all( lt ), a, 4 ) )
  assert( returns( is_eq{ true,n=1 }, fx.into, {}, shift( fx.all"v => v < 4" ), ipairs( a ) ) )
  assert( returns( is_eq{ false,n=1 }, fx.into, {}, fx.all( lt ), numbers, 4 ) )
  assert( returns( is_eq{ false,n=1 }, fx.into, {}, shift( fx.all"v => v < 4" ), ipairs( numbers ) ) )
  -- fx.all works as a transducer on infinite sequences
  assert( returns( { false,n=1 }, fx.into, {}, fx.all"v => v > 2", ones ) )
  -- fx.all works on iterators
  assert( returns( true, fx.all, "_,v => v < 4", ipairs( a ) ) )
  assert( returns( false, fx.all, "_,v => v < 4", ipairs( numbers ) ) )
  -- fx.all works on infinite iterators
  assert( returns( false, fx.all, "v => v > 2", ones ) )
end


local function test_none()
  local a, b = { 1, 2, 3, n=3 }, { 1, 2, 3 }
  local function gt( x, y ) return x > y end
  -- fx.none is curried
  assert( returns( is_function, fx.none, gt ) )
  -- fx.none works on normal sequences and .n sequences
  assert( returns( true, fx.none, gt, a, 3 ) )
  assert( returns( true, fx.none, gt, b, 3 ) )
  assert( returns( false, fx.none, gt, numbers, 3 ) )
  assert( returns( false, fx.none, gt, numbers2, 3 ) )
  -- fx.none accepts string lambdas
  assert( returns( true, fx.none, "x,y => x > y", a, 3 ) )
  -- fx.none works as a transducer
  assert( returns( is_eq{ true,n=1 }, fx.into, {}, fx.none( gt ), a, 3 ) )
  assert( returns( is_eq{ true,n=1 }, fx.into, {}, shift( fx.none"v => v > 3" ), ipairs( a ) ) )
  assert( returns( is_eq{ false,n=1 }, fx.into, {}, fx.none( gt ), numbers, 3 ) )
  assert( returns( is_eq{ false,n=1 }, fx.into, {}, shift( fx.none"v => v > 3" ), ipairs( numbers ) ) )
  -- fx.none works as a transducer on infinite sequences
  assert( returns( { false,n=1 }, fx.into, {}, fx.none"v => v < 2", ones ) )
  -- fx.none works on iterators
  assert( returns( true, fx.none, "_,v => v > 3", ipairs( a ) ) )
  assert( returns( false, fx.none, "_,v => v > 3", ipairs( numbers ) ) )
  -- fx.none works on infinite iterators
  assert( returns( false, fx.none, "v => v < 2", ones ) )
end


local function test_any()
  local a, b = { 1, 2, 3, n=3 }, { 1, 2, 3 }
  local function eq( x, y )
    return x == y
  end
  -- fx.any is curried
  assert( returns( is_function, fx.any, eq ) )
  -- fx.any works on normal sequences and .n sequences
  assert( returns( false, fx.any, eq, a, 4 ) )
  assert( returns( false, fx.any, eq, b, 4 ) )
  assert( returns( true, fx.any, eq, numbers, 4 ) )
  assert( returns( true, fx.any, eq, numbers2, 4 ) )
  -- fx.any accepts string lambdas
  assert( returns( true, fx.any, "x,y => x == y", a, 3 ) )
  -- fx.any works as a transducer
  assert( returns( is_eq{ false,n=1 }, fx.into, {}, fx.any( eq ), a, 4 ) )
  assert( returns( is_eq{ false,n=1 }, fx.into, {}, shift( fx.any"v => v == 4" ), ipairs( a ) ) )
  assert( returns( is_eq{ true,n=1 }, fx.into, {}, fx.any( eq ), numbers, 4 ) )
  assert( returns( is_eq{ true,n=1 }, fx.into, {}, shift( fx.any"v => v == 4" ), ipairs( numbers ) ) )
  -- fx.any works as a transducer on infinite sequences
  assert( returns( { true,n=1 }, fx.into, {}, fx.any"v => v < 2", ones ) )
  -- fx.any works on iterators
  assert( returns( false, fx.any, "_,v => v == 4", ipairs( a ) ) )
  assert( returns( true, fx.any, "_,v => v == 4", ipairs( numbers ) ) )
  -- fx.any works on infinite iterators
  assert( returns( true, fx.any, "v => v < 2", ones ) )
end

