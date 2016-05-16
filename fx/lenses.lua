local assert = assert
local _G = assert( _G )
local pairs = assert( pairs )
local ipairs = assert( ipairs )
local select = assert( select )
local setmetatable = assert( setmetatable )
local require = assert( require )
local fx = require( "fx" )
local curry = assert( fx.curry )
local map = assert( fx.map )



-- Instead of the functors Identity and Const, we use an explicit
-- flag that gets passed to all lenses and tells us whether to
-- return an updated copy or not. By avoiding the functors we can
-- reduce table allocations quite a bit, and an extra value passed
-- to the lenses was necessary anyway to fix the behavior of mapped
-- when viewing. (Another approach would be to not allow mapped in
-- view, because mapped is actually a setter not a lens.)
local function makeLens( getter, setter )
  return function( f )
    return function( x, doupdate )
      if doupdate then
        return (setter( x, f( getter( x ), true ) ))
      else
        return f( getter( x ), false )
      end
    end
  end
end


local function tableLens( key )
  local function getter( t )
    if t ~= nil then return t[ key ] end
  end
  local function setter( t, nv )
    t = t == nil and {} or t
    local nt = {}
    for k,v in pairs( t ) do
      nt[ k ] = v
    end
    nt[ key ] = nv
    return nt
  end
  return makeLens( getter, setter )
end



local function ID( x ) return x end
-- swallow extra arguments (i.e. the doupdate flag)
local function F( f )
  return function( v ) return (f( v )) end
end
-- K combinator (return previously configured value)
local function K( x )
  return function() return x end
end


local function view( lens, x )
  return lens( ID )( x, false )
end

local function over( lens, f, x )
  return lens( F( f ) )( x, true )
end

local function set( lens, v, x )
  return lens( K( v ) )( x, true )
end



local function mapped( f )
  return function( x, doupdate )
    if x ~= nil then
      return map( f, x, doupdate )
    else
      return {}
    end
  end
end


local function selected( p )
  return function( f )
    return function( x, doupdate )
      local r = {}
      if x ~= nil then
        for k,v in pairs( x ) do
          if p( k, v ) then
            r[ k ] = f( v, doupdate )
          elseif doupdate then
            r[ k ] = v
          end
        end
      end
      return r
    end
  end
end


local function filtered( p )
  return function( f )
    return function( x, doupdate )
      local r, n = {}, 1
      if x ~= nil then
        for i,v in ipairs( x ) do
          if p( i, v ) then
            r[ n ], n = f( v, doupdate ), n+1
          elseif doupdate then
            r[ n ], n = v, n+1
          end
        end
      end
      return r
    end
  end
end



-- add predefined lenses here
local Lenses = {
  indexed = tableLens,
  mapped = mapped,
  selected = selected,
  filtered = filtered,
}

local L_meta = {
  __index = Lenses
}

local function makeLenses( ... )
  local L = {}
  for i = 1, select( '#', ... ) do
    local name = select( i, ... )
    L[ name ] = tableLens( name )
  end
  return setmetatable( L, L_meta )
end



-- return module table
return setmetatable( {
  Lenses = Lenses,
  view = curry( 2, view ),
  over = curry( 3, over ),
  set = curry( 3, set ),
  makeLens = makeLens,
  makeLenses = makeLenses,
}, { __call = function( t )
  _G.view = t.view
  _G.over = t.over
  _G.set = t.set
  _G.makeLenses = t.makeLenses
  return t
end } )

