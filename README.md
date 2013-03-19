rockspec
========

The [rockspec format](http://luarocks.org/en/Rockspec_format) as used by [LuaRocks](http://luarocks.org/)
provides a way to specify how to fetch and install a Lua package:

  * exact package version, including of the rockspec itself
  * Its description and use
  * Its website and the email address of the maintainer
  * where to download the package
  * what other packages it needs and what operating systems it supports
  * what modules it installs, or how to build it (if it's a C extension)
  
Here is a fairly simple example:

```lua
-- alt-getopt-0.7.0-1.rockspec
package = "alt-getopt"
version = "0.7.0-1"
source = {
   url = "http://luaforge.net/frs/download.php/4260/lua-alt-getopt-0.7.0.tar.gz"
}
description = {
   summary = "Process application arguments the same way as getopt_long",
   detailed = [[
       alt-getopt is a module for Lua programming language for processing
       application's arguments the same way BSD/GNU getopt_long(3) functions do.
       The main goal is compatibility with SUS "Utility Syntax Guidelines"
       guidelines 3-13.
   ]],
   homepage = "http://luaforge.net/projects/alt-getopt/", 
   license = "MIT/X11" 
}
dependencies = {
   "lua >= 5.1"
}

build = {
   type = "builtin",
   modules = {
      ["alt_getopt"] = "alt_getopt.lua"
   }
}
```

It is somewhat 'tedious and error-prone' (to use my favourite Bjarne Stroustrup quote) to write a rockspec from scratch,
and generally we do what countless people have done with makefiles; we copy and modify something that
already works.  Note that it's necessary to name the file in a particular way consistent with its contents

      <package>-<package-version>-<rockspec-version>.rockspec
      
It's easy to leave out optional (but useful) information like `maintainer` in the `description` table.  And this is for the
simple case of a standalone module that only depends on Lua itself.  But this is all needed to fulfil our conditions
above.

There is an [excellent guide](http://luarocks.org/en/Creating_a_rock)) to making rockspecs, which usefully 
distinguishes between all the meta information and `build`, which is where all the interesting stuff happens. The
LuaRocks build rules are very powerful, and often under-used because (a) we already have a makefile which
works 'on this machine' (b) it takes care to specify the build.  If you use the LuaRocks built-in build mode as
much as possible, then there is a guarantee of portability, since LuaRocks will use the available system
compiler (MSVC/mingw for Windows, otherwise gcc) and do the copying of the resulting shared libraries to
their appointed place.

`rockspec` is a command-line tool for generating rockspecs, much as Premake generates makefiles. It runs Lua
scripts called 'specfiles' and defines a DSL for specifying LuaRocks builds.

## Simple Usage

In the simplest case, you do not even have to provide a specfile.
Here is the procedure I followed to install `rockspec` itself:

```sh
~/lua/rockspec$ lua rockspec --git --depends penlight --script rockspec
rockspec-0.7-1.rockspec
~/lua/rockspec$ luarocks make --local rockspec-0.7-1.rockspec
Warning: Directory 'doc' not found
Updating manifest for /home/azisa/.luarocks/lib/luarocks/rocks

rockspec 0.7-1 is now built and installed in /home/azisa/.luarocks/ (license: MIT/X11)
```
The `--git` flag finds out things like the package name, version and repo from querying my Git setup, so
I end up with something which is pretty much ready to go:

```lua
--rockspec-0.7-1.rockspec
package = "rockspec"
version = "0.7-1"

source = {
  url = "git://github.com/stevedonovan/rockspec.git",
  tag="0.7"
}

description = {
  summary = "one-line about rockspec",
  detailed = [[
   Some details about
   rockspec
  ]],
  license = "MIT/X11",
  homepage = "https://github.com/stevedonovan/rockspec",
  maintainer = "steve.j.donovan@gmail.com"
}

dependencies = {
  "penlight"
}

build = {
  type = "none",
  install = {
    bin = {
      "rockspec"
    }
  }
}
```

I used the very useful LuaRocks `make` command, which works locally and does not use the `source` field. With the
`--local` flag it installs to the local tree, which means we don't have to be a superuser when developing.

This is a useful file that allows your Lua to see the local LuaRocks tree:

```sh
# luarocks-path (source this)
LR=$(HOME)/.luarocks
export PATH=$PATH:$LR/bin
SHARE=$LR/share/lua/5.1
LIB=$LR/lib/lua/5.1
export LUA_PATH=";;$SHARE/?.lua;$SHARE/?/init.lua"
export LUA_CPATH=";;$LIB/?.so"
```
Thereafter, I can directly execute scripts or require modules that are installed locally:

```sh
~/lua/rockspec$ . luarocks-path
~/lua/rockspec$ rockspec
please provide a specfile or either -s or -m

rockspec [flags] spec-script
    -d,--depends (default '') list of dependencies
    -s,--script  (default '') script to be installed
    -m,--module  (default '') Lua module(s) to be installed; can be a dir
    -g,--git   get Git config data for user and repo information
    -v,--version (default '1.0') Version of package
    -b,--build dump out build section
```

After pushing to Github (and remembering the all-important `git push --tags`) we can test the install:

```sh
~/lua/rockspec$ luarocks install --local rockspec-0.7-1.rockspec 
Using rockspec-0.7-1.rockspec... switching to 'build' mode
Initialized empty Git repository in /tmp/luarocks_rockspec-0.7-1-2688/rockspec/.git/
remote: Counting objects: 8, done.
remote: Compressing objects: 100% (7/7), done.
remote: Total 8 (delta 0), reused 5 (delta 0)
Receiving objects: 100% (8/8), 5.55 KiB, done.
Note: checking out '0.7'.
.....
HEAD is now at 2ea2487... first commit
Warning: Directory 'doc' not found
Updating manifest for /home/azisa/.luarocks/lib/luarocks/rocks

rockspec 0.7-1 is now built and installed in /home/azisa/.luarocks/ (license: MIT/X11)
```

LuaRocks' ability to work with Git repos can really simplify the job of creating and deploying rockspecs.
A common misunderstanding is that this always requires the user to have Git installed.  But when you
submit your rockspec to the LuaRocks mailing list `luarocks-developers@lists.sourceforge.net` then Hisham
(or one of his kindly elves) will _build a rock_, which is an archive containing the contents of your repo at
that tag; thereafter, users installing `rockspec` will actually be downloading this prebuilt rock, not directly
from the repo.

In a similar fashion, installing simple modules is straightforward:

```sh
~/lua/rockspec$ cat > foo.lua
local foo = {}
function foo.answer() return 42 end
return foo
~/lua/rockspec$ rockspec -b -m foo
{
  type = "builtin",
  modules = {
    foo = "foo.lua"
  }
}
~/lua/rockspec$ rockspec -m foo
foo-1.0-1.rockspec
~/lua/rockspec$ luarocks make --local foo-1.0-1.rockspec 
...
~/lua/rockspec$ lua
Lua 5.1.4  Copyright (C) 1994-2008 Lua.org, PUC-Rio
> foo = require 'foo'
> = foo.answer()
42
```
(Note the `-b` flag which dumps out the `build` part of the rockspec). The `-m` or `--module` flag installs
one or more modules,e.g `rockspec -m 'foo.init, foo.utils', assuming you have a subdirectory called `foo` with
those Lua files.

## The Specfile DSL

```lua
-- foo.rockspec.lua
package('foo','1.0')
Lua.install.script 'foo'
Lua.module.boo()
```

Dumping out the generated `build` using the `-b` flag:

```sh
~/lua/rockspec/examples$ rockspec -b foo.rockspec.lua
{
  type = "builtin",
  modules = {
    boo = "boo.lua"
  },
  install = {
    bin = {
      "foo"
    }
  }
}
```
That's cute, but not much more involved that the simple command-line invocations.  It is always a good idea to 
specify the package name and vesion, and then you can install scripts or modules.

Things get more interesting with C extensions:

```lua
-- mylib.rockspec.lua
package('mylib','1.0')
C.module.mylib()
```
Invoked thus:

```sh
~/lua/rockspec/examples$ rockspec -b mylib.rockspec.lua
{
  type = "builtin",
  modules = {
    mylib = {
      sources = {
        "mylib.c"
      }
    }
  }
}
~/lua/rockspec/examples$ rockspec mylib.rockspec.lua
mylib-1.0-1.rockspec
~/lua/rockspec/examples$ luarocks make --local mylib-1.0-1.rockspec 
gcc -O2 -fPIC -I/usr/include/lua5.1 -c mylib.c -o mylib.o
gcc -shared -o mylib.so -L/usr/lib mylib.o
Warning: Directory 'doc' not found
Updating manifest for /home/azisa/.luarocks/lib/luarocks/rocks

mylib 1.0-1 is now built and installed in /home/azisa/.luarocks/ (license: MIT/X11)
~/lua/rockspec/examples$ lua -lmylib
Lua 5.1.4  Copyright (C) 1994-2008 Lua.org, PUC-Rio
> = mylib.createtable
function: 0x8453350

The LuaRocks 'builtin' build mode invokes the compiler directly, and knows where the Lua include files are on my
Ubuntu syatem.

This is common enough that there is a shortcut that does all of this:

```sh
~/lua/rockspec/examples$ rockspec --make -c mylib
```

The usual rockspec for LuaSocket uses a makefile, but naturally suffers from the portability issues that bedevil
all makefiles.  It is perfectly possible to use LuaSocket's 'builtin' mode to build and deploy LuaSocket:

```lua
package('luasocket','2.0.2','3')
C.module.socket.core [[
 luasocket.c auxiliar.c buffer.c except.c io.c tcp.c
 timeout.c udp.c options.c select.c inet.c
]]
:when 'unix' :add 'usocket.c'
:when 'win32'
  :add 'wsocket.c'
  :libraries 'winsock32'
```











