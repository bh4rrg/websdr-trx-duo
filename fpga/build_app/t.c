#include <time.h>
#include <sys/stat.h>
#define UNW_LOCAL_ONLY
#include <libunwind.h>
int main(){ struct stat st; fstat(0,&st); unw_cursor_t c; unw_context_t uc; unw_getcontext(&uc); unw_init_local(&c,&uc); return time(0)+clock_gettime(0,0)+st.st_mtime+(int)unw_step(&c); }
