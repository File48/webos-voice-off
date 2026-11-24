#!/bin/sh
# Build lsnull for 32-bit ARM webOS (soft-float EABI, /lib/ld-linux.so.3).
#
# lsnull uses no libc of its own: it links only libluna-service2.so.3 and
# libglib-2.0.so.0, which the TV's dynamic linker resolves at runtime. So any
# arm-linux-gnueabi cross-compiler works, and there are no glibc version issues.
# Tiny stub .so files stand in for the TV's libraries at link time.
#
# Debian/Ubuntu: apt install gcc-arm-linux-gnueabi
set -e
CC=${CC:-arm-linux-gnueabi-gcc}
T=$(mktemp -d)
trap 'rm -rf "$T"' EXIT

cat > "$T/ls.c" <<'C'
int LSErrorInit(void *e){return 0;}
int LSRegister(const char *n, void **h, void *e){return 0;}
int LSGmainAttach(void *h, void *l, void *e){return 0;}
C
cat > "$T/g.c" <<'C'
void *g_main_loop_new(void *c, int r){return 0;}
void g_main_loop_run(void *l){}
C
$CC -shared -nostdlib -Wl,-soname,libluna-service2.so.3 -o "$T/libluna-service2.so" "$T/ls.c"
$CC -shared -nostdlib -Wl,-soname,libglib-2.0.so.0 -o "$T/libglib-2.0.so" "$T/g.c"

$CC -Os -marm -march=armv7-a -fno-stack-protector -fno-builtin -nostdlib -nostartfiles -no-pie -fno-pic \
    -Wl,--dynamic-linker=/lib/ld-linux.so.3 -Wl,--hash-style=both -Wl,-z,noexecstack -Wl,--as-needed \
    -o lsnull lsnull.c -L"$T" -lluna-service2 -lglib-2.0 -s
echo "built lsnull"
