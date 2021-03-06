local assert = assert
local error = assert( error )
local tostring = assert( tostring )
local setmetatable = assert( setmetatable )
local require = assert( require )
local F = require( "fx.functors" )
local makeFunctor = assert( F.makeFunctor )
local makeApplicative = assert( F.makeApplicative )


local Const, Meta = makeFunctor( "Const" )


setmetatable( Const, {
  __call = function( _, v )
    return setmetatable( { v }, Meta )
  end
} )


function Meta:__tostring()
  return "Const "..tostring( self[ 1 ] )
end


function Const:get()
  return self[ 1 ]
end


function Const:map()
  return self
end


local cache = setmetatable( {}, { __mode = "k" } )

-- return type constructor
return function( t )
  if t ~= nil and t.isMonoid then
    local M, C = cache[ t ]
    if not M then
      local cname = "Const<"..t.name..">"
      local iscname = "is"..cname
      C, M = makeApplicative( cname )
      cache[ t ] = M

      setmetatable( C, {
        __call = function( _, v )
          return setmetatable( { v }, M )
        end
      } )

      C.get = Const.get
      C.map = Const.map
      M.__tostring = Meta.__tostring

      function C.pure()
        return C( t.mempty() )
      end

      function C:apply( f )
        if not f[ iscname ] then
          error( cname .. " expected", 2 )
        end
        return C( f:get():mappend( self:get() ) )
      end
    else
      C = M.__index
    end
    return C
  else
    return Const
  end
end

