import std / [os, strutils]

switch("gc", "orc")
switch("tlsEmulation", "off")
# switch("define", "useMalloc")
switch("define", "host")
switch("define", "nimArcDebug")

let
  thirdPartyPath = projectDir() / ".." / "thirdparty"
#   mimallocPath = thirdPartyPath / "mimalloc"
#   mimallocStatic = "mimallocStatic=\"" & (mimallocPath / "src" / "static.c") & '"'
#   mimallocIncludePath = "mimallocIncludePath=\"" & (mimallocPath / "include") & '"'

# switch("define", mimallocStatic)
# switch("define", mimallocIncludePath)

switch("define", "host")
switch("define", "debug")

switch("path", thirdPartyPath)
switch("path", thirdPartyPath / "winim")
switch("path", thirdPartyPath / "sokol-nim" / "src")
switch("path", thirdPartyPath / "laser")

# patchFile("stdlib", "malloc", "alloc")

when defined Windows:
  switch("cc", "vcc")
  switch("passC", "/Zi /FS /Od")
  switch("passL", "/Zi /FS /Od")
  # switch("passC", "/fsanitize=address")