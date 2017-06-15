local fx = require( "fx.core" )
local pairs = assert( pairs )


-- Instead of the functors Identity and Const, we use an explicit
-- flag that gets passed to all lenses and tells us whether to
-- return an updated copy or not. By avoiding the functors we can
-- reduce table allocations quite a bit.
local function lens( getter, setter )
  return function( f )
    return function( x, doupdate )
      if doupdate then
        return (setter( x, f( getter( x ), true ) ))
      else
        return (f( getter( x ), false ))
      end
    end
  end
end


local function prism( getter, setter )
  return function( f )
    return function( x, doupdate )
      local a = getter( x )
      if doupdate then
        if a == nil then return x, true end
        local b, unchanged = f( a, true )
        if unchanged then return x end
        return (setter( x, b ))
      else
        if a == nil then return nil end
        return f( a, false )
      end
    end
  end
end


local function tableprism( key )
  local function getter( t )
    return t[ key ]
  end
  local function setter( t, nv )
    local nt = {}
    for k, v in pairs( t ) do
      nt[ k ] = v
    end
    nt[ key ] = nv
    return nt
  end
  return prism( getter, setter )
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


-- return module table
return setmetatable( {
  view = fx.curry( 2, view ),
  over = fx.curry( 3, over ),
  set = fx.curry( 3, set ),
  lens = lens,
  prism = prism,
  tableprism = tableprism,
}, { __call = function( M, t )
  t = t or _G
  for k,v in pairs( M ) do
    t[ k ] = v
  end
  return M
end } )

