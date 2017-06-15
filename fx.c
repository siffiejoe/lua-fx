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

#define lua_load( L, r, d, s, m ) \
  ((void)m,lua_load( L, r, d, s ))

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


#if LUA_VERSION_NUM < 503

static void reverse( lua_State*, int, int );

/* idx must be positive for this implementation! */
static void lua_rotate( lua_State* L, int idx, int n ) {
  int n_elems = 0;
  n_elems = lua_gettop( L )-idx+1;
  if( n < 0 )
    n += n_elems;
  if( n > 0 && n < n_elems ) {
    luaL_checkstack( L, 2, "lua_rotate" );
    n = n_elems - n;
    reverse( L, idx, idx+n-1 );
    reverse( L, idx+n, idx+n_elems-1 );
    reverse( L, idx, idx+n_elems-1 );
  }
}

#endif /* LUA_VERSION_NUM < 503 */



#define STR_LAMBDA_PREFIX "return function("
#define STR_LAMBDA_INFIX ") return "
#define STR_LAMBDA_SUFFIX " end"

typedef struct {
  char const* code;
  size_t code_size;
  size_t fa_pos; /* position of the start of the fat arrow */
  int counter;
} str_lambda_data;

static char const* str_lambda_reader( lua_State* L, void* data,
                                      size_t* size ) {
  char const* s = NULL;
  str_lambda_data* d = data;
  (void)L;
  switch( d->counter ) {
    case 0:
      s = STR_LAMBDA_PREFIX;
      *size = sizeof( STR_LAMBDA_PREFIX )-1;
      break;
    case 1:
      s = d->fa_pos > 0 ? d->code : " ";
      *size = d->fa_pos > 0 ? d->fa_pos : 1;
      break;
    case 2:
      s = STR_LAMBDA_INFIX;
      *size = sizeof( STR_LAMBDA_INFIX )-1;
      break;
    case 3:
      s = d->code + d->fa_pos + 2;
      *size = d->code_size - (s - d->code);
      break;
    case 4:
      s= STR_LAMBDA_SUFFIX;
      *size = sizeof( STR_LAMBDA_SUFFIX )-1;
      break;
    default:
      *size = 0;
      break;
  }
  d->counter++;
  return s;
}


static void check_callable( lua_State* L, int i ) {
  int c = 0;
  switch( lua_type( L, i ) ) {
    case LUA_TFUNCTION:
      c = 1;
      break;
    case LUA_TUSERDATA: /* fall through */
    case LUA_TTABLE:
      if( luaL_getmetafield( L, i, "__call" ) ) {
        lua_pop( L, 1 );
        c = 1;
      }
      break;
    case LUA_TSTRING: {
      size_t code_size = 0;
      char const* code = lua_tolstring( L, i, &code_size );
      str_lambda_data d = { code, code_size, 0, 0 };
      char const* s = memchr( code, '=', code_size );
      if( !s || s[ 1 ] != '>' )
        luaL_argerror( L, i, "[lambda]:1: '=>' expected" );
      d.fa_pos = s - code;
      if( 0 != lua_load( L, str_lambda_reader, &d, "=[lambda]", NULL ) )
        luaL_argerror( L, i, lua_tostring( L, -1 ) );
      lua_call( L, 0, 1 );
      lua_replace( L, i );
      c = 1;
    }
  }
  luaL_argcheck( L, c, i, "callable value expected" );
}


static int check_index( lua_State* L, int idx ) {
  lua_Integer i = luaL_checkinteger( L, idx );
  luaL_argcheck( L, i >= INT_MIN && i <= INT_MAX && i != 0, idx,
                 "invalid index" );
  return i;
}
#define opt_index( L, idx, def ) (luaL_opt( L, check_index, idx, def ))


static int check_int( lua_State* L, int idx ) {
  lua_Integer i = luaL_checkinteger( L, idx );
  luaL_argcheck( L, i >= INT_MIN && i <= INT_MAX, idx,
                "invalid 'n'" );
  return i;
}
#define opt_int( L, idx, def ) (luaL_opt( L, check_int, idx, def ))


