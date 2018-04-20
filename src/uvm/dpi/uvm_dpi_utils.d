module uvm.dpi.uvm_dpi_utils;

import core.stdc.string: strlen;

version(LDC) {
  import ldc.attributes;
}
 else {
   enum weak;
 }

class uvm_dpi_utils
{
  private __gshared uvm_dpi_utils _inst;

  private this() {		// singleton
    char* testname = uvm_dpi_get_testname();
    if (testname.strlen != 0) {
      import std.conv;
      _testname = testname.to!string();
    }
    char* verbosity = uvm_dpi_get_verbosity();
    if (verbosity.strlen != 0) {
      import std.conv;
      _verbosity = verbosity.to!string();
    }
  }
  
  static uvm_dpi_utils instance() {
    if (uvm_dpi_is_usable()) {
      synchronized {
	if (_inst is null) {
	  _inst = new uvm_dpi_utils();
	}
	return _inst;
      }
    }
    else {
      assert(false,
	     "uvm_dpi_utils should be used only after checking" ~
	     "uvm_dpi_is_usable returns true");
    }
  }

  immutable string _verbosity;
  immutable string _testname;

  string get_testname() {
    return _testname;
  }

  string get_verbosity() {
    return _verbosity;
  }
}

@weak extern(C) char* uvm_dpi_get_testname() {
  assert(false, "Function uvm_dpi_get_testname should be exported from SV");
}

@weak extern(C) char* uvm_dpi_get_verbosity() {
  assert(false, "Function uvm_dpi_get_verbosity should be exported from SV");
}

@weak extern(C) bool uvm_dpi_is_usable() {
  return false;
}
