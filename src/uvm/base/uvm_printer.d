//
//------------------------------------------------------------------------------
//   Copyright 2007-2011 Mentor Graphics Corporation
//   Copyright 2007-2011 Cadence Design Systems, Inc.
//   Copyright 2010      Synopsys, Inc.
//   Copyright 2012-2016 Coverify Systems Technology
//   All Rights Reserved Worldwide
//
//   Licensed under the Apache License, Version 2.0 (the
//   "License"); you may not use this file except in
//   compliance with the License.  You may obtain a copy of
//   the License at
//
//       http://www.apache.org/licenses/LICENSE-2.0
//
//   Unless required by applicable law or agreed to in
//   writing, software distributed under the License is
//   distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR
//   CONDITIONS OF ANY KIND, either express or implied.  See
//   the License for the specific language governing
//   permissions and limitations under the License.
//------------------------------------------------------------------------------


module uvm.base.uvm_printer;

import uvm.base.uvm_globals;
import std.conv: to;
import esdl.base.core: SimTime;
import std.traits: isFloatingPoint;
import std.string: format;


// GC hack to make sure that heap allocation with static scope
// are covered -- this is because of an error in druntime
// https://issues.dlang.org/show_bug.cgi?id=15513
import core.memory: GC;

enum int UVM_STDOUT = 1;  // Writes to standard out and logfile

struct uvm_printer_row_info
{
  size_t level;
  string name;
  string type_name;
  string size;
  string val;
}


//------------------------------------------------------------------------------
//
// Class: uvm_printer
//
// The uvm_printer class provides an interface for printing <uvm_objects> in
// various formats. Subtypes of uvm_printer implement different print formats,
// or policies.
//
// A user-defined printer format can be created, or one of the following four
// built-in printers can be used:
//
// - <uvm_printer> - provides base printer functionality; must be overridden.
//
// - <uvm_table_printer> - prints the object in a tabular form.
//
// - <uvm_tree_printer> - prints the object in a tree form.
//
// - <uvm_line_printer> - prints the information on a single line, but uses the
//   same object separators as the tree printer.
//
// Printers have knobs that you use to control what and how information is printed.
// These knobs are contained in a separate knob class:
//
// - <uvm_printer_knobs> - common printer settings
//
// For convenience, global instances of each printer type are available for
// direct reference in your testbenches.
//
//  -  <uvm_default_tree_printer>
//  -  <uvm_default_line_printer>
//  -  <uvm_default_table_printer>
//  -  <uvm_default_printer> (set to default_table_printer by default)
//
// When <uvm_object::print> and <uvm_object::sprint> are called without
// specifying a printer, the <uvm_default_printer> is used.
//
//------------------------------------------------------------------------------

import esdl.data.bvec;
import uvm.base.uvm_misc;
import uvm.base.uvm_object;
import uvm.base.uvm_object_globals;
import uvm.base.uvm_component;
import uvm.meta.misc;
import uvm.meta.meta;
import std.traits: isIntegral;

abstract class uvm_printer
{

  mixin uvm_sync;

  // Variable: knobs
  //
  // The knob object provides access to the variety of knobs associated with a
  // specific printer instance.
  //
  @uvm_immutable_sync
  private uvm_printer_knobs _knobs; // = new;

  // SV implementation uses a Queue, but a dynamic array will be OK as well
  private bool[] _m_array_stack;
  @uvm_immutable_sync
  private uvm_scope_stack _m_scope; // = new;
  @uvm_public_sync
  private string _m_string;

  // holds each cell entry
  // SV implementation uses a Queue, but a dynamic array will be OK as well
  private uvm_printer_row_info[] _m_rows;

  this() {
    synchronized(this) {
      _knobs = new uvm_printer_knobs();
      _m_scope = new uvm_scope_stack();
    }
  }

  // Group: Methods for printer usage

  // These functions are called from <uvm_object::print>, or they are called
  // directly on any data to get formatted printing.

  // Function: print_field
  //
  // Prints an integral field (up to 4096 bits).
  //
  // name  - The name of the field.
  // value - The value of the field.
  // size  - The number of bits of the field (maximum is 4096).
  // radix - The radix to use for printing. The printer knob for radix is used
  //           if no radix is specified.
  // scope_separator - is used to find the leaf name since many printers only
  //           print the leaf name of a field.  Typical values for the separator
  //           are . (dot) or [ (open bracket).

  void print(T)(string          name,
		T               value,
		uvm_radix_enum  radix=UVM_NORADIX,
		char            scope_separator='.',
		string          type_name="")
    if(isBitVector!T || isIntegral!T || is(T: bool)) {
      print_int!T(name, value, -1, radix, scope_separator, type_name);
    }

  void print_integral(T)(string          name,
			 T               value,
			 ptrdiff_t       size = -1,
			 uvm_radix_enum  radix=UVM_NORADIX,
			 char            scope_separator='.',
			 string          type_name="")
    if(isBitVector!T || isIntegral!T || is(T: bool)) {
      synchronized(this) {
	if(size < 0) {
	  static if(is(T: bool)) {
	    size = 1;
	  }
	  else static if(isBitVector!T) {
	    size = T.SIZE;
	  }
	  else static if(isIntegral!T) {
	    size = T.sizeof * 8;
	  }
	}

	uvm_printer_row_info row_info;
	import std.conv: to;

	if(name != "") {
	  m_scope.set_arg(name);
	  name = m_scope.get();
	}

	if(type_name == "") {
	  if(radix is UVM_TIME)        type_name = "time";
	  else if(radix is UVM_STRING) type_name = "string";
	  else if(radix is UVM_ENUM)   type_name = "enum";
	  else                         type_name = "integral";
	}

	auto sz_str = size.to!string;

	if(radix is UVM_NORADIX) radix = knobs.default_radix;

	auto val_str = uvm_bitvec_to_string(value, size, radix,
					    knobs.get_radix_str(radix));

	row_info.level = m_scope.depth();
	row_info.name = adjust_name(name,scope_separator);
	row_info.type_name = type_name;
	row_info.size = sz_str;
	row_info.val = val_str;

	_m_rows ~= row_info;

      }
    }

  // backward compatibility
  alias print_field_int = print_integral;
  alias print_field = print_integral;
  alias print_int = print_field;

  // Function: print_object
  //
  // Prints an object. Whether the object is recursed depends on a variety of
  // knobs, such as the depth knob; if the current depth is at or below the
  // depth setting, then the object is not recursed.
  //
  // By default, the children of <uvm_components> are printed. To turn this
  // behavior off, you must set the <uvm_component::print_enabled> bit to 0 for
  // the specific children you do not want automatically printed.

  void print(T)(string     name,
		T          value,
		char       scope_separator='.')
    if(is(T: uvm_object)) {
      synchronized(this) {
	print_object_header(name, value, scope_separator);

	if(value !is null) {
	  if((knobs.depth == -1 || (knobs.depth > m_scope.depth())) &&
	     ! value.m_uvm_status_container.check_cycle(value)) {

	    value.m_uvm_status_container.add_cycle(value);
	    if(name == "" && value !is null) {
	      m_scope.down(value.get_name());
	    }
	    else {
	      m_scope.down(name);
	    }
	    auto comp = cast(uvm_component) value;
	    //Handle children of the comp
	    if(comp !is null) {
	      foreach(child; comp.get_children()) {
		auto child_comp = cast(uvm_component) child;
		if (child_comp !is null && child_comp.print_enabled) {
		  this.print("", child_comp);
		}
	      }
	    }

	    // print members of object
	    value.sprint(this);

	    if(name != "" && name[0] == '[') {
	      m_scope.up('[');
	    }
	    else {
	      m_scope.up('.');
	    }
	    value.m_uvm_status_container.remove_cycle(value);
	  }
	}
      }
    }

  alias print_object = print;


  void print_object_header (string name,
			    uvm_object value,
			    char scope_separator='.') {
    synchronized(this) {
      uvm_printer_row_info row_info;

      if(name == "") {
	if(value !is null) {
	  auto comp = cast(uvm_component) value;
	  if((m_scope.depth() is 0) && comp !is null) {
	    name = comp.get_full_name();
	  }
	  else {
	    name = value.get_name();
	  }
	}
      }

      if(name == "") {
	name = "<unnamed>";
      }

      m_scope.set_arg(name);

      row_info.level = m_scope.depth();

      if(row_info.level == 0 && knobs.show_root == true) {
	row_info.name = value.get_full_name();
      }
      else {
	row_info.name = adjust_name(m_scope.get(), scope_separator);
      }

      row_info.type_name = (value !is null) ? value.get_type_name() : "object";
      row_info.size = "-";
      row_info.val = knobs.reference ? uvm_object_value_str(value) : "-";

      _m_rows ~= row_info;
    }
  }


  // Function: print_string
  //
  // Prints a string field.

  void print(T)(string name,
		T      value,
		char   scope_separator = '.')
    if(is(T == string)) {
      synchronized(this) {
	uvm_printer_row_info row_info;

	if(name != "") {
	  m_scope.set_arg(name);
	}

	row_info.level = m_scope.depth();
	row_info.name = adjust_name(m_scope.get(),scope_separator);
	row_info.type_name = "string";
	row_info.size = format("%0d", value.length);
	row_info.val = (value == "" ? "\"\"" : value);

	_m_rows ~= row_info;
      }
    }
  alias print_string = print;

  // Function: print_time
  //
  // Prints a time value. name is the name of the field, and value is the
  // value to print.
  //
  // The print is subject to the ~$timeformat~ system task for formatting time
  // values.

  void print(T)(string name,
		T      value,
		char   scope_separator='.')
    if(is(T == SimTime)) {
      synchronized(this) {
	print(name, value.to!ulong, UVM_TIME, scope_separator);
      }
    }

  alias print_time = print;

  // Function: print_string
  //
  // Prints a string field.

  void print(T)(string  name,
		T       value,
		char    scope_separator = '.')
    if(isFloatingPoint!T) {
      synchronized(this) {

	uvm_printer_row_info row_info;

	if (name != "" && name != "...") {
	  m_scope.set_arg(name);
	  name = m_scope.get();
	}

	row_info.level = m_scope.depth();
	row_info.name = adjust_name(m_scope.get(), scope_separator);
	row_info.type_name = qualifiedTypeName!T;
	row_info.size = (T.sizeof*8).to!string();
	row_info.val = format("%f",value);

	_m_rows ~= row_info;

      }
    }
  alias print_real = print;

  // Function: print_generic
  //
  // Prints a field having the given ~name~, ~type_name~, ~size~, and ~value~.

  void print_generic(string     name,
		     string     type_name,
		     size_t     size,
		     string     value,
		     char       scope_separator='.') {
    synchronized(this) {

      uvm_printer_row_info row_info;

      if (name != "" && name != "...") {
	m_scope.set_arg(name);
	name = m_scope.get();
      }

      row_info.level = m_scope.depth();
      row_info.name = adjust_name(name,scope_separator);
      row_info.type_name = type_name;
      row_info.size = (size is -2 ? "..." : format("%0d",size));
      row_info.val = (value == "" ? "\"\"" : value);

      _m_rows ~= row_info;

    }
  }

  // Group: Methods for printer subtyping

  // Function: emit
  //
  // Emits a string representing the contents of an object
  // in a format defined by an extension of this object.
  //
  abstract string emit();		// abstract
  //  {
  //   uvm_error("NO_OVERRIDE","emit() method not overridden in printer subtype");
  //   return "";
  // }


  // Function: format_row
  //
  // Hook for producing custom output of a single field (row).
  //
  string format_row (uvm_printer_row_info row) {
    return "";
  }


  // Function: format_row
  //
  // Hook to override base header with a custom header.
  string format_header() {
    return "";
  }


  // Function: format_header
  //
  // Hook to override base footer with a custom footer.
  string format_footer() {
    return "";
  }


  // Function: adjust_name
  //
  // Prints a field's name, or ~id~, which is the full instance name.
  //
  // The intent of the separator is to mark where the leaf name starts if the
  // printer if configured to print only the leaf name of the identifier.

  protected string adjust_name (string id, char scope_separator='.') {
    synchronized(this) {
      if(knobs.show_root && m_scope.depth() == 0 ||
	 knobs.full_name || id == "...") {
	return id;
      }
      return uvm_leaf_scope(id, scope_separator);
    }
  }

  // Function: print_array_header
  //
  // Prints the header of an array. This function is called before each
  // individual element is printed. <print_array_footer> is called to mark the
  // completion of array printing.

  void print_array_header(string name,
			  size_t size,
			  string arraytype="array",
			  char   scope_separator='.') {
    synchronized(this) {

      uvm_printer_row_info row_info;

      if(name != "") {
	m_scope.set_arg(name);
      }

      row_info.level = m_scope.depth();
      row_info.name = adjust_name(m_scope.get(), scope_separator);
      row_info.type_name = arraytype;
      row_info.size = format("%0d", size);
      row_info.val = "-";

      _m_rows ~= row_info;

      m_scope.down(name);
      _m_array_stack ~= true;
    }
  }

  // Function: print_array_range
  //
  // Prints a range using ellipses for values. This method is used when honoring
  // the array knobs for partial printing of large arrays,
  // <uvm_printer_knobs::begin_elements> and <uvm_printer_knobs::end_elements>.
  //
  // This function should be called after begin_elements have been printed
  // and before end_elements have been printed.

  void print_array_range (int min, int max) {
    // string tmpstr; // redundant -- declared in the SV version
    if(min == -1 && max == -1) {
      return;
    }
    if(min == -1) {
      min = max;
    }
    if(max == -1) {
      max = min;
    }
    if(max < min) {
      return;
    }
    print_generic("...", "...", -2, "...");
  }


  // Function: print_array_footer
  //
  // Prints the header of a footer. This function marks the end of an array
  // print. Generally, there is no output associated with the array footer, but
  // this method lets the printer know that the array printing is complete.

  void print_array_footer (size_t size=0) {
    synchronized(this) {
      if(_m_array_stack.length) {
	m_scope.up();
	_m_array_stack = _m_array_stack[1..$];
      }
    }
  }


  // Utility methods
  final bool istop () {
    synchronized(this) {
      return (m_scope.depth() == 0);
    }
  }

  static string index_string (int index, string name="") {
    return name ~ "[" ~ index.to!string() ~ "]";
  }
} // endclass

//------------------------------------------------------------------------------
//
// Class: uvm_table_printer
//
// The table printer prints output in a tabular format.
//
// The following shows sample output from the table printer.
//
//|  ---------------------------------------------------
//|  Name        Type            Size        Value
//|  ---------------------------------------------------
//|  c1          container       -           @1013
//|  d1          mydata          -           @1022
//|  v1          integral        32          'hcb8f1c97
//|  e1          enum            32          THREE
//|  str         string          2           hi
//|  value       integral        12          'h2d
//|  ---------------------------------------------------
//
//------------------------------------------------------------------------------

class uvm_table_printer: uvm_printer {

  // Variable: new
  //
  // Creates a new instance of ~uvm_table_printer~.
  //
  this () {
    super();
  }

  // Function: emit
  //
  // Formats the collected information from prior calls to ~print_*~
  // into table format.
  //
  override final string emit() {
    synchronized(this) {
      import uvm.base.uvm_root;

      char[] s;
      string user_format;
      static char[] dash; // = "---------------------------------------------------------------------------------------------------";
      static char[] space; // = "                                                                                                   ";
      char[] dashes;

      string linefeed = "\n" ~ knobs.prefix;

      calculate_max_widths();

      import std.algorithm: max;
      size_t m = max(_m_max_name, _m_max_type, _m_max_size, _m_max_value, 100);

      if(dash.length < m) {
	// GC hack to make sure that heap allocation with static scope
	// are covered -- this is because of an error in druntime
	// https://issues.dlang.org/show_bug.cgi?id=15513
	GC.disable();
	if(dash.length != 0) {
	  GC.removeRoot(dash.ptr);
	  GC.removeRoot(space.ptr);
	}
	dash.length = m;
	dash[] = '-';
	space.length = m;
	space[] = ' ';
	GC.addRoot(dash.ptr);
	GC.addRoot(space.ptr);
	GC.enable();
      }

      if(knobs.header) {
	char[] header;
	user_format = format_header();
	if(user_format == "") {
	  string dash_id, dash_typ, dash_sz;
	  string head_id, head_typ, head_sz;
	  if(knobs.identifier) {
	    dashes = dash[0.._m_max_name+2];
	    header = "Name" ~ space[0.._m_max_name-2];
	  }
	  if(knobs.type_name) {
	    dashes = dashes ~ dash[0.._m_max_type+2];
	    header = header ~ "Type" ~ space[0.._m_max_type-2];
	  }
	  if(knobs.size) {
	    dashes = dashes ~ dash[0.._m_max_size+2];
	    header = header ~ "Size" ~ space[0.._m_max_size-2];
	  }
	  dashes = dashes ~ dash[0.._m_max_value] ~ linefeed;
	  header = header ~ "Value" ~ space[0.._m_max_value-5] ~ linefeed;

	  s ~= dashes ~ header ~ dashes;
	}
	else {
	  s ~= user_format ~ linefeed;
	}
      }

      foreach (row; _m_rows) {
	user_format = format_row(row);
	if (user_format == "") {
	  char[] row_str;
	  if (knobs.identifier) {
	    row_str = space[0..row.level*knobs.indent] ~ row.name ~
	      space[0.._m_max_name-row.name.length-(row.level*knobs.indent)+2];
	  }
	  if (knobs.type_name) {
	    row_str = row_str ~ row.type_name ~
	      space[0.._m_max_type-row.type_name.length+2];
	  }
	  if (knobs.size) {
	    row_str = row_str ~ row.size ~
	      space[0.._m_max_size-row.size.length+2];
	  }
	  s ~= row_str ~ row.val ~ space[0.._m_max_value-row.val.length]
	    ~ linefeed;
	}
	else {
	  s ~= user_format ~ linefeed;
	}
      }

      if (knobs.footer) {
	user_format = format_footer();
	if (user_format == "") {
	  s ~= dashes;
	}
	else {
	  s ~= user_format ~ linefeed;
	}
      }

      // _m_rows.delete();
      _m_rows.length = 0;
      return cast(string) (knobs.prefix ~ s);
    }
  }

  // Variables- m_max_*
  //
  // holds max size of each column, so table columns can be resized dynamically

  private size_t _m_max_name;
  private size_t _m_max_type;
  private size_t _m_max_size;
  private size_t _m_max_value;

  final void calculate_max_widths() {
    synchronized(this) {
      _m_max_name = 4;
      _m_max_type = 4;
      _m_max_size = 4;
      _m_max_value = 5;
      foreach(row; _m_rows) {
	// uvm_printer_row_info row = _m_rows[j];
	auto name_len = knobs.indent*row.level + row.name.length;
	if (name_len > _m_max_name) {
	  _m_max_name =  name_len;
	}
	if (row.type_name.length > _m_max_type) {
	  _m_max_type = row.type_name.length;
	}
	if (row.size.length > _m_max_size) {
	  _m_max_size = row.size.length;
	}
	if (row.val.length > _m_max_value) {
	  _m_max_value = row.val.length;
	}
      }
    }
  }
} // endclass


//------------------------------------------------------------------------------
//
// Class: uvm_tree_printer
//
// By overriding various methods of the <uvm_printer> super class,
// the tree printer prints output in a tree format.
//
// The following shows sample output from the tree printer.
//
//|  c1: (container@1013) {
//|    d1: (mydata@1022) {
//|         v1: 'hcb8f1c97
//|         e1: THREE
//|         str: hi
//|    }
//|    value: 'h2d
//|  }
//
//------------------------------------------------------------------------------

class uvm_tree_printer: uvm_printer {

  private string _newline = "\n";

  // Variable: new
  //
  // Creates a new instance of ~uvm_tree_printer~.

  this() {
    synchronized(this) {
      super();
      knobs.size = 0;
      knobs.type_name = 0;
      knobs.header = 0;
      knobs.footer = 0;
    }
  }

