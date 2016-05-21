local assert = assert
local tostring = assert( tostring )
local setmetatable = assert( setmetatable )
local require = assert( require )
local F = require( "fx.functors" )
local makeMonad = assert( F.makeMonad )


local Left, LMeta = makeMonad( "Left" )
Left.isEither = true


setmetatable( Left, {
  __call = function( _, v )
    return setmetatable( { v }, LMeta )
  end
} )


function LMeta:__tostring()
  return "Left "..tostring( self[ 1 ] )
end


local Right, RMeta = makeMonad( "Right" )
Right.isEither = true


setmetatable( Right, {
  __call = function( _, v )
    return setmetatable( { v }, RMeta )
  end
} )


function RMeta:__tostring()
  return "Right "..tostring( self[ 1 ] )
end


local function get( self )
  return self[ 1 ]
end
Left.get, Right.get = get, get


local function fmap( self, f )
  if self.isLeft then
    return self
  else
    return Right( f( self:get() ) )
  end
end
Left.fmap, Right.fmap = fmap, fmap


local function pure( v )
  return Right( v )
end
Left.pure, Right.pure = pure, pure


local function apply( self, f )
  assert( f.isEither, "Either expected" )
  if f.isLeft then
    return f
  elseif self.isLeft then
    return self
  else
    return Right( f:get()( self:get() ) )
  end
end
Left.apply, Right.apply = apply, apply


local function bind( self, f )
  if self.isLeft then
    return self
  else
    return f( self:get() )
  end
end
Left.bind, Right.bind = bind, bind


-- return type constructor
return function()
  return Left, Right
end

