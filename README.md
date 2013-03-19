rockspec
========

The [rockspec format](http://luarocks.org/en/Rockspec_format) as used by [LuaRocks](http://luarocks.org/)
provides a way to specify how to fetch and install a Lua package:

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
simple case of a standalone module that only depends on Lua itself.

There is an [excellent guide](http://luarocks.org/en/Creating_a_rock)) to making rockspecs, which usefully 
distinguishes between all the meta information and `build`, which is where all the interesting stuff happens.



