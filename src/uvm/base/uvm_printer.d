//
//------------------------------------------------------------------------------
//   Copyright 2007-2011 Mentor Graphics Corporation
//   Copyright 2007-2011 Cadence Design Systems, Inc.
//   Copyright 2010 Synopsys, Inc.
//   Copyright 2012-2014 Coverify Systems Technology
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
import esdl.base.time;

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

abstract class uvm_printer
{
  import std.traits: isIntegral;

  mixin(uvm_sync!uvm_printer);

  // Variable: knobs
  //
  // The knob object provides access to the variety of knobs associated with a
  // specific printer instance.
  //
  @uvm_immutable_sync private uvm_printer_knobs _knobs; // = new;

  // SV implementation uses a Queue, but a dynamic array will be OK as well
  protected bool[] _m_array_stack;
  @uvm_immutable_sync private uvm_scope_stack _m_scope; // = new;
  @uvm_public_sync private string _m_string;

  // holds each cell entry
  // SV implementation uses a Queue, but a dynamic array will be OK as well
  protected uvm_printer_row_info[] _m_rows;

  this() {
    synchronized(this) {
      _knobs = new uvm_printer_knobs();
      _m_scope = new uvm_scope_stack();
    }
  }

  // Group: Methods for printer usage

  // These functions are called from <uvm_object::print>, or they are called
  // directly on any data to get formatted printing.

  // Function: print_int
  //
  // Prints an integral field.
  //
  // name  - The name of the field.
  // value - The value of the field.
  // size  - The number of bits of the field (maximum is 4096).
  // radix - The radix to use for printing. The printer knob for radix is used
  //           if no radix is specified.
  // scope_separator - is used to find the leaf name since many printers only
  //           print the leaf name of a field.  Typical values for the separator
  //           are . (dot) or [ (open bracket).

  public void print_int(T)(string          name,
			   T               value,
			   uvm_radix_enum  radix=UVM_NORADIX,
			   char            scope_separator='.',
			   string          type_name="")
    if(isBitVector!T || isIntegral!T || is(T == bool)) {
      synchronized(this) {
	uvm_printer_row_info row_info;
	import std.conv: to;

	if(name != "") {
	  _m_scope.set_arg(name);
	  name = _m_scope.get();
	}

	if(type_name == "") {
	  if(radix is UVM_TIME)        type_name = "time";
	  else if(radix is UVM_STRING) type_name = "string";
	  else                         type_name = "integral";
	}

	static if(isIntegral!T || is(T == bool)) enum size_t size = T.sizeof*8;
	else                                     enum size_t size = T.SIZE;

	auto sz_str = size.to!string;

	if(radix is UVM_NORADIX) radix = _knobs.default_radix;

	auto val_str = uvm_vector_to_string (value, radix,
					     _knobs.get_radix_str(radix));

	row_info.level = _m_scope.depth();
	row_info.name = adjust_name(name,scope_separator);
	row_info.type_name = type_name;
	row_info.size = sz_str;
	row_info.val = val_str;

	_m_rows ~= row_info;

      }
    }

  // backward compatibility
  alias print_int print_field;

  // Function: print_object
  //
  // Prints an object. Whether the object is recursed depends on a variety of
  // knobs, such as the depth knob; if the current depth is at or below the
  // depth setting, then the object is not recursed.
  //
  // By default, the children of <uvm_components> are printed. To turn this
  // behavior off, you must set the <uvm_component::print_enabled> bit to 0 for
  // the specific children you do not want automatically printed.

  public void print_object (string     name,
			    uvm_object value,
			    char       scope_separator='.') {
    synchronized(this) {
      print_object_header(name, value, scope_separator);

      if(value !is null) {
	if((_knobs.depth is -1 || (_knobs.depth > _m_scope.depth())) &&
	   value.m_uvm_status_container.check_cycle(value)) {
	  value.m_uvm_status_container.add_cycle(value);
	  if(name == "" && value !is null) _m_scope.down(value.get_name());
	  else                             _m_scope.down(name);
	  auto comp = cast(uvm_component) value;
	  //Handle children of the comp
	  if(comp !is null) {
	    foreach(child; comp.get_children()) {
	      auto child_comp = cast(uvm_component) child;
	      if (child_comp !is null && child_comp.print_enabled) {
		this.print_object("", child_comp);
	      }
	    }
	  }

	  // print members of object
	  value.sprint(this);

	  if(name != "" && name[0] is '[') _m_scope.up('[');
	  else                             _m_scope.up('.');
	  value.m_uvm_status_container.remove_cycle(value);
	}
      }
    }
  }


