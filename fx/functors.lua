local assert = assert
local error = assert( error )
local setmetatable = assert( setmetatable )
local require = assert( require )
local fx = require( "fx" )
local curry = assert( fx.curry )
local compose = assert( fx.compose )



-- cache the metatables of objects
local metatables = setmetatable( {}, { __mode = "k" } )


local function makeType( name )
  local mt, t = metatables[ name ]
  if mt then
    t = mt.__index
  else
    t = { name = name, [ "is"..name ] = true }
    function t:switch( alt, ... )
      return alt[ name ]( self, ... )
    end
    mt = { __index = t, __name = name }
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


local function makeMonoid( name )
  local t, mt = makeType( name )
  if not t.isMonoid then
    t.isMonoid = true
    t.mempty = pure_virtual
    t.mappend = pure_virtual
  end
  return t, mt
end


local function makeFunctor( name )
  local t, mt = makeType( name )
  if not t.isFunctor then
    t.isFunctor = true
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
  local t, mt = makeType( name )
  if not t.isApplicative then
    t.isFunctor, t.isApplicative = true, true
    if t.fmap == nil or t.fmap == pure_virtual then
      t.fmap = applicative_default_fmap
    end
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
  assert( f.isMonad, "Monad expected" )
  return f:bind( function( g )
    return self:fmap( g )
  end )
end

local function makeMonad( name )
  local t, mt = makeType( name )
  if not t.isMonad then
    t.isFunctor, t.isApplicative, t.isMonad = true, true, true
    if t.fmap == nil or t.fmap == pure_virtual then
      t.fmap = monad_default_fmap
    end
    mt.__mod = fmap_operator
    mt[ "__map@fx" ] = map_metamethod
    if t.pure == nil then t.pure = pure_virtual end
    if t.apply == nil or t.apply == pure_virtual then
      t.apply = monad_default_apply
    end
    t.bind = pure_virtual
    mt.__div = bind_operator
  end
  return t, mt
end


local function fmap( f, v )
  assert( v.isFunctor, "Functor expected" )
  return v:fmap( f )
end

local function apply( f, v )
  assert( v.isApplicative, "Applicative functor expected" )
  return v:apply( f )
end

local function bind( f, v )
  assert( v.isMonad, "Monad expected" )
  return v:bind( f )
end

local function lift2( f, a, b )
  assert( a.isApplicative, "Applicative functor expected" )
  return b:apply( a:fmap( curry( 2, f ) ) )
end

local function lift3( f, a, b, c )
  assert( a.isApplicative, "Applicative functor expected" )
  return c:apply( b:apply( a:fmap( curry( 3, f ) ) ) )
end

local function lift4( f, a, b, c, d )
  assert( a.isApplicative, "Applicative functor expected" )
  return d:apply( c:apply( b:apply( a:fmap( curry( 4, f ) ) ) ) )
end

-- return module table
return {
  -- type constructors
  makeType = makeType,
  makeMonoid = makeMonoid,
  makeFunctor = makeFunctor,
  makeApplicative = makeApplicative,
  makeMonad = makeMonad,
  -- free functions
  fmap = curry( 2, fmap ),
  apply = curry( 2, apply ),
  bind = curry( 2, bind ),
  lift2 = curry( 3, lift2 ),
  lift3 = curry( 4, lift3 ),
  lift4 = curry( 5, lift4 ),
}

