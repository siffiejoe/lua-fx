local assert = assert
local tostring = assert( tostring )
local setmetatable = assert( setmetatable )
local require = assert( require )
local F = require( "fx.functors" )
local makeMonad = assert( F.makeMonad )


local None, NMeta = makeMonad( "Nothing" )
None.isMaybe = true


-- singleton Nothing value
local Nothing = setmetatable( {}, NMeta )


-- make the Nothing singleton behave like a Nothing type also
function NMeta:__call()
  return self
end


function NMeta.__tostring()
  return "Nothing"
end


local Just, JMeta = makeMonad( "Just" )
Just.isMaybe = true


setmetatable( Just, {
  __call = function( _, v )
    return setmetatable( { v }, JMeta )
  end
} )


function JMeta:__tostring()
  return "Just "..tostring( self[ 1 ] )
end


function Just:get()
  return self[ 1 ]
end


local function fmap( self, f )
  if self == Nothing then
    return Nothing
  else
    return Just( f( self:get() ) )
  end
end
Just.map, None.map = fmap, fmap


local function pure( v )
  return Just( v )
end
Just.pure, None.pure = pure, pure


local function apply( self, f )
  assert( f.isMaybe, "Maybe expected" )
  if self == Nothing or f == Nothing then
    return Nothing
  else
    return Just( f:get()( self:get() ) )
  end
end
Just.apply, None.apply = apply, apply


local function bind( self, f )
  if self == Nothing then
    return Nothing
  else
    return f( self:get() )
  end
end
Just.bind, None.bind = bind, bind


-- return type constructor
return function()
  return Just, Nothing
end