  public void print_object_header (string name,
				   uvm_object value,
				   char scope_separator='.') {
    synchronized(this) {
      uvm_printer_row_info row_info;

      if(name == "") {
	if(value !is null) {
	  auto comp = cast(uvm_component) value;
	  if((_m_scope.depth() is 0) && comp !is null) {
	    name = comp.get_full_name();
	  }
	  else {
	    name = value.get_name();
	  }
	}
      }

      if(name == "") name = "<unnamed>";

      _m_scope.set_arg(name);

      row_info.level = _m_scope.depth();

      if(row_info.level is 0 && _knobs.show_root is 1) {
	row_info.name = value.get_full_name();
      }
      else {
	row_info.name = adjust_name(_m_scope.get(),scope_separator);
      }

      row_info.type_name = (value !is null) ?value.get_type_name() : "object";
      row_info.size = "-";
      row_info.val = _knobs.reference ? uvm_object_value_str(value) : "-";

      _m_rows ~= row_info;
    }
  }


  // Function: print_string
  //
  // Prints a string field.

  public void print_string (string name,
			    string value,
			    char   scope_separator = '.') {
    synchronized(this) {
      // for format
      import std.string: format;

      uvm_printer_row_info row_info;

      if(name != "") _m_scope.set_arg(name);

      row_info.level = _m_scope.depth();
      row_info.name = adjust_name(_m_scope.get(),scope_separator);
      row_info.type_name = "string";
      row_info.size = format("%0d", value.length);
      row_info.val = (value == "" ? "\"\"" : value);

      _m_rows ~= row_info;
    }
  }


  // Function: print_time
  //
  // Prints a time value. name is the name of the field, and value is the
  // value to print.
  //
  // The print is subject to the ~$timeformat~ system task for formatting time
  // values.

  public void print_time(T)(string name,
			    T      value,
			    char   scope_separator='.')
    if(is(T == SimTime)) {
      synchronized(this) {
	print_int(name, cast(BitVec!(T.sizeof*8)) value, UVM_TIME, scope_separator);
      }
    }


  public void print_time(T)(string name,
			    T      value,
			    char   scope_separator='.')
    if(isIntegral!T) {
      synchronized(this) {
	print_int(name, value, UVM_TIME, scope_separator);
      }
    }



  // Function: print_string
  //
  // Prints a string field.

  public void print_real(T)(string  name,
			    T       value,
			    char    scope_separator = '.')
    if(isFloatingPoint!T) {
      synchronized(this) {
	// for format
	import std.string: format;

	uvm_printer_row_info row_info;

	if (name != "" && name != "...") {
	  _m_scope.set_arg(name);
	  name = _m_scope.get();
	}

	row_info.level = _m_scope.depth();
	row_info.name = adjust_name(_m_scope.get(), scope_separator);
	row_info.type_name = T.stringof;
	row_info.size = (T.sizeof*8).to!string();
	row_info.val = format("%f",value);

	_m_rows ~= row_info;

      }
    }

  // Function: print_generic
  //
  // Prints a field having the given ~name~, ~type_name~, ~size~, and ~value~.