  // Function: emit
  //
  // Formats the collected information from prior calls to ~print_*~
  // into hierarchical tree format.
  //
  override final string emit() {
    synchronized(this) {

      string s = knobs.prefix;
      string space= "                                                                                                   ";
      string user_format;

      string linefeed = _newline == "" || _newline == " " ?
	_newline : _newline ~ knobs.prefix;

      // Header
      if (knobs.header) {
	user_format = format_header();
	if (user_format != "") {
	  s ~= user_format ~ linefeed;
	}
      }

      foreach (i, row; _m_rows) {
	user_format = format_row(row);
	if (user_format == "") {
	  auto indent_str = space[0..row.level * knobs.indent];

	  // Name (id)
	  if (knobs.identifier) {
	    s ~= indent_str ~ row.name;
	    if (row.name != "" && row.name != "...") {
	      s ~= ": ";
	    }
	  }

	  // Type Name
	  if (row.val[0] == '@') { // is an object w/ knobs.reference on
	    s ~= "(" ~ row.type_name ~ row.val ~ ") ";
	  }
	  else {
	    if (knobs.type_name &&
		(row.type_name != "" ||
		 row.type_name != "-" ||
		 row.type_name != "...")) {
	      s ~= "(" ~ row.type_name ~ ") ";
	    }
	  }

	  // Size
	  if (knobs.size) {
	    if (row.size != "" || row.size != "-") {
	      s ~= "(" ~ row.size ~ ") ";
	    }
	  }

	  if (i < _m_rows.length-1) {
	    if (_m_rows[i+1].level > row.level) {
	      s ~= knobs.separator[0] ~ linefeed;
	      continue;
	    }
	  }

	  // Value (unconditional)
	  s ~= row.val ~ " " ~ linefeed;

	  // Scope handling...
	  if (i <= _m_rows.length-1) {
	    size_t end_level;
	    if (i == _m_rows.length-1) {
	      end_level = 0;
	    }
	    else {
	      end_level = _m_rows[i+1].level;
	    }
	    if (end_level < row.level) {
	      for (size_t l=row.level-1; l >= end_level; --l) {
		auto str = space[0..l * knobs.indent];
		s ~= str ~ knobs.separator[1] ~ linefeed;
	      }
	    }
	  }

	}
	else s ~= user_format;
      }

      // Footer
      if (knobs.footer) {
	user_format = format_footer();
	if (user_format != "") {
	  s ~= user_format ~ linefeed;
	}
      }

      if (_newline == "" || _newline == " ") {
	s ~= "\n";
      }

      _m_rows.length = 0;

      return s;
    }
  }
} // endclass



//------------------------------------------------------------------------------
//
// Class: uvm_line_printer
//
// The line printer prints output in a line format.
//
// The following shows sample output from the line printer.
//
//| c1: (container@1013) { d1: (mydata@1022) { v1: 'hcb8f1c97 e1: THREE str: hi } value: 'h2d }
//------------------------------------------------------------------------------

class uvm_line_printer: /*extends*/ uvm_tree_printer {

  // Variable: new
  //
  // Creates a new instance of ~uvm_line_printer~. It differs from the
  // <uvm_tree_printer> only in that the output contains no line-feeds
  // and indentation.

  this() {
    synchronized(this) {
      _newline = " ";
      _knobs.indent = 0;
    }
  }
} // endclass



//------------------------------------------------------------------------------
//
// Class: uvm_printer_knobs
//
// The ~uvm_printer_knobs~ class defines the printer settings available to all
// printer subtypes.
//
//------------------------------------------------------------------------------

import uvm.base.uvm_object_globals;
import uvm.meta.mcd;

class uvm_printer_knobs {
  // Variable: header
  //
  // Indicates whether the <print_header> function should be called when
  // printing an object.

  mixin uvm_sync;

  @uvm_public_sync
  private bool _header = true;


  // Variable: footer
  //
  // Indicates whether the <print_footer> function should be called when
  // printing an object.

  @uvm_public_sync
  private bool _footer = true;


  // Variable: full_name
  //
  // Indicates whether <adjust_name> should print the full name of an identifier
  // or just the leaf name.

  @uvm_public_sync
  private bool _full_name = false;


  // Variable: identifier
  //
  // Indicates whether <adjust_name> should print the identifier. This is useful
  // in cases where you just want the values of an object, but no identifiers.

  @uvm_public_sync
  private bool _identifier = true;


  // Variable: type_name
  //
  // Controls whether to print a field's type name.

  @uvm_public_sync
  private bool _type_name = true;


  // Variable: size
  //
  // Controls whether to print a field's size.

  @uvm_public_sync
  private bool _size = true;


