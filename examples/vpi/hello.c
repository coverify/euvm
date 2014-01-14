# include  <vpi_user.h>

extern void initEsdl();

void (*vlog_startup_routines[])() = {
  initEsdl,
  0
};

void get_handle() {
  vpiHandle co = vpi_handle_by_name("main", 0);
}
