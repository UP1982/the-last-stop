#include <fcntl.h>
#include <stdarg.h>
#include <errno.h>
#include <stdlib.h>
/* Test-only dyld interposer: inject actual fcntl errno in production acquisition. */
static int e4_fcntl(int fd, int cmd, ...) {
    if (cmd == F_SETLK) { errno = atoi(getenv("TLS_E4_LOCK_ERRNO")); return -1; }
    if (cmd == F_GETFD || cmd == F_GETFL || cmd == F_GETOWN) return fcntl(fd,cmd);
    va_list ap; va_start(ap,cmd); void *arg = va_arg(ap,void*); va_end(ap);
    return fcntl(fd,cmd,arg);
}
__attribute__((used)) static struct { const void *replacement,*replacee; } interpose
__attribute__((section("__DATA,__interpose"))) = {(const void*)e4_fcntl,(const void*)fcntl};