  // Variable: depth
  //
  // Indicates how deep to recurse when printing objects.
  // A depth of -1 means to print everything.

  @uvm_public_sync
  private int _depth = -1;


  // Variable: reference
  //
  // Controls whether to print a unique reference ID for object handles.
  // The behavior of this knob is simulator-dependent.

  @uvm_public_sync
  private bool _reference = true;


  // Variable: begin_elements
  //
  // Defines the number of elements at the head of a list to print.
  // Use -1 for no max.

  private int _begin_elements = 5;


  // Variable: end_elements
  //
  // This defines the number of elements at the end of a list that
  // should be printed.

  private int _end_elements = 5;


  // Variable: prefix
  //
  // Specifies the string prepended to each output line

  @uvm_public_sync
  private string _prefix = "";


  // Variable: indent
  //
  // This knob specifies the number of spaces to use for level indentation.
  // The default level indentation is two spaces.

  @uvm_public_sync
  private int _indent = 2;


  // Variable: show_root
  //
  // This setting indicates whether or not the initial object that is printed
  // (when current depth is 0) prints the full path name. By default, the first
  // object is treated like all other objects and only the leaf name is printed.

  @uvm_public_sync
  private bool _show_root = false;


  // Variable: mcd
  //
  // This is a file descriptor, or multi-channel descriptor, that specifies
  // where the print output should be directed.
  //
  // By default, the output goes to the standard output of the simulator.

  @uvm_public_sync
  private MCD _mcd = UVM_STDOUT;


  // Variable: separator
  //
  // For tree printers only, determines the opening and closing
  // separators used for nested objects.

  @uvm_public_sync
  private string _separator = "{}";


  // Variable: show_radix
  //
  // Indicates whether the radix string ('h, and so on) should be prepended to
  // an integral value when one is printed.

  private bool
  _show_radix = true;


  // Variable: default_radix
  //
  // This knob sets the default radix to use for integral values when no radix
  // enum is explicitly supplied to the print_int() method.

  @uvm_public_sync
  private uvm_radix_enum _default_radix = UVM_HEX;


  // Variable: dec_radix
  //
  // This string should be prepended to the value of an integral type when a
  // radix of <UVM_DEC> is used for the radix of the integral object.
  //
  // When a negative number is printed, the radix is not printed since only
  // signed decimal values can print as negative.

  private string _dec_radix = "";


  // Variable: bin_radix
  //
  // This string should be prepended to the value of an integral type when a
  // radix of <UVM_BIN> is used for the radix of the integral object.

  private string _bin_radix = "";


  // Variable: oct_radix
  //
  // This string should be prepended to the value of an integral type when a
  // radix of <UVM_OCT> is used for the radix of the integral object.

  private string _oct_radix = "";


  // Variable: unsigned_radix
  //
  // This is the string which should be prepended to the value of an integral
  // type when a radix of <UVM_UNSIGNED> is used for the radix of the integral
  // object.

  private string _unsigned_radix = "";


  // Variable: hex_radix
  //
  // This string should be prepended to the value of an integral type when a
  // radix of <UVM_HEX> is used for the radix of the integral object.

  private string _hex_radix = "";


  // Function: get_radix_str
  //
  // Converts the radix from an enumerated to a printable radix according to
  // the radix printing knobs (bin_radix, and so on).

  string get_radix_str(uvm_radix_enum radix) {
    synchronized(this) {
      if(_show_radix is false) {
	return "";
      }
      if(radix == UVM_NORADIX) {
	radix = _default_radix;
      }
      switch(radix) {
      case UVM_BIN:      return _bin_radix;
      case UVM_OCT:      return _oct_radix;
      case UVM_DEC:      return _dec_radix;
      case UVM_HEX:      return _hex_radix;
      case UVM_UNSIGNED: return _unsigned_radix;
      default:           return "";
      }
    }
  }

  // Deprecated knobs, hereafter ignored
  private int _max_width = 999;
  private string _truncation = "+";
  private int _name_width = -1;
  private int _type_width = -1;
  private int _size_width = -1;
  private int _value_width = -1;
  private bool _sprint = true;

} // endclass


alias uvm_printer_knobs uvm_table_printer_knobs;
alias uvm_printer_knobs uvm_tree_printer_knobs;
