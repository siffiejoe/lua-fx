local assert = assert
local type = assert( type )
local error = assert( error )
local setmetatable = assert( setmetatable )
local require = assert( require )
local fx = require( "fx" )
local curry = assert( fx.curry )
local compose = assert( fx.compose )



-- cache the metatables of objects
local metatables = setmetatable( {}, { __mode = "k" } )


local function gettype( name )
  local mt, t = metatables[ name ]
  if mt then
    t = mt.__index
  else
    t = { name = name }
    mt = { __index = t }
    metatables[ name ] = mt
  end
  return t, mt
end


local function pure_virtual()
  error( "pure virtual method not implemented", 2 )
end


local function map_metamethod( f, v )
  return v:fmap( f )
end

local function fmap_operator( v, f )
  return v:fmap( f )
end

local function bind_operator( v, f )
  return v:bind( f )
end


local function is_a( v, tn )
  return type( v ) == "table" and v[ tn ] == true
end

local function assert_is_a( v, tn )
  if type( v ) ~= "table" or v[ tn ] ~= true then
    error( tn.." expected", 2 )
  end
end



local function makeMonoid( name )
  local t, mt = gettype( name )
  if not t.Monoid then
    t[ name ] = true
    t.Monoid = true
    t.mempty = pure_virtual
    t.mappend = pure_virtual
  end
  return t, mt
end


local function makeFunctor( name )
  local t, mt = gettype( name )
  if not t.Functor then
    t[ name ] = true
    t.Functor = true
    t.fmap = pure_virtual
    mt.__mod = fmap_operator
    mt[ "__map@fx" ] = map_metamethod
  end
  return t, mt
end


local function applicative_default_fmap( self, f )
  return self:apply( self.pure( f ) )
end

local function makeApplicative( name )
  local t, mt = gettype( name )
  if not t.Applicative then
    t[ name ] = true
    t.Functor, t.Applicative = true, true
    t.fmap = applicative_default_fmap
    mt.__mod = fmap_operator
    mt[ "__map@fx" ] = map_metamethod
    t.pure = pure_virtual
    t.apply = pure_virtual
  end
  return t, mt
end


local function monad_default_fmap( self, f )
  return self:bind( compose( self.pure, f ) )
end

local function monad_default_apply( self, f )
  assert_is_a( f, "Monad" )
  return f:bind( function( g )
    return self:fmap( g )
  end )
end

local function makeMonad( name )
  local t, mt = gettype( name )
  if not t.Monad then
    t[ name ] = true
    t.Functor, t.Applicative, t.Monad = true, true, true
    t.fmap = monad_default_fmap
    mt.__mod = fmap_operator
    mt[ "__map@fx" ] = map_metamethod
    t.pure = pure_virtual
    t.apply = monad_default_apply
    t.bind = pure_virtual
    mt.__div = bind_operator
  end
  return t, mt
end


local function fmap( f, v )
  assert_is_a( v, "Functor" )
  return v:fmap( f )
end

local function apply( f, v )
  assert_is_a( v, "Applicative" )
  return v:apply( f )
end

local function bind( f, v )
  assert_is_a( v, "Monad" )
  return v:bind( f )
end


-- return module table
return {
  -- type constructors
  makeMonoid = makeMonoid,
  makeFunctor = makeFunctor,
  makeApplicative = makeApplicative,
  makeMonad = makeMonad,
  -- free functions
  fmap = curry( 2, fmap ),
  apply = curry( 2, apply ),
  bind = curry( 2, bind ),
  -- other helper functions
  is_a = is_a,
  assert_is_a = assert_is_a,
}