  public void print_generic (string  name,
			     string  type_name,
			     size_t  size,
			     string  value,
			     char    scope_separator='.') {
    synchronized(this) {
      // format
      import std.string: format;

      uvm_printer_row_info row_info;

      if (name != "" && name != "...") {
	_m_scope.set_arg(name);
	name = _m_scope.get();
      }

      row_info.level = _m_scope.depth();
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
  public string emit();		// abstract
  //  {
  //   uvm_error("NO_OVERRIDE","emit() method not overridden in printer subtype");
  //   return "";
  // }


  // Function: format_row
  //
  // Hook for producing custom output of a single field (row).
  //
  public string format_row (uvm_printer_row_info row) {
    return "";
  }


  // Function: format_row
  //
  // Hook to override base header with a custom header.
  public string format_header() {
    return "";
  }


  // Function: format_header
  //
  // Hook to override base footer with a custom footer.
  public string format_footer() {
    return "";
  }


  // Function: adjust_name
  //
  // Prints a field's name, or ~id~, which is the full instance name.
  //
  // The intent of the separator is to mark where the leaf name starts if the
  // printer if configured to print only the leaf name of the identifier.

  protected string adjust_name (string id,
				char scope_separator='.') {
    synchronized(this) {
      if(_knobs.show_root && _m_scope.depth() is 0 ||
	 _knobs.full_name || id == "...") {
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

  public void print_array_header(string name,
				 size_t size,
				 string arraytype="array",
				 char   scope_separator='.') {
    synchronized(this) {
      import std.string: format;

      uvm_printer_row_info row_info;

      if(name != "") _m_scope.set_arg(name);

      row_info.level = _m_scope.depth();
      row_info.name = adjust_name(_m_scope.get(), scope_separator);
      row_info.type_name = arraytype;
      row_info.size = format("%0d", size);
      row_info.val = "-";

      _m_rows ~= row_info;

      _m_scope.down(name);
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

  public void print_array_range (int min, int max) {
    // string tmpstr; // redundant -- declared in the SV version
    if(min is -1 && max is -1) return;
    if(min is -1) min = max;
    if(max is -1) max = min;
    if(max < min) return;
    print_generic("...", "...", -2, "...");
  }


  // Function: print_array_footer
  //
  // Prints the header of a footer. This function marks the end of an array
  // print. Generally, there is no output associated with the array footer, but
  // this method lets the printer know that the array printing is complete.

  public void print_array_footer (size_t size=0) {
    synchronized(this) {
      if(_m_array_stack.length) {
	_m_scope.up();
	_m_array_stack = _m_array_stack[1..$];
      }
    }
  }


  // Utility methods
  final public bool istop () {
    synchronized(this) {
      return (_m_scope.depth() is 0);
    }
  }

  static public string index_string (int index, string name="") {
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

class uvm_table_printer: /* extends */ uvm_printer {

  // Variable: new
  //
  // Creates a new instance of ~uvm_table_printer~.
  //
  public this () {
    super();
  }

  // Function: emit
  //
  // Formats the collected information from prior calls to ~print_*~
  // into table format.
  //
  override final public string emit() {
    synchronized(this) {
      import uvm.base.uvm_root;

      char[] s;
      string user_format;
      shared static char[][uvm_object] dash; // = "---------------------------------------------------------------------------------------------------";
      shared static char[][uvm_object] space; // = "                                                                                                   ";
      char[] dashes;

      string linefeed = "\n" ~ _knobs.prefix;

      calculate_max_widths();

      import std.algorithm: max;
      size_t m = max(_m_max_name, _m_max_type, _m_max_size, _m_max_value, 100);

      uvm_root top = uvm_top;

      if(top !in dash) dash[top] = [];
      if(top !in space) space[top] = [];

      if(dash[top].length < m) {
	dash[top].length = m;
	dash[top][] = '-';
	space[top].length = m;
	space[top][] = ' ';
      }

      if (_knobs.header) {
	char[] header;
	user_format = format_header();
	if (user_format == "") {
	  string dash_id, dash_typ, dash_sz;
	  string head_id, head_typ, head_sz;
	  if (_knobs.identifier) {
	    // cast away shared
	    dashes = cast(char[])dash[top][0.._m_max_name+2];
	    header = "Name" ~ space[top][0.._m_max_name-2];
	  }
	  if (_knobs.type_name) {
	    dashes = dashes ~ dash[top][0.._m_max_name+2];
	    header = header ~ "Type" ~ space[top][0.._m_max_name-2];
	  }
	  if (_knobs.size) {
	    dashes = dashes ~ dash[top][0.._m_max_name+2];
	    header = header ~ "Size" ~ space[top][0.._m_max_name-2];
	  }
	  dashes = dashes ~ dash[top][0.._m_max_name] ~ linefeed;
	  header = header ~ "Value" ~ space[top][0.._m_max_value-5] ~ linefeed;

	  s ~= dashes ~ header ~ dashes;
	}
	else {
	  s ~= user_format ~ linefeed;
	}
      }

      foreach (row; _m_rows) {
	// uvm_printer_row_info row = _m_rows[i];
	user_format = format_row(row);
	if (user_format == "") {
	  char[] row_str;
	  if (_knobs.identifier) {
	    row_str = space[top][0..row.level*_knobs.indent] ~ row.name ~
	      space[top][0.._m_max_name-row.name.length-(row.level*_knobs.indent)+2];
	  }
	  if (_knobs.type_name) {
	    row_str = row_str ~ row.type_name ~
	      space[top][0.._m_max_type-row.type_name.length+2];
	  }
	  if (_knobs.size) {
	    row_str = row_str ~ row.size ~
	      space[top][0.._m_max_size-row.size.length+2];
	  }
	  s ~= row_str ~ row.val ~ space[top][0.._m_max_value-row.val.length]
	    ~ linefeed;
	}
	else {
	  s ~= user_format ~ linefeed;
	}
      }

      if (_knobs.footer) {
	user_format = format_footer();
	if (user_format == "") s ~= dashes;
	else s ~= user_format ~ linefeed;
      }

      // _m_rows.delete();
      _m_rows.length = 0;
      return cast(string)s;
    }
  }

  // Variables- m_max_*
  //
  // holds max size of each column, so table columns can be resized dynamically

  private size_t _m_max_name;
  private size_t _m_max_type;
  private size_t _m_max_size;
  private size_t _m_max_value;

  final public void calculate_max_widths() {
    synchronized(this) {
      _m_max_name=4;
      _m_max_type=4;
      _m_max_size = 4;
      _m_max_value= 5;
      foreach(row; _m_rows) {
	// uvm_printer_row_info row = _m_rows[j];
	auto name_len = _knobs.indent*row.level + row.name.length;
	if (name_len > _m_max_name) _m_max_name =  name_len;
	if (row.type_name.length > _m_max_type) _m_max_type = row.type_name.length;
	if (row.size.length > _m_max_size) _m_max_size = row.size.length;
	if (row.val.length > _m_max_value) _m_max_value = row.val.length;
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

  public this() {
    synchronized(this) {
      super();
      _knobs.size = 0;
      _knobs.type_name = 0;
      _knobs.header = 0;
      _knobs.footer = 0;
    }
  }

  // Function: emit
  //
  // Formats the collected information from prior calls to ~print_*~
  // into hierarchical tree format.
  //
  override final public string emit() {
    synchronized(this) {
      import std.string: format;

      string s = _knobs.prefix;
      string space= "                                                                                                   ";
      string user_format;

      string linefeed = _newline == "" || _newline == " " ?
	_newline : _newline ~ _knobs.prefix;

      // Header
      if (_knobs.header) {
	user_format = format_header();
	if (user_format != "") s ~= user_format ~ linefeed;
      }

      foreach (i, row; _m_rows) {
	user_format = format_row(row);
	if (user_format == "") {
	  auto indent_str = space[0..row.level * _knobs.indent];

	  // Name (id)
	  if (_knobs.identifier) {
	    s ~= indent_str ~ row.name;
	    if (row.name != "" && row.name != "...") s ~= ": ";
	  }

	  // Type Name
	  if (row.val[0] is '@') { // is an object w/ knobs.reference on
	    s ~= "(" ~ row.type_name ~ row.val ~ ") ";
	  }
	  else {
	    if (_knobs.type_name &&
		(row.type_name != "" ||
		 row.type_name != "-" ||
		 row.type_name != "...")) {
	      s ~= "(" ~ row.type_name ~ ") ";
	    }
	  }

	  // Size
	  if (_knobs.size) {
	    if (row.size != "" || row.size != "-") {
	      s ~= "(" ~ row.size ~ ") ";
	    }
	  }

	  if (i < _m_rows.length-1) {
	    if (_m_rows[i+1].level > row.level) {
	      s ~= _knobs.separator[0] ~ linefeed;
	      continue;
	    }
	  }

	  // Value (unconditional)
	  s ~= row.val ~ " " ~ linefeed;

	  // Scope handling...
	  if (i <= _m_rows.length-1) {
	    size_t end_level;
	    if (i is _m_rows.length-1) end_level = 0;
	    else                      end_level = _m_rows[i+1].level;
	    if (end_level < row.level) {
	      for (size_t l=row.level-1; l >= end_level; --l) {
		auto str = space[0..l * _knobs.indent];
		s ~= str ~ _knobs.separator[1] ~ linefeed;
	      }
	    }
	  }

	}
	else s ~= user_format;
      }

      // Footer
      if (_knobs.footer) {
	user_format = format_footer();
	if (user_format != "") s ~= user_format ~ linefeed;
      }

      if (_newline == "" || _newline == " ") s ~= "\n";

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

  public this() {
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

  mixin(uvm_sync!uvm_printer_knobs);

  @uvm_public_sync private bool _header = true;


  // Variable: footer
  //
  // Indicates whether the <print_footer> function should be called when
  // printing an object.

  @uvm_public_sync private bool _footer = true;


  // Variable: full_name
  //
  // Indicates whether <adjust_name> should print the full name of an identifier
  // or just the leaf name.

  @uvm_public_sync private bool _full_name = false;


  // Variable: identifier
  //
  // Indicates whether <adjust_name> should print the identifier. This is useful
  // in cases where you just want the values of an object, but no identifiers.

  @uvm_public_sync private bool _identifier = true;


  // Variable: type_name
  //
  // Controls whether to print a field's type name.

  @uvm_public_sync private bool _type_name = true;


  // Variable: size
  //
  // Controls whether to print a field's size.

  @uvm_public_sync private bool _size = true;


  // Variable: depth
  //
  // Indicates how deep to recurse when printing objects.
  // A depth of -1 means to print everything.

  @uvm_public_sync private int _depth = -1;


  // Variable: reference
  //
  // Controls whether to print a unique reference ID for object handles.
  // The behavior of this knob is simulator-dependent.

  @uvm_public_sync private bool _reference = true;


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

  @uvm_public_sync private string _prefix = "";


  // Variable: indent
  //
  // This knob specifies the number of spaces to use for level indentation.
  // The default level indentation is two spaces.

  @uvm_public_sync private int _indent = 2;


  // Variable: show_root
  //
  // This setting indicates whether or not the initial object that is printed
  // (when current depth is 0) prints the full path name. By default, the first
  // object is treated like all other objects and only the leaf name is printed.

  @uvm_public_sync private bool _show_root = false;


  // Variable: mcd
  //
  // This is a file descriptor, or multi-channel descriptor, that specifies
  // where the print output should be directed.
  //
  // By default, the output goes to the standard output of the simulator.

  @uvm_public_sync private MCD _mcd = UVM_STDOUT;


  // Variable: separator
  //
  // For tree printers only, determines the opening and closing
  // separators used for nested objects.

  @uvm_public_sync private string _separator = "{}";


  // Variable: show_radix
  //
  // Indicates whether the radix string ('h, and so on) should be prepended to
  // an integral value when one is printed.

  private bool _show_radix = true;


  // Variable: default_radix
  //
  // This knob sets the default radix to use for integral values when no radix
  // enum is explicitly supplied to the print_int() method.

  @uvm_public_sync private uvm_radix_enum _default_radix = UVM_HEX;


  // Variable: dec_radix
  //
  // This string should be prepended to the value of an integral type when a
  // radix of <UVM_DEC> is used for the radix of the integral object.
  //
  // When a negative number is printed, the radix is not printed since only
  // signed decimal values can print as negative.

  private string _dec_radix = "'d";


  // Variable: bin_radix
  //
  // This string should be prepended to the value of an integral type when a
  // radix of <UVM_BIN> is used for the radix of the integral object.

  private string _bin_radix = "'b";


  // Variable: oct_radix
  //
  // This string should be prepended to the value of an integral type when a
  // radix of <UVM_OCT> is used for the radix of the integral object.

  private string _oct_radix = "'o";


  // Variable: unsigned_radix
  //
  // This is the string which should be prepended to the value of an integral
  // type when a radix of <UVM_UNSIGNED> is used for the radix of the integral
  // object.

  private string _unsigned_radix = "'d";


  // Variable: hex_radix
  //
  // This string should be prepended to the value of an integral type when a
  // radix of <UVM_HEX> is used for the radix of the integral object.

  private string _hex_radix = "'h";


  // Function: get_radix_str
  //
  // Converts the radix from an enumerated to a printable radix according to
  // the radix printing knobs (bin_radix, and so on).

  public string get_radix_str(uvm_radix_enum radix) {
    synchronized(this) {
      if(_show_radix is false) return "";
      if(radix is UVM_NORADIX) radix = _default_radix;
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