static int check_uint( lua_State* L, int idx ) {
  lua_Integer i = luaL_checkinteger( L, idx );
  luaL_argcheck( L, i >= 0 && i <= INT_MAX, idx,
                "invalid 'n'" );
  return i;
}
#define opt_uint( L, idx, def ) (luaL_opt( L, check_uint, idx, def ))


static int get_index( lua_State* L, int uvidx ) {
  int idx = lua_tointeger( L, lua_upvalueindex( uvidx ) );
  if( idx <= 0 )
    idx += lua_gettop( L )+1;
  if( idx <= 0 )
    luaL_error( L, "index out of bounds" );
  return idx;
}


static void reverse( lua_State* L, int a, int b ) {
  for( ; a < b; ++a, --b ) {
    lua_pushvalue( L, a );
    lua_pushvalue( L, b );
    lua_replace( L, a );
    lua_replace( L, b );
  }
}


/* unique addresses used as IDs/markers */
static char const mark[ 1 ];


/* enable/disable special handling of placeholder value: */
#if 1
#define is_gap( L, idx ) \
  (lua_touserdata( L, idx ) == (void*)mark)
#else
#define is_gap( L, idx ) (0)
#endif


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
      luaL_checkstack( L, k+m+5+LUA_MINSTACK, "curried" );
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
      luaL_checkstack( L, n+t+2+LUA_MINSTACK, "composed" );
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
        luaL_checkstack( L, LUA_MINSTACK, "composed" );
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
  luaL_argcheck( L, n < LUAI_MAXUPVALUES, LUAI_MAXUPVALUES,
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
  if( m == 1 ) /* no need for composing a single function */
    return 1;
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



#ifndef FXLIB
#ifdef _WIN32
#define FXLIB __declspec(dllexport)
#else
#define FXLIB
#endif
#endif

FXLIB int luaopen_fx_core( lua_State* L ) {
  luaL_Reg const functions[] = {
    { "curry", curry },
    { "compose", compose },
    { NULL, 0 }, /* reserve space for `has` */
    { NULL, 0 }, /* reserve space for `_` */
    { NULL, 0 }
  };
  luaL_newlib( L, functions );
  lua_newtable( L ); /* a cache */
  lua_pushcclosure( L, has, 1 );
  lua_setfield( L, -2, "has" );
  lua_pushlightuserdata( L, (void*)mark );
  lua_setfield( L, -2, "_" );
  lua_newtable( L );
  lua_pushcfunction( L, export );
  lua_setfield( L, -2, "__call" );
  lua_setmetatable( L, -2 );
  return 1;
}



/* Collection of glue functions that manipulate vararg lists to
 * make composing functions easier.
 */

LUA_KFUNCTION( vmapfk ) {
  int idx1, idx2, i, top = 0;
  (void)status;
  switch( ctx ) {
    case 0: /* args ... */
      top = lua_gettop( L );
      idx1 = lua_tointeger( L, lua_upvalueindex( 2 ) );
      idx2 = lua_tointeger( L, lua_upvalueindex( 3 ) );
      if( idx1 != 0 ) {
        if( idx1 < 0 ) {
          idx1 += top+1;
          if( idx1 <= 0 )
            luaL_error( L, "index out of bounds" );
        } else if( idx1 > top ) {
          luaL_checkstack( L, idx1+4+LUA_MINSTACK, "vmap" );
          top = idx1-1;
          lua_settop( L, top );
        }
      } else
        idx1 = 1;
      if( idx2 != 0 ) {
        if( idx2 < 0 ) {
          idx2 += top+1;
          if( idx2 <= 0 )
            luaL_error( L, "index out of bounds" );
        } else if( idx2 > top ) {
          luaL_checkstack( L, idx2+4+LUA_MINSTACK, "vmap" );
          top = idx2;
          lua_settop( L, top );
        }
      } else
        idx2 = top;
      if( idx1 > idx2 )
        return top;
      lua_pushinteger( L, idx1+=3 );
      lua_pushinteger( L, idx2+=3 );
      lua_pushinteger( L, top ); /* number of arguments */
      lua_rotate( L, 1, 3 );
      luaL_checkstack( L, top+1+LUA_MINSTACK, "vmap" );
      for( i = 4; i < idx1; ++i )
        lua_pushvalue( L, i );
      while( idx1 <= idx2 ) {
        lua_pushvalue( L, lua_upvalueindex( 1 ) );
        lua_pushvalue( L, idx1 );
        lua_pushinteger( L, ++idx1 );
        lua_replace( L, 1 );
        lua_callk( L, 1, 1, 1, vmapfk );
    case 1: /* idx1, idx2, nargs, x1, ... xn, r1, r2, ... */
        idx1 = lua_tointeger( L, 1 );
        idx2 = lua_tointeger( L, 2 );
        top = lua_tointeger( L, 3 );
      }
      for( i = idx1; i <= top+3; ++i )
        lua_pushvalue( L, i );
  }
  return top;
}

static int vmapf( lua_State* L ) {
  return vmapfk( L, 0, 0 );
}

static int vmap( lua_State* L ) {
  int idx1, idx2;
  check_callable( L, 1 );
  idx1 = opt_index( L, 2, 0 );
  idx2 = opt_index( L, 3, 0 );
  lua_settop( L, 1 );
  lua_pushinteger( L, idx1 );
  lua_pushinteger( L, idx2 );
  lua_pushcclosure( L, vmapf, 3 );
  return 1;
}


LUA_KFUNCTION( vtransformfk ) {
  int n = lua_tointeger( L, lua_upvalueindex( 1 ) );
  int i = 1, j = 0, nargs = 0;
  (void)status;
  switch( ctx ) {
    case 0: /* args ... */
      nargs = lua_gettop( L );
      lua_pushinteger( L, i );
      lua_pushinteger( L, nargs );
      lua_rotate( L, 1, 2 ); /* i, nargs, args ... */
      luaL_checkstack( L, nargs+1+LUA_MINSTACK, "vtransform" );
      while( i <= n ) {
        lua_pushinteger( L, i+1 );
        lua_replace( L, 1 );
        lua_pushvalue( L, lua_upvalueindex( 1+i ) );
        for( j = i; j <= nargs; ++j )
          lua_pushvalue( L, 2+j );
        lua_callk( L, nargs >= i ? nargs-i+1 : 0,
                   i == n ? LUA_MULTRET : 1, 1, vtransformfk );
    case 1:
        i = lua_tointeger( L, 1 );
        nargs = lua_tointeger( L, 2 );
      }
  }
  return lua_gettop( L )-nargs-2;
}

static int vtransformf( lua_State* L ) {
  return vtransformfk( L, 0, 0 );
}

static int vtransform( lua_State* L ) {
  int i = 1, top = lua_gettop( L );
  luaL_argcheck( L, top < LUAI_MAXUPVALUES, LUAI_MAXUPVALUES,
                 "too many arguments" );
  for( i = 1; i <= top; ++i )
    check_callable( L, i );
  lua_pushinteger( L, top );
  lua_insert( L, 1 );
  lua_pushcclosure( L, vtransformf, top+1 );
  return 1;
}


static int vinsertf( lua_State* L ) {
  int idx = get_index( L, 1 ), top = lua_gettop( L );
  int n = lua_tointeger( L, lua_upvalueindex( 2 ) );
  int i = 0;
  if( idx > top ) {
    luaL_checkstack( L, idx+n, "vinsert" );
    top = idx-1;
    lua_settop( L, top );
  } else if( idx+n > top )
    luaL_checkstack( L, idx+n, "vinsert" );
  for( i = 0; i < n; ++i )
    lua_pushvalue( L, lua_upvalueindex( i+3 ) );
  lua_rotate( L, idx, n );
  return top+n;
}

static int vinsert( lua_State* L ) {
  int i = opt_index( L, 1, 0 );
  int top = lua_gettop( L );
  luaL_argcheck( L, top < LUAI_MAXUPVALUES, LUAI_MAXUPVALUES,
                 "too many arguments" );
  if( top < 2 )
    top = 2;
  lua_settop( L, top );
  lua_pushinteger( L, i );
  lua_replace( L, 1 );
  lua_pushinteger( L, top-1 );
  lua_insert( L, 2 );
  lua_pushcclosure( L, vinsertf, top+1 );
  return 1;
}


static int vreplacef( lua_State* L ) {
  int idx = get_index( L, 1 ), top = lua_gettop( L );
  int n = lua_tointeger( L, lua_upvalueindex( 2 ) );
  int i = 0;
  if( idx+n-1 > top ) {
    luaL_checkstack( L, idx+n-top, "vreplace" );
    top = idx+n-1;
    lua_settop( L, top );
  }
  for( i = 0; i < n; ++i ) {
    lua_pushvalue( L, lua_upvalueindex( i+3 ) );
    lua_replace( L, idx+i );
  }
  return top;
}

static int vreplace( lua_State* L ) {
  int top = lua_gettop( L );
  check_index( L, 1 );
  luaL_argcheck( L, top < LUAI_MAXUPVALUES, LUAI_MAXUPVALUES,
                 "too many arguments" );
  if( top < 2 )
    top = 2;
  lua_settop( L, top );
  lua_pushinteger( L, top-1 );
  lua_insert( L, 2 );
  lua_pushcclosure( L, vreplacef, top+1 );
  return 1;
}


static int vreversef( lua_State* L ) {
  int top = lua_gettop( L );
  if( top > 0 ) {
    int idx1 = get_index( L, 1 ), idx2 = get_index( L, 2 );
    int maxidx = idx1 > idx2 ? idx1 : idx2;
    if( maxidx > top ) {
      luaL_checkstack( L, maxidx-top+2, "vreverse" );
      lua_settop( L, maxidx );
      top = maxidx;
    }
    reverse( L, idx1, idx2 );
  }
  return top;
}

static int vreverse( lua_State* L ) {
  int i = opt_index( L, 1, 1 );
  int j = opt_index( L, 2, -1 );
  lua_settop( L, 0 );
  lua_pushinteger( L, i );
  lua_pushinteger( L, j );
  lua_pushcclosure( L, vreversef, 2 );
  return 1;
}


static int vrotatef( lua_State* L ) {
  int idx = get_index( L, 1 ), top = lua_gettop( L );
  int n = lua_tointeger( L, lua_upvalueindex( 2 ) );
  if( idx < top )
    lua_rotate( L, idx, n % (top-idx+1) );
  return top;
}

static int vrotate( lua_State* L ) {
  int i = opt_index( L, 1, 1 );
  int n = opt_int( L, 2, 1 );
  lua_settop( L, 0 );
  lua_pushinteger( L, i );
  lua_pushinteger( L, n );
  lua_pushcclosure( L, vrotatef, 2 );
  return 1;
}


FXLIB int luaopen_fx_glue( lua_State* L ) {
  luaL_Reg const functions[] = {
    { "vmap", vmap },
    { "vtransform", vtransform },
    { "vinsert", vinsert },
    { "vreplace", vreplace },
    { "vreverse", vreverse },
    { "vrotate", vrotate },
    { NULL, 0 }
  };
  luaL_newlib( L, functions );
  return 1;
}


#ifdef _WIN32
/* LuaRocks with MSVC can't really handle multiple modules in a single
 * DLL, so we have to export the luaopen_ functions ourselves, and let
 * LuaRocks think that fx.dll contains the fx module: */
int luaopen_fx( lua_State* L ) {
  luaL_error( L, "fx.lua not found" );
  return 0;
}
#endif

