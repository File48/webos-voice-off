/*
 * lsnull - register luna bus names and answer nothing.
 *
 * Every call to a registered name gets luna-service2's own immediate
 * "Unknown method" error, because no categories/methods are registered.
 * Callers fail fast instead of waiting on a static service that never comes up.
 *
 * Built without libc: talks only to libluna-service2 and libglib, resolved
 * by the TV's dynamic linker. Service names come from argv[0]'s basename,
 * or from argv[1..] if given.
 */
typedef struct { int code; char *msg; const char *f; int l; const char *fn; void *pad; unsigned long magic; } LSError;
typedef struct LSHandle LSHandle;
typedef struct GMainLoop GMainLoop;

int LSErrorInit(LSError *e);
int LSRegister(const char *name, LSHandle **sh, LSError *e);
int LSGmainAttach(LSHandle *sh, GMainLoop *loop, LSError *e);
GMainLoop *g_main_loop_new(void *ctx, int is_running);
void g_main_loop_run(GMainLoop *loop);

static long sys3(long n, long a, long b, long c) {
    register long r0 __asm__("r0") = a, r1 __asm__("r1") = b, r2 __asm__("r2") = c;
    register long r7 __asm__("r7") = n;
    __asm__ volatile("svc 0" : "+r"(r0) : "r"(r1), "r"(r2), "r"(r7) : "memory");
    return r0;
}
static unsigned slen(const char *s) { unsigned n = 0; while (s[n]) n++; return n; }
static void say(const char *s) { sys3(4, 2, (long)s, slen(s)); }            /* write(2, ...) */
static void die(const char *s) { say(s); for (;;) sys3(248, 1, 0, 0); }      /* exit_group(1) */
static int eq(const char *a, const char *b) { while (*a && *a == *b) a++, b++; return *a == *b; }

static const char *const voiceinput[]     = { "com.webos.service.voiceinput", "com.webos.service.voiceinput.sync", 0 };
static const char *const voiceconductor[] = { "com.webos.service.voiceconductor", 0 };

void c_main(long *sp) {
    int argc = (int)sp[0];
    const char **argv = (const char **)(sp + 1);
    const char *base = argv[0], *p;
    for (p = argv[0]; *p; p++) if (*p == '/') base = p + 1;

    const char *const *names;
    if (argc > 1) names = argv + 1;
    else if (eq(base, "voiceinput")) names = voiceinput;
    else if (eq(base, "voiceconductor")) names = voiceconductor;
    else die("lsnull: no service names (unknown argv[0], none given)\n");

    GMainLoop *loop = g_main_loop_new(0, 0);
    for (; *names; names++) {
        LSHandle *h = 0;
        LSError e;
        LSErrorInit(&e);
        if (!LSRegister(*names, &h, &e) || !LSGmainAttach(h, loop, &e)) {
            say("lsnull: failed to register "); say(*names);
            say(": "); say(e.msg ? e.msg : "?"); die("\n");
        }
        say("lsnull: registered "); say(*names); say("\n");
    }
    g_main_loop_run(loop);
    die("lsnull: main loop exited\n");
}

__asm__(".text\n.global _start\n.type _start,%function\n_start:\n"
        "  mov r0, sp\n  bic sp, sp, #7\n  bl c_main\n  b .\n");
