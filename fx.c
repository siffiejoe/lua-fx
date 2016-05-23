#include <stddef.h>
#include <string.h>
#include <ctype.h>
#include <lua.h>
#include <lauxlib.h>


#if LUA_VERSION_NUM == 501
/* compatibility for Lua 5.1 */

#define luaL_newlib( L, r ) \
  (lua_newtable( L ), luaL_register( L, NULL, r ))

#define lua_pushglobaltable( L ) \
  (lua_pushvalue( L, LUA_GLOBALSINDEX ))

typedef int lua_KContext;

#define lua_callk( L, na, nr, ctx, cont ) \
  ((void)(ctx),(void)(cont),lua_call( L, na, nr ))

#endif /* LUA_VERSION_NUM < 502 */


#if LUA_VERSION_NUM == 502

typedef int lua_KContext;

#define LUA_KFUNCTION( _name ) \
  static int (_name)( lua_State* L, int status, lua_KContext ctx ); \
  static int (_name ## _52)( lua_State* L ) { \
    lua_KContext ctx; \
    int status = lua_getctx( L, &ctx ); \
    return (_name)( L, status, ctx ); \
  } \
  static int (_name)( lua_State* L, int status, lua_KContext ctx )

#define lua_callk( L, na, nr, ctx, cont ) \
  lua_callk( L, na, nr, ctx, cont ## _52 )

#ifdef lua_call
#undef lua_call
#define lua_call( L, na, nr ) \
  (lua_callk)( L, na, nr, 0, 0 )
#endif

#else /* LUA_VERSION_NUM != 502 */

#define LUA_KFUNCTION( _name ) \
  static int (_name)( lua_State* L, int status, lua_KContext ctx )

#endif



static int is_sequence( lua_State* L, int i ) {
  switch( lua_type( L, i ) ) {
    case LUA_TTABLE:
      return 1;
    case LUA_TUSERDATA:
      if( !luaL_getmetafield( L, i, "__index" ) )
        break;
      lua_pop( L, 1 );
      return 1;
  }
  return 0;
}
#define check_sequence( L, i ) \
  (luaL_argcheck( L, is_sequence( L, i ), i, "sequence expected" ))


static int is_callable( lua_State* L, int i ) {
  switch( lua_type( L, i ) ) {
    case LUA_TFUNCTION:
      return 1;
    case LUA_TUSERDATA: /* fall through */
    case LUA_TTABLE:
      if( luaL_getmetafield( L, i, "__call" ) ) {
        lua_pop( L, 1 );
        return 1;
      }
      break;
  }
  return 0;
}
#define check_callable( L, i ) \
  (luaL_argcheck( L, is_callable( L, i ), i, \
                  "function or callable userdata/table expected" ))


/* unique addresses used as IDs/markers */
static char const mark[ 1 ];


/* enable/disable special handling of placeholder value: */
#if 1
#define is_gap( L, idx ) \
  (lua_touserdata( L, idx ) == (void*)mark)
#else
#define is_gap( L, idx ) (0)
#endif


#define is_stop( L, idx ) \
  (lua_touserdata( L, idx ) == (void*)mark)


#ifndef LUAI_MAXUPVALUES
#if LUA_VERSION_NUM > 501
/* PUC Rio Lua 5.2 and 5.3 use this: */
#define LUAI_MAXUPVALUES 255
#else
/* the maximum for PUC-Rio Lua 5.1 and LuaJIT: */
#define LUAI_MAXUPVALUES 60
#endif
#endif



static int curried( lua_State* L );

LUA_KFUNCTION( curriedk ) {
  int n, m, g, k, i;
  int c = 1, newm = 0;
  (void)status;
  switch( ctx ) {
    case 0:
      n = lua_tointeger( L, lua_upvalueindex( 1 ) );
      m = lua_tointeger( L, lua_upvalueindex( 3 ) );
      g = lua_tointeger( L, lua_upvalueindex( 4 ) );
      k = lua_gettop( L );
      luaL_checkstack( L, k+m+5, "curried" );
      lua_pushvalue( L, lua_upvalueindex( 1 ) );
      lua_pushnil( L ); /* placeholders */
      lua_pushnil( L ); /* ... */
      lua_pushvalue( L, lua_upvalueindex( 2 ) );
      for( i = 1; i <= m; ++i ) {
        if( c <= k && is_gap( L, lua_upvalueindex( 4+i ) ) ) {
          g -= !is_gap( L, c );
          lua_pushvalue( L, c++ );
        } else
          lua_pushvalue( L, lua_upvalueindex( 4+i ) );
      }
      for( i = c; i <= k; ++i ) {
        g += is_gap( L, i );
        lua_pushvalue( L, i );
      }
      newm = m + k - c + 1;
      if( g > 0 || newm < n ) {
        lua_pushvalue( L, lua_upvalueindex( 2 ) );
        lua_replace( L, k+2 );
        lua_pushinteger( L, newm );
        lua_replace( L, k+3 );
        lua_pushinteger( L, g );
        lua_replace( L, k+4 );
        if( 4+newm > LUAI_MAXUPVALUES )
          luaL_error( L, "too many upvalues" );
        lua_pushcclosure( L, curried, 4+newm );
        return 1;
      } else {
        lua_pushinteger( L, k+3 );
        lua_replace( L, 1 );
        lua_callk( L, newm, LUA_MULTRET, 1, curriedk );
    case 1:
        k = lua_tointeger( L, 1 ); /* reload k after possible yield */
        return lua_gettop( L )-k;
      }
  }
  /* should never happen: */
  return luaL_error( L, "invalid ctx in curried function" );
}

static int curried( lua_State* L ) {
  return curriedk( L, 0, 0 );
}


#define is_curried( L, i ) \
  (lua_tocfunction( L, i ) == curried)


static void curryf( lua_State* L, int n ) {
  luaL_checkstack( L, 4, "curry" );
  lua_pushinteger( L, n ); /* required arguments */
  lua_pushvalue( L, -2 ); /* function to curry */
  lua_pushinteger( L, 0 ); /* arguments received */
  lua_pushinteger( L, 0 ); /* gaps in those arguments */
  lua_pushcclosure( L, curried, 4 );
  lua_replace( L, -2 );
}


static void recurryf( lua_State* L, int n ) {
  int req, rec, gaps, i, m;
  int idx = lua_gettop( L );
  luaL_checkstack( L, 4, "curry" );
  lua_getupvalue( L, idx, 1 );
  lua_getupvalue( L, idx, 2 );
  lua_getupvalue( L, idx, 3 );
  lua_getupvalue( L, idx, 4 );
  req = lua_tointeger( L, -4 );
  rec = lua_tointeger( L, -2 );
  gaps = lua_tointeger( L, -1 );
  m = gaps + ((req > rec) ? req - rec : 0);
  if( n > m ) {
    luaL_checkstack( L, rec+1, "curry" );
    lua_pushinteger( L, rec-gaps+n );
    lua_replace( L, -5 );
    for( i = 5; i <= rec+4; ++i )
      lua_getupvalue( L, idx, i );
    lua_pushcclosure( L, curried, rec+4 );
    lua_replace( L, idx );
  } else
    lua_pop( L, 4 );
}


static int curry( lua_State* L ) {
  lua_Integer n = luaL_checkinteger( L, 1 );
  luaL_argcheck( L, n >= 0 && n <= LUAI_MAXUPVALUES-4, 1,
                 "too many (or too few) curried parameters" );
  check_callable( L, 2 );
  lua_settop( L, 2 );
  if( is_curried( L, 2 ) )
    recurryf( L, n );
  else
    curryf( L, n );
  return 1;
}



LUA_KFUNCTION( composedk ) {
  int n = lua_tointeger( L, lua_upvalueindex( 1 ) );
  int next = 0, last = 0;
  int t, i = 0;
  (void)status;
  switch( ctx ) {
    case 0:
      t = lua_gettop( L );
      luaL_checkstack( L, n+t+2, "composed" );
      if( t < 2 ) /* make room for control block */
        lua_settop( L, 2 );
      /* push functions */
      for( i = 1; i <= n; ++i )
        lua_pushvalue( L, lua_upvalueindex( i+1 ) );
      /* push arguments */
      for( i = 1; i <= t; ++i )
        lua_pushvalue( L, i );
      /* update control block */
      last = t <= 2 ? 3 : t+1; /* index of last function to call */
      next = last + n - 1; /* index of first function to call */
      lua_pushinteger( L, last );
      lua_replace( L, 1 );
      lua_pushinteger( L, next );
      lua_replace( L, 2 );
      while( next >= last ) {
        lua_callk( L, lua_gettop( L )-next, LUA_MULTRET, 1, composedk  );
    case 1:
        last = lua_tointeger( L, 1 );
        next = lua_tointeger( L, 2 );
        luaL_checkstack( L, 1, "composed" );
        lua_pushinteger( L, --next ); /* update next idx */
        lua_replace( L, 2 );
      }
  }
  return lua_gettop( L )-next;
}

static int composed( lua_State* L ) {
  return composedk( L, 0, 0 );
}


static int is_composed( lua_State* L, int i ) {
  int r = 0;
  if( lua_tocfunction( L, i ) == composed &&
      lua_getupvalue( L, i, 1 ) ) {
    r = lua_tointeger( L, -1 );
    lua_pop( L, 1 );
  }
  return r;
}


static int compose( lua_State* L ) {
  int i, j, a, m = 0, n = lua_gettop( L );
  if( n < 1 )
    n = 1;
  lua_settop( L, n );
  luaL_argcheck( L, n < LUAI_MAXUPVALUES-1, LUAI_MAXUPVALUES,
                 "too many arguments" );
  lua_pushnil( L ); /* placeholder for m */
  luaL_checkstack( L, n+1, "compose" );
  for( i = 1; i <= n; ++i, ++m ) {
    check_callable( L, i );
    a = is_composed( L, i );
    if( a < 1 || a+m+n-i+1 > LUAI_MAXUPVALUES )
      lua_pushvalue( L, i );
    else { /* unpack composed function */
      luaL_checkstack( L, n-i+a, "compose" );
      for( j = 1; j <= a; ++j )
        lua_getupvalue( L, i, j+1 );
      m += a-1;
    }
  }
  lua_pushinteger( L, m );
  lua_replace( L, n+1 );
  /* upvalues: m, f1, f2, ..., fm */
  lua_pushcclosure( L, composed, m+1 );
  return 1;
}



/* duck type checking */
typedef struct {
  char const* s;
  size_t len;
} sliteral;

#define SLIT( s ) \
  { "" s , sizeof( s )-1 }

#define N( a ) (sizeof( a )/sizeof( *a ))

/* list of metamethod names, sorted by length */
static sliteral const metafields[] = {
  SLIT( "eq" ),
  SLIT( "gc" ),
  SLIT( "le" ),
  SLIT( "lt" ),
  SLIT( "add" ),
  SLIT( "bor" ),
  SLIT( "div" ),
  SLIT( "len" ),
  SLIT( "mod" ),
  SLIT( "mul" ),
  SLIT( "pow" ),
  SLIT( "shl" ),
  SLIT( "shr" ),
  SLIT( "sub" ),
  SLIT( "unm" ),
  SLIT( "band" ),
  SLIT( "bnot" ),
  SLIT( "bxor" ),
  SLIT( "call" ),
  SLIT( "idiv" ),
  SLIT( "mode" ),
  SLIT( "index" ),
  SLIT( "pairs" ),
  SLIT( "concat" ),
  SLIT( "ipairs" ),
  SLIT( "newindex" ),
  SLIT( "tostring" ),
  SLIT( "metatable" ),
};

/* contents depend on order of Lua type tags and metafields above! */
static unsigned char const capabilities[][ N( metafields ) ] = {
  /* LUA_TNIL */           {1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1,0},
  /* LUA_TBOOLEAN */       {1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1,0},
  /* LUA_TLIGHTUSERDATA */ {1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1,0},
  /* LUA_TNUMBER */        {1,0,1,1,1,1,1,0,1,1,1,1,1,1,1,1,1,1,0,1,0,0,0,0,0,0,1,0},
  /* LUA_TSTRING */        {1,0,1,1,0,0,0,1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1,0,0,1,0},
  /* LUA_TTABLE */         {1,0,0,0,0,0,0,1,0,0,0,0,0,0,0,0,0,0,0,0,0,1,1,0,1,1,1,0},
  /* LUA_TFUNCTION */      {1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1,0,0,0,0,0,0,0,1,0},
  /* LUA_TUSERDATA */      {1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1,0},
  /* LUA_TTHREAD */        {1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1,0},
  /* LUA_TPROTO(luajit) */ {1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1,0},
  /* LUA_TCDATA(luajit) */ {1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1,0},
};


/* The capabilities table above relies on the specific numeric values
 * of Lua's types. Although those haven't changed since Lua 5.0 (at
 * least), the following array will produce a compiler error in case
 * they *do* change at some point in the future.
 */
static unsigned char assert_lua_tag_values[
  1 - 2*((LUA_TNIL != 0) + (LUA_TBOOLEAN != 1) +
         (LUA_TLIGHTUSERDATA != 2) + (LUA_TNUMBER != 3) +
         (LUA_TSTRING != 4) + (LUA_TTABLE != 5) +
         (LUA_TFUNCTION != 6) + (LUA_TUSERDATA != 7) +
         (LUA_TTHREAD != 8))
] = { 0 };


static int has_check( lua_State* L ) {
  int n = lua_tointeger( L, lua_upvalueindex( 1 ) );
  int i, t, ok = 1, mt = -1;
  lua_settop( L, 1 );
  t = lua_type( L, 1 );
  for( i = 0; i < n; ++i ) {
    int index = lua_upvalueindex( i+2 );
    int ct = lua_type( L, index );
    if( ct == LUA_TNUMBER ) { /* check metamethod */
      int mf = lua_tointeger( L, index );
      ++i; /* metamethod name follows metamethod number */
      index = lua_upvalueindex( i+2 );
      if( !capabilities[ t ][ mf ] ) {
        if( mt < 0 ) {
          lua_getmetatable( L, 1 );
          mt = lua_gettop( L );
          if( !lua_istable( L, mt ) ) {
            ok = 0;
            break;
          }
        }
        lua_pushvalue( L, index );
        lua_rawget( L, mt );
        if( lua_isnil( L, -1 ) ){
          ok = 0;
          break;
        }
        lua_pop( L, 1 );
      }
    } else { /* check normal field */
      lua_pushvalue( L, index );
      lua_gettable( L, 1 );
      if( lua_isnil( L, -1 ) ) {
        ok = 0;
        break;
      }
      lua_pop( L, 1 );
    }
  }
  lua_pushboolean( L, ok );
  return 1;
}


static int is_metafield( char const* s, size_t n ) {
  if( n >= metafields[ 0 ].len+2 &&
      s[ 0 ] == '_' && s[ 1 ] == '_' &&
      n <= metafields[ N( metafields )-1 ].len+2 ) {
    int i;
    s += 2; /* skip "__" after initial check */
    n -= 2;
    for( i = 0; i < (int)N( metafields ); ++i ) {
      sliteral const* other = metafields+i;
      if( n == other->len ) {
        if( 0 == memcmp( s, other->s, n ) )
          return i;
      } else if( n < other->len )
        break;
    }
  }
  return -1;
}


static void pushcheck( lua_State* L, char const* from,
                       char const* to, int* n ) {
  int mf = is_metafield( from, to-from );
  if( mf >= 0 ) { /* metafield check */
    luaL_checkstack( L, 3, "has" );
    lua_pushinteger( L, mf );
    *n += 2;
  } else { /* normal field check */
    luaL_checkstack( L, 2, "has" );
    *n += 1;
  }
  lua_pushlstring( L, from, to-from );
}


static int idchar( int c ) {
  return isalnum( (unsigned char)c ) || c == '_';
}

static int has( lua_State* L ) {
  int n = 0;
  size_t len = 0;
  char const* s = luaL_checklstring( L, 1, &len );
  char const* c = s;
  char const* l = s;
  (void)assert_lua_tag_values;
  lua_pushvalue( L, 1 );
  lua_rawget( L, lua_upvalueindex( 1 ) );
  if( lua_isnil( L, -1 ) ) {
    lua_settop( L, 2 );
    while( !idchar( *c ) && c != s+len )
      ++c;
    while( c != s+len ) {
      if( !idchar( *c ) ) {
        pushcheck( L, l, c, &n );
        do {
          ++c;
        } while( !idchar( *c ) && c != s+len );
        l = c;
      } else
        ++c;
    }
    pushcheck( L, l, c, &n );
    lua_pushinteger( L, n );
    lua_replace( L, 2 );
    lua_pushcclosure( L, has_check, n+1 );
    lua_pushvalue( L, 1 );
    lua_pushvalue( L, -2 );
    lua_rawset( L, lua_upvalueindex( 1 ) );
  }
  return 1;
}



LUA_KFUNCTION( map_reducerk ) {
  (void)status;
  switch( ctx ) {
    case 0: /* state, ... */
      luaL_checkany( L, 1 );
      lua_pushvalue( L, lua_upvalueindex( 2 ) );
      lua_insert( L, 1 );
      lua_pushvalue( L, lua_upvalueindex( 1 ) );
      lua_insert( L, 3 );
      lua_callk( L, lua_gettop( L )-3, LUA_MULTRET, 1, map_reducerk );
    case 1: /* reducer, state, r_1, ... r_n */
      lua_callk( L, lua_gettop( L )-1, LUA_MULTRET, 2, map_reducerk );
  }
  return lua_gettop( L );
}

static int map_reducer( lua_State* L ) {
  return map_reducerk( L, 0, 0 );
}


LUA_KFUNCTION( mapk ) {
  int nx = 0, i = 1, j = 1;
  (void)status;
  switch( ctx ) {
    case 0:
      check_callable( L, 1 );
      if( lua_isfunction( L, 2 ) ) {
        lua_settop( L, 2 );
        lua_pushcclosure( L, map_reducer, 2 );
        return 1;
      } else if( luaL_getmetafield( L, 2, "__map@fx" ) ) {
        lua_insert( L, 1 );
        lua_callk( L, lua_gettop( L )-1, 1, 1, mapk );
    case 1: /* result */
        return 1;
      } else { /* work on sequence(-like object) */
        check_sequence( L, 2 );
        nx = lua_gettop( L )-2;
        lua_pushinteger( L, 1 ); /* store current iteration index */
        lua_newtable( L ); /* result table */
        luaL_checkstack( L, nx+2, "map" );
        do { /* func, array, x_1, ..., x_n, i, res */
          lua_pushvalue( L, 1 );
          lua_pushvalue( L, -3 );
          lua_gettable( L, 2 );
          if( lua_isnil( L, -1 ) ) {
            lua_pop( L, 2 );
            return 1;
          }
          for( j = 3; j <= nx+2; ++j )
            lua_pushvalue( L, j );
          lua_callk( L, nx+1, 1, 2, mapk );
    case 2: /* func, array, x_1, ..., x_n, i, res, v */
          nx = lua_gettop( L )-5;
          i = lua_tointeger( L, nx+3 );
          lua_rawseti( L, nx+4, i );
          lua_pushinteger( L, ++i );
          lua_replace( L, nx+3 ); /* update i */
        } while( 1 );
      }
  }
  /* should never happen: */
  return luaL_error( L, "invalid ctx in map function" );
}

static int map( lua_State* L ) {
  return mapk( L, 0, 0 );
}



LUA_KFUNCTION( filter_reducerk ) {
  int nargs = 0, i = 0;
  (void)status;
  switch( ctx ) {
    case 0: /* state, ... */
      luaL_checkany( L, 1 );
      nargs = lua_gettop( L )-1;
      lua_pushvalue( L, lua_upvalueindex( 2 ) );
      lua_insert( L, 1 ); /* reducer, state, x_1, ... x_n */
      lua_pushvalue( L, lua_upvalueindex( 1 ) );
      luaL_checkstack( L, nargs, "filter transducer" );
      for( i = 3; i <= nargs+2; ++i )
        lua_pushvalue( L, i );
      lua_callk( L, nargs, 1, 1, filter_reducerk );
    case 1: /* reducer, state, x_1, ..., x_n, r_1 */
      if( !lua_toboolean( L, -1 ) ) {
        lua_settop( L, 2 );
        lua_replace( L, 1 );
      } else {
        lua_pop( L, 1 );
        lua_callk( L, lua_gettop( L )-1, LUA_MULTRET, 2,
                   filter_reducerk );
      }
  }
  return lua_gettop( L );
}

static int filter_reducer( lua_State* L ) {
  return filter_reducerk( L, 0, 0 );
}


LUA_KFUNCTION( filterk ) {
  int nx = 0, i = 1, j = 1;
  (void)status;
  switch( ctx ) {
    case 0:
      check_callable( L, 1 );
      if( lua_isfunction( L, 2 ) ) {
        lua_settop( L, 2 );
        lua_pushcclosure( L, filter_reducer, 2 );
        return 1;
      } else { /* work on sequence(-like object) */
        check_sequence( L, 2 );
        nx = lua_gettop( L )-2;
        lua_pushinteger( L, 1 ); /* store current iteration index */
        lua_newtable( L ); /* result table */
        lua_pushinteger( L, 1 ); /* store current target index */
        luaL_checkstack( L, nx+3, "filter" );
        do { /* pred, array, x_1, ..., x_n, i, res, j */
          lua_pushvalue( L, -3 );
          lua_gettable( L, 2 );
          if( lua_isnil( L, -1 ) ) {
            lua_pop( L, 2 );
            return 1;
          }
          lua_pushvalue( L, 1 );
          lua_pushvalue( L, -2 );
          for( j = 3; j <= nx+2; ++j )
            lua_pushvalue( L, j );
          lua_callk( L, nx+1, 1, 1, filterk );
    case 1: /* pred, array, x_1, ..., x_n, i, res, j, v, r */
          nx = lua_gettop( L )-7;
          i = lua_tointeger( L, nx+3 );
          j = lua_tointeger( L, nx+5 );
          if( lua_toboolean( L, -1 ) ) {
            lua_pop( L, 1 );
            lua_rawseti( L, nx+4, j );
            lua_pushinteger( L, ++j );
            lua_replace( L, nx+5 ); /* update j */
          } else
            lua_pop( L, 2 );
          lua_pushinteger( L, ++i );
          lua_replace( L, nx+3 ); /* update i */
        } while( 1 );
      }
  }
  /* should never happen: */
  return luaL_error( L, "invalid ctx in filter function" );
}

static int filter( lua_State* L ) {
  return filterk( L, 0, 0 );
}



LUA_KFUNCTION( take_while_reducerk ) {
  int nargs = 0, i = 0;
  (void)status;
  switch( ctx ) {
    case 0: /* state, ... */
      luaL_checkany( L, 1 );
      nargs = lua_gettop( L )-1;
      lua_pushvalue( L, lua_upvalueindex( 2 ) );
      lua_insert( L, 1 );
      lua_pushvalue( L, lua_upvalueindex( 1 ) );
      if( !lua_isnil( L, -1 ) ) {
        luaL_checkstack( L, nargs, "take (while) transducer" );
        for( i = 3; i <= nargs+2; ++i )
          lua_pushvalue( L, i );
        lua_callk( L, nargs, 1, 1, take_while_reducerk );
      }
    case 1: /* reducer, state, x_1, ..., x_n, r */
      if( !lua_toboolean( L, -1 ) ) {
        lua_pushnil( L );
        lua_replace( L, lua_upvalueindex( 1 ) );
        lua_settop( L, 2 );
        lua_replace( L, 1 );
        lua_pushlightuserdata( L, (void*)mark );
      } else {
        lua_pop( L, 1 );
        lua_callk( L, lua_gettop( L )-1, LUA_MULTRET, 2,
                   take_while_reducerk );
      }
  }
  return lua_gettop( L );
}

static int take_while_reducer( lua_State* L ) {
  return take_while_reducerk( L, 0, 0 );
}


LUA_KFUNCTION( take_n_reducerk ) {
  int n = 0;
  (void)status;
  switch( ctx ) {
    case 0:
      luaL_checkany( L, 1 );
      n = lua_tointeger( L, lua_upvalueindex( 1 ) );
      if( n > 0 ) {
        lua_pushvalue( L, lua_upvalueindex( 2 ) );
        lua_insert( L, 1 );
        lua_pushinteger( L, --n );
        lua_replace( L, lua_upvalueindex( 1 ) );
        lua_callk( L, lua_gettop( L )-1, LUA_MULTRET, 1,
                   take_n_reducerk );
      } else
        lua_settop( L, 1 );
  }
  if( lua_tointeger( L, lua_upvalueindex( 1 ) ) <= 0 ) {
    lua_settop( L, 1 );
    lua_pushlightuserdata( L, (void*)mark );
  }
  return lua_gettop( L );
}

static int take_n_reducer( lua_State* L ) {
  return take_n_reducerk( L, 0, 0 );
}


LUA_KFUNCTION( takek ) {
  int nx = 0, i = 1, j = 1;
  (void)status;
  switch( ctx ) {
    case 0:
      if( is_callable( L, 1 ) ) { /* -> take-while */
        if( lua_isfunction( L, 2 ) ) {
          lua_settop( L, 2 );
          lua_pushcclosure( L, take_while_reducer, 2 );
          return 1;
        } else { /* work on sequence(-like object) */
          check_sequence( L, 2 );
          nx = lua_gettop( L )-2;
          lua_pushinteger( L, 1 ); /* store current iteration index */
          lua_newtable( L ); /* result table */
          lua_pushinteger( L, 1 ); /* store current target index */
          luaL_checkstack( L, nx+3, "take (while)" );
          do { /* pred, array, x_1, ..., x_n, i, res, j */
            lua_pushvalue( L, nx+3 );
            lua_gettable( L, 2 );
            if( lua_isnil( L, -1 ) ) {
              lua_pop( L, 2 );
              return 1;
            }
            lua_pushvalue( L, 1 );
            lua_pushvalue( L, -2 );
            for( j = 3; j <= nx+2; ++j )
              lua_pushvalue( L, j );
            lua_callk( L, nx+1, 1, 1, takek );
    case 1: /* pred, array, x_1, ..., x_n, i, res, j, v, r */
            if( !lua_toboolean( L, -1 ) ) {
              lua_pop( L, 3 );
              return 1;
            }
            nx = lua_gettop( L )-7;
            i = lua_tointeger( L, nx+3 );
            j = lua_tointeger( L, nx+5 );
            lua_pop( L, 1 );
            lua_rawseti( L, nx+4, j );
            lua_pushinteger( L, ++j );
            lua_replace( L, nx+5 ); /* update j */
            lua_pushinteger( L, ++i );
            lua_replace( L, nx+3 ); /* update i */
          } while( 1 );
        }
      } else { /* -> take-n */
        int n = luaL_checkinteger( L, 1 );
        if( lua_isfunction( L, 2 ) ) {
          lua_settop( L, 2 );
          lua_pushcclosure( L, take_n_reducer, 2 );
          return 1;
        } else { /* work on sequence(-like object) */
          check_sequence( L, 2 );
          lua_settop( L, 2 );
          lua_newtable( L ); /* result table */
          while( i <= n ) { /* n, array, res */
            lua_pushinteger( L, i++ );
            lua_pushvalue( L, -1 );
            lua_gettable( L, 2 );
            if( lua_isnil( L, -1 ) ) {
              lua_pop( L, 2 );
              return 1;
            }
            lua_rawset( L, -3 );
          }
          return 1;
        }
      }
  }
  /* should never happen: */
  return luaL_error( L, "invalid ctx in take function" );
}

static int take( lua_State* L ) {
  return takek( L, 0, 0 );
}



LUA_KFUNCTION( drop_while_reducerk ) {
  int nargs = 0, i = 0;
  (void)status;
  switch( ctx ) {
    case 0: /* state, ... */
      luaL_checkany( L, 1 );
      nargs = lua_gettop( L )-1;
      lua_pushvalue( L, lua_upvalueindex( 2 ) );
      lua_insert( L, 1 );
      lua_pushvalue( L, lua_upvalueindex( 1 ) );
      if( lua_isnil( L, -1 ) ) {
        lua_pop( L, 1 );
        lua_callk( L, lua_gettop( L )-1, LUA_MULTRET, 2,
                   drop_while_reducerk );
      } else {
        luaL_checkstack( L, nargs, "drop (while) transducer" );
        for( i = 3; i <= nargs+2; ++i )
          lua_pushvalue( L, i );
        lua_callk( L, nargs, 1, 1, take_while_reducerk );
    case 1: /* reducer, state, x_1, ..., x_n, r */
        if( lua_toboolean( L, -1 ) ) {
          lua_settop( L, 2 );
          lua_replace( L, 1 );
        } else {
          lua_pop( L, 1 );
          lua_pushnil( L );
          lua_replace( L, lua_upvalueindex( 1 ) );
          lua_callk( L, lua_gettop( L )-1, LUA_MULTRET, 2,
                     drop_while_reducerk );
        }
      }
  }
  return lua_gettop( L );
}

static int drop_while_reducer( lua_State* L ) {
  return drop_while_reducerk( L, 0, 0 );
}


LUA_KFUNCTION( drop_n_reducerk ) {
  int n = 0;
  (void)status;
  switch( ctx ) {
    case 0:
      luaL_checkany( L, 1 );
      n = lua_tointeger( L, lua_upvalueindex( 1 ) );
      if( n > 0 ) {
        lua_pushinteger( L, --n );
        lua_replace( L, lua_upvalueindex( 1 ) );
        lua_settop( L, 1 );
      } else {
        lua_pushvalue( L, lua_upvalueindex( 2 ) );
        lua_insert( L, 1 );
        lua_callk( L, lua_gettop( L )-1, LUA_MULTRET, 1,
                   drop_n_reducerk );
      }
  }
  return lua_gettop( L );
}

static int drop_n_reducer( lua_State* L ) {
  return drop_n_reducerk( L, 0, 0 );
}


LUA_KFUNCTION( dropk ) {
  int nx = 0, i = 1, j = 1, doassign = 0;
  (void)status;
  switch( ctx ) {
    case 0:
      if( is_callable( L, 1 ) ) { /* -> drop-while */
        if( lua_isfunction( L, 2 ) ) {
          lua_settop( L, 2 );
          lua_pushcclosure( L, drop_while_reducer, 2 );
          return 1;
        } else { /* work on sequence(-like object) */
          check_sequence( L, 2 );
          nx = lua_gettop( L )-2;
          lua_pushinteger( L, 1 ); /* store current iteration index */
          lua_newtable( L ); /* result table */
          luaL_checkstack( L, nx+3, "drop (while)" );
          do { /* pred, array, x_1, ..., x_n, i, res */
            lua_pushinteger( L, i );
            lua_gettable( L, 2 );
            if( lua_isnil( L, -1 ) ) {
              lua_pop( L, 1 );
              return 1;
            }
            if( j < 2 ) {
              lua_pushvalue( L, 1 );
              lua_pushvalue( L, -2 );
              for( j = 3; j <= nx+2; ++j )
                lua_pushvalue( L, j );
              lua_callk( L, nx+1, 1, 1, dropk );
    case 1: /* pred, array, x_1, ..., x_n, i, res, v, r */
              nx = lua_gettop( L )-6;
              i = lua_tointeger( L, nx+3 );
              if( !lua_toboolean( L, -1 ) )
                doassign = 1;
              lua_pop( L, 1 );
            } else
              doassign = 1;
            if( doassign ) {
              lua_rawseti( L, -2, j++ );
              ++i;
            } else {
              lua_pop( L, 1 );
              lua_pushinteger( L, ++i );
              lua_replace( L, nx+3 );
            }
          } while( 1 );
        }
      } else { /* -> drop-n */
        int n = luaL_checkinteger( L, 1 );
        if( lua_isfunction( L, 2 ) ) {
          lua_settop( L, 2 );
          lua_pushcclosure( L, drop_n_reducer, 2 );
          return 1;
        } else { /* work on sequence(-like object) */
          check_sequence( L, 2 );
          lua_settop( L, 2 );
          lua_newtable( L ); /* result table */
          do { /* n, array, res */
            lua_pushinteger( L, i );
            lua_gettable( L, 2 );
            if( lua_isnil( L, -1 ) ) {
              lua_pop( L, 1 );
              return 1;
            }
            if( i++ > n )
              lua_rawseti( L, -2, j++ );
            else
              lua_pop( L, 1 );
          } while( 1 );
        }
      }
  }
  /* should never happen: */
  return luaL_error( L, "invalid ctx in drop function" );
}

static int drop( lua_State* L ) {
  return dropk( L, 0, 0 );
}



LUA_KFUNCTION( reducek ) {
  int nx = 0, i = 1, j = 1;
  (void)status;
  /* use Duff's Device to allow yielding from multiple places */
  switch( ctx ) {
    case 0:
      check_callable( L, 1 );
      if( lua_isfunction( L, 3 ) ) { /* iterator */
        lua_settop( L, 5 );
        do { /* fun, init, f, s, var */
          lua_pushvalue( L, 1 );
          lua_pushvalue( L, 2 );
          lua_pushvalue( L, 3 );
          lua_pushvalue( L, 4 );
          lua_pushvalue( L, 5 );
          lua_callk( L, 2, LUA_MULTRET, 1, reducek );
    case 1: /* fun, init, f, s, var, fun, init, var_1, ... */
          if( lua_isnoneornil( L, 8 ) ) {
            lua_settop( L, 2 );
            return 1;
          }
          luaL_checkstack( L, 1, "reduce" );
          lua_pushvalue( L, 8 );
          lua_replace( L, 5 );
          lua_callk( L, lua_gettop( L )-6, 2, 2, reducek );
    case 2: /* fun, init, f, s, var_1, val, signal */
          if( is_stop( L, -1 ) ) {
            lua_pop( L, 1 );
            return 1;
          }
          lua_pop( L, 1 );
          lua_replace( L, 2 );
        } while( 1 );
      } else { /* plain sequence(-like object) */
        check_sequence( L, 3 );
        nx = lua_gettop( L )-3;
        lua_pushinteger( L, 1 ); /* store current iteration index */
        luaL_checkstack( L, nx+3, "reduce" );
        do { /* fun, init, array, x_1, ..., x_n, i */
          lua_pushvalue( L, 1 );
          lua_pushvalue( L, 2 );
          lua_pushvalue( L, -3 );
          lua_gettable( L, 3 );
          if( lua_isnil( L, -1 ) ) {
            lua_settop( L, 2 );
            return 1;
          }
          for( j = 4; j <= nx+3; ++j )
            lua_pushvalue( L, j );
          lua_callk( L, nx+2, 2, 3, reducek );
    case 3: /* fun, init, array, x_1, ..., x_n, i, val, signal */
          if( is_stop( L, -1 ) ) {
            lua_pop( L, 1 );
            return 1;
          }
          lua_pop( L, 1 );
          lua_replace( L, 2 );
          nx = lua_gettop( L )-4;
          i = lua_tointeger( L, -1 );
          lua_pop( L, 1 );
          lua_pushinteger( L, ++i );
        } while( 1 );
      }
  };
  /* should never happen: */
  return luaL_error( L, "invalid ctx in reduce function" );
}

static int reduce( lua_State* L ) {
  return reducek( L, 0, 0 );
}



static int export( lua_State* L ) {
  luaL_checktype( L, 1, LUA_TTABLE );
  if( lua_istable( L, 2 ) )
    lua_settop( L, 2 );
  else
    lua_pushglobaltable( L );
  lua_pushnil( L );
  while( lua_next( L, 1 ) ) {
    if( lua_type( L, -2 ) == LUA_TSTRING &&
        lua_tostring( L, -2 )[ 0 ] == '_' ) {
      lua_pop( L, 1 );
    } else {
      lua_pushvalue( L, -2 );
      lua_insert( L, -2 );
      lua_settable( L, -4 );
    }
  }
  lua_settop( L, 1 );
  return 1;
}



typedef struct {
  char const* name;
  int n;
} string_int_pair;


#ifndef FXLIB
#  define FXLIB
#endif

FXLIB int luaopen_fx( lua_State* L ) {
  luaL_Reg const functions[] = {
    { "curry", curry },
    { "compose", compose },
    { "map", map },
    { "filter", filter },
    { "take", take },
    { "drop", drop },
    { "reduce", reduce },
    { NULL, 0 }, /* reserve space for `has` */
    { NULL, 0 }, /* reserve space for `_` */
    { NULL, 0 }
  };
  string_int_pair const tocurry[] = {
    { "map", 2 },
    { "filter", 2 },
    { "take", 2 },
    { "drop", 2 },
    { "reduce", 3 },
    { NULL, 0 }
  };
  string_int_pair const* p = 0;
  luaL_newlib( L, functions );
  lua_newtable( L ); /* a cache */
  lua_pushcclosure( L, has, 1 );
  lua_setfield( L, -2, "has" );
  lua_pushlightuserdata( L, (void*)mark );
  lua_setfield( L, -2, "_" );
  for( p = tocurry; p->name != NULL; ++p ) {
    lua_getfield( L, -1, p->name );
    curryf( L, p->n );
    lua_setfield( L, -2, p->name );
  }
  lua_newtable( L );
  lua_pushcfunction( L, export );
  lua_setfield( L, -2, "__call" );
  lua_setmetatable( L, -2 );
  return 1;
}

