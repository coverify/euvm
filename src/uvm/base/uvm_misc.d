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

module uvm.base.uvm_misc;

//------------------------------------------------------------------------------
//
// Topic: uvm_void
//
// The ~uvm_void~ class is the base class for all UVM classes. It is an abstract
// class with no data members or functions. It allows for generic containers of
// objects to be created, similar to a void pointer in the C programming
// language. User classes derived directly from ~uvm_void~ inherit none of the
// UVM functionality, but such classes may be placed in ~uvm_void~-typed
// containers along with other UVM objects.
//
//------------------------------------------------------------------------------
import std.array;
import std.string: format;
import esdl.data.bvec;
// import uvm.base.uvm_object_globals;

interface uvm_void_if { }
abstract class uvm_void: uvm_void_if { }



import uvm.meta.misc;

// Append/prepend symbolic values for order-dependent APIs
enum uvm_apprepend: bool
  {   UVM_APPEND = false,
      UVM_PREPEND = true
      }

mixin(declareEnums!uvm_apprepend());


// Forward declaration since scope stack uses uvm_objects now
// typedef class uvm_object;

//----------------------------------------------------------------------------
//
// CLASS- uvm_scope_stack
//
//----------------------------------------------------------------------------

final class uvm_scope_stack
{
  private string _m_arg;
  // UVM for SV uses a queue for m_stack, but a dynamic array is good
  // enough since we do not need push_front for this collection
  private string[] _m_stack;

  // depth
  // -----

  public size_t depth() {
    synchronized(this) {
      return _m_stack.length;
    }
  }

  // scope
  // -----

  public string get() {
    synchronized(this) {
      string v;
      if(_m_stack.length is 0) return _m_arg;
      string res = _m_stack[0];
      for(size_t i=1; i<_m_stack.length; ++i) {
	v = _m_stack[i];
	if(v != "" && (v[0] is '[' || v[0] is '(' || v[0] is '{'))
	  res ~= v;
	else
	  res ~= "." ~ v;
      }
      if(_m_arg != "") {
	if(res != "")
	  res ~= "." ~ _m_arg;
	else
	  res = _m_arg;
      }
      return res;
    }
  }

  // scope_arg
  // ---------

  public string get_arg() {
    synchronized(this) {
      return _m_arg;
    }
  }


  // set_scope
  // ---------

  public void set (string s) {
    synchronized(this) {
      _m_stack.length = 0;

      _m_stack ~= s;
      _m_arg = "";
    }
  }

  // down
  // ----

  public void down (string s) {
    synchronized(this) {
      _m_stack ~= s;
      _m_arg = "";
    }
  }

  // down_element
  // ------------

  public void down_element (int element) {
    synchronized(this) {
      _m_stack ~= format("[%0d]", element);
      _m_arg = "";
    }
  }


  // up_element
  // ------------

  public void up_element () {
    synchronized(this) {
      if(_m_stack.length is 0) {
	return;
      }
      string s = _m_stack[$-1];
      if(s == "" || s[0] is '[') {
	_m_stack = _m_stack[0..$-1];
      }
    }
  }

  // up
  // --

  public void up (char separator = '.') {
    synchronized(this) {
      bool found = false;
      while(_m_stack.length && !found ) {
	string s = _m_stack[$-1];
	_m_stack = _m_stack[0..$-1];
	if(separator is '.') {
	  if (s == "" || (s[0] !is '[' && s[0] !is '(' && s[0] !is '{')) {
	    found = true;
	  }
	}
	else {
	  if(s != "" && s[0] is separator) {
	    found = true;
	  }
	}
      }
      _m_arg = "";
    }
  }


  // set_arg
  // -------

  public void set_arg (string arg) {
    synchronized(this) {
      if(arg == "") {
	return;
      }
      _m_arg = arg;
    }
  }


  // set_arg_element
  // ---------------

  public void set_arg_element (string arg, int ele) {
    synchronized(this) {
      import std.conv;
      _m_arg = arg ~ "[" ~ ele.to!string ~ "]";
    }
  }

  // unset_arg
  // ---------

  public void unset_arg (string arg) {
    synchronized(this) {
      if(arg == _m_arg) {
	_m_arg = "";
      }
    }
  }
} // endclass



//------------------------------------------------------------------------------
//
// CLASS- uvm_status_container
//
// Internal class to contain status information for automation methods.
//
//------------------------------------------------------------------------------

import uvm.base.uvm_packer;
import uvm.base.uvm_comparer;
import uvm.base.uvm_recorder;
import uvm.base.uvm_printer;

final class uvm_status_container {
  import uvm.base.uvm_object;

  mixin(uvm_sync!uvm_status_container);

  //The clone setting is used by the set/get config to know if cloning is on.
  @uvm_public_sync private bool _clone = true;

  //Information variables used by the macro functions for storage.
  @uvm_public_sync private bool             _warning;
  @uvm_public_sync private bool             _status;
  @uvm_public_sync private uvm_bitstream_t  _bitstream;

  // FIXME -- next two elements present in SV version but are not used
  // private int              _intv;
  // private int              _element;

  @uvm_public_sync private string _stringv;

  // FIXME -- next three elements present in SV version but are not used
  // private string           _scratch1;
  // private string           _scratch2;
  // private string           _key;

  @uvm_public_sync private uvm_object _object;

  // FIXME -- next element present in SV version but is not used
  // private bool             _array_warning_done;

  // Since only one static instance is created for this class
  // (uvm_status_container), it is Ok to not make the next two
  // elements static (as done in SV version)
  // __gshared 
  private bool _field_array[string];

  public bool field_exists(string field) {
    synchronized(this) {
      if(field in _field_array) return true;
      else return false;
    }
  }

  public void reset_fields() {
    synchronized(this) {
      _field_array = null;
    }
  }

  public bool no_fields() {
    synchronized(this) {
      if(_field_array.length is 0) return true;
      else return false;
    }
  }

  // __gshared 
  // FIXME -- next element present in SV version but is not used
  // private bool             _print_matches;

  public void do_field_check(string field, uvm_object obj) {
    synchronized(this) {
      debug(UVM_ENABLE_FIELD_CHECKS) {
	if (field in _field_array)
	  uvm_report_error("MLTFLD",
			   format("Field %s is defined multiple times in type '%s'",
				  field, obj.get_type_name()), UVM_NONE);
      }
      _field_array[field] = true;
    }
  }


  public static string get_function_type (int what) {
    switch (what) {
    case UVM_COPY:    return "copy";
    case UVM_COMPARE: return "compare";
    case UVM_PRINT:   return "print";
    case UVM_RECORD:  return "record";
    case UVM_PACK:    return "pack";
    case UVM_UNPACK:  return "unpack";
    case UVM_FLAGS:   return "get_flags";
    case UVM_SETINT:  return "set";
    case UVM_SETOBJ:  return "set_object";
    case UVM_SETSTR:  return "set_string";
    default:          return "unknown";
    }
  }

  // The scope stack is used for messages that are emitted by policy classes.
  @uvm_immutable_sync private uvm_scope_stack _scope_stack; // = new uvm_scope_stack();

  public this() {
    synchronized(this) {
      _scope_stack = new uvm_scope_stack();
    }
  }

  public string get_full_scope_arg () {
    synchronized(this) {
      return scope_stack.get();
    }
  }

  //Used for checking cycles. When a data function is entered, if the depth is
  //non-zero, then then the existeance of the object in the map means that a
  //cycle has occured and the function should immediately exit. When the
  //function exits, it should reset the cycle map so that there is no memory
  //leak.
  private bool _cycle_check[uvm_object];

  public bool check_cycle(uvm_object obj) {
    synchronized(this) {
      if(obj in _cycle_check) return true;
      else return false;
    }
  }

  public bool add_cycle(uvm_object obj) {
    synchronized(this) {
      if(obj in _cycle_check) return false;
      else _cycle_check[obj] = true;
      return true;
    }
  }

  public bool remove_cycle(uvm_object obj) {
    synchronized(this) {
      if(obj !in _cycle_check) return false;
      else _cycle_check.remove(obj);
      return true;
    }
  }

  public void remove_all_cycles() {
    synchronized(this) {
      _cycle_check = null;
    }
  }

  //These are the policy objects currently in use. The policy object gets set
  //when a function starts up. The macros use this.
  @uvm_public_sync private uvm_comparer _comparer;
  @uvm_public_sync private uvm_packer   _packer;
  @uvm_public_sync private uvm_recorder _recorder;
  @uvm_public_sync private uvm_printer  _printer;

  // utility function used to perform a cycle check when config setting are pushed
  // to uvm_objects. the function has to look at the current object stack representing
  // the call stack of all m_uvm_field_automation() invocations.
  // it is a only a cycle if the previous m_uvm_field_automation call scope
  // is not identical with the current scope AND the scope is already present in the
  // object stack
  private uvm_object[] _m_uvm_cycle_scopes;

  public void reset_cycle_scopes() {
    synchronized(this) {
      _m_uvm_cycle_scopes.length = 0;
    }
  }

  public bool m_do_cycle_check(uvm_object scope_stack) {
    synchronized(this) {
      uvm_object l = _m_uvm_cycle_scopes[$-1];

      // we have been in this scope before (but actually right before so assuming a super/derived context of the same object)
      if(l is scope_stack) {
	_m_uvm_cycle_scopes ~= scope_stack;
	return false;
      }
      else {
	// now check if we have already been in this scope before
	import std.algorithm;
	auto m = find(_m_uvm_cycle_scopes, scope_stack);
	// uvm_object m[] = m_uvm_cycle_scopes.find_first(item) with (item is scope_stack);
	if(m.length !is 0) {
	  return true;   //   detected a cycle
	}
	else {
	  _m_uvm_cycle_scopes ~= scope_stack;
	  return false;
	}
      }
    }
  }
} // endclass

//------------------------------------------------------------------------------
//
// CLASS- uvm_copy_map
//
//
// Internal class used to map rhs to lhs so when a cycle is found in the rhs,
// the correct lhs object can be bound to it.
//------------------------------------------------------------------------------

final class uvm_copy_map {
  import uvm.base.uvm_object;
  private uvm_object _m_map[uvm_object];
  public void set(uvm_object key, uvm_object obj) {
    synchronized(this) {
      _m_map[key] = obj;
    }
  }
  public uvm_object get(uvm_object key) {
    synchronized(this) {
      if (key in _m_map) {
	return _m_map[key];
      }
      return null;
    }
  }
  public void clear() {
    synchronized(this) {
      _m_map = null;		// _m_map.delete() in SV
    }
  }
  public void remove(uvm_object v) { // delete in D is a keyword
    synchronized(this) {
      _m_map.remove(v);
    }
  }
}


final class uvm_once_seed_map
{
  // ** from uvm_misc
  // Variable- m_global_random_seed
  //
  // Create a seed which is based off of the global seed which can be used to seed
  // srandom processes but will change if the command line seed setting is
  // changed.
  //
  @uvm_immutable_sync
  private uint _m_global_random_seed;

  // ** from uvm_misc -- global variable in SV
  private uvm_seed_map[string] _uvm_random_seed_table_lookup;


  this(uint seed) {
    synchronized(this) {
      _m_global_random_seed = seed;
    }
  }
}

// Class- uvm_seed_map
//
// This map is a seed map that can be used to update seeds. The update
// is done automatically by the seed hashing routine. The seed_table_lookup
// uses an instance name lookup and the seed_table inside a given map
// uses a type name for the lookup.
//
final class uvm_seed_map {
  mixin(uvm_once_sync!(uvm_once_seed_map));

  private uint _seed_table[string];
  private uint _count[string];

  static private uint map_random_seed ( string type_id, string inst_id="" ) {
    uvm_seed_map seed_map;

    if (inst_id == "") inst_id = "__global__";

    type_id = "uvm_pkg." ~ type_id; // uvm_instance_scope()

    synchronized(_once) {
      if (inst_id !in _uvm_random_seed_table_lookup) {
	_uvm_random_seed_table_lookup[inst_id] = new uvm_seed_map();
      }
      seed_map = _uvm_random_seed_table_lookup[inst_id];
    }

    return seed_map.create_random_seed(type_id, inst_id);
  }

  // Function- uvm_create_random_seed
  //
  // Creates a random seed and updates the seed map so that if the same string
  // is used again, a new value will be generated. The inst_id is used to hash
  // by instance name and get a map of type name hashes which the type_id uses
  // for it's lookup.

  private uint create_random_seed ( string type_id, string inst_id="" ) {
    synchronized(this) {
      if (type_id !in _seed_table) {
	_seed_table[type_id] = oneway_hash (type_id ~ "." ~ inst_id,
					    m_global_random_seed);
      }
      if (type_id !in _count) {
	_count[type_id] = 0;
      }

      //can't just increment, otherwise too much chance for collision, so
      //randomize the seed using the last seed as the seed value. Check if
      //the seed has been used before and if so increment it.
      _seed_table[type_id] = _seed_table[type_id] +
	_count[type_id];
      _count[type_id]++;

      return _seed_table[type_id];
    }
  }

  // Function- oneway_hash
  //
  // A one-way hash function that is useful for creating srandom seeds. An
  // unsigned int value is generated from the string input. An initial seed can
  // be used to seed the hash, if not supplied the m_global_random_seed
  // value is used. Uses a CRC like functionality to minimize collisions.
  //

  // TBD -- replace all this junk with std.hash implementation once it
  // gets into DMD

  static private uint oneway_hash (string string_in, uint seed ) {
    enum int UVM_STR_CRC_POLYNOMIAL = 0x04c11db6;
    bool          msb;
    ubyte         current_byte;
    uint          crc1 = 0xffffffff;

    uint res = seed;

    for (int _byte=0; _byte < string_in.length; _byte++) {
      current_byte = cast(ubyte) string_in[_byte];
      // I do not think that the next line makes any sense (in SV either)
      // but the SV code has it
      if (current_byte is 0) break;
      for (int _bit=0; _bit < 8; _bit++) {
	msb = cast(bool) (crc1 >>> 31);
	crc1 <<= 1;
	if (msb ^ ((current_byte >> _bit) & 1)) {
	  crc1 ^=  UVM_STR_CRC_POLYNOMIAL;
	  crc1 |= 1;
	}
      }
    }
    uint byte_swapped_crc1 = 0;
    for (int i = 0; i !is 4; ++i) {
      byte_swapped_crc1 <<= 8;
      byte_swapped_crc1 += (crc1 >> i*8) & 0x000000ff;
    }

    // res += ~{crc1[7:0], crc1[15:8], crc1[23:16], crc1[31:24]};
    res += ~byte_swapped_crc1;
    return res;
  }

}

public uint uvm_create_random_seed (string type_id, string inst_id="") {
  return uvm_seed_map.map_random_seed(type_id, inst_id);
}

public uint uvm_global_random_seed() {
  return uvm_seed_map.m_global_random_seed;
}

// //------------------------------------------------------------------------------
// // Internal utility functions
// //------------------------------------------------------------------------------

// // Function- uvm_instance_scope
// //
// // A function that returns the scope that the UVM library lives in, either
// // an instance, a module, or a package.
// //
// function string uvm_instance_scope();
//   byte c;
//   int pos;
//   //first time through the scope is null and we need to calculate, afterwards it
//   //is correctly set.

//   if(uvm_instance_scope != "")
//     return uvm_instance_scope;

//   $swrite(uvm_instance_scope, "%m");
//   //remove the extraneous .uvm_instance_scope piece or ::uvm_instance_scope
//   pos = uvm_instance_scope.len()-1;
//   c = uvm_instance_scope[pos];
//   while(pos && (c != ".") && (c != ":"))
//     c = uvm_instance_scope[--pos];
//   if(pos is 0)
//     uvm_report_error("SCPSTR", $sformatf("Illegal name %s in scope_stack string",uvm_instance_scope));
//   uvm_instance_scope = uvm_instance_scope.substr(0,pos);
// endfunction


// Function- uvm_object_value_str
//
//
import uvm.base.uvm_object: uvm_object;
public string uvm_object_value_str(uvm_object v) {
  import std.conv;
  if (v is null) {
    return "<null>";
  }
  return "@" ~ (v.get_inst_id()).to!string();
}

// Function- uvm_leaf_scope
//
//
public string uvm_leaf_scope (string full_name, char scope_separator = '.') {
  char bracket_match;
  size_t  pos;
  int  bmatches = 0;

  switch(scope_separator) {
  case '[': bracket_match = ']'; break;
  case '(': bracket_match = ')'; break;
  case '<': bracket_match = '>'; break;
  case '{': bracket_match = '}'; break;
  default : bracket_match = '.'; break;
  }

  //Only use bracket matching if the input string has the end match
  if(bracket_match !is '.' && bracket_match !is full_name[$-1])
    bracket_match = '.';

  for(pos=full_name.length-1; pos !is 0; --pos) {
    if(full_name[pos] is bracket_match) ++bmatches;
    else if(full_name[pos] is scope_separator) {
      --bmatches;
      if(!bmatches || (bracket_match is '.')) break;
    }
  }
  if(pos) {
    if(scope_separator !is '.') --pos;
    return full_name[pos+1..$];
  }
  else {
    return full_name;
  }
}

// Function- uvm_vector_to_string
//
//
import std.traits: isIntegral;
import uvm.base.uvm_object_globals;

public string uvm_vector_to_string(T)(T value,
				      uvm_radix_enum radix=UVM_NORADIX,
				      string radix_str="")
  if(isBitVector!T || isIntegral!T || is(T == bool)) {
    static if(isIntegral!T)       vec!T val = value;
    else static if(is(T == bool)) Bit!1 val = value;
      else                        alias value val;

    // sign extend & don't show radix for negative values
    if (radix is UVM_DEC && (cast(Bit!1) val[$-1]) is 1)
      return format("%0d", val);

    switch(radix) {
    case UVM_BIN:      return format("%0s%0b", radix_str, val);
    case UVM_OCT:      return format("%0s%0o", radix_str, val);
    case UVM_UNSIGNED: return format("%0s%0d", radix_str, val);
    case UVM_STRING:   return format("%0s%0s", radix_str, val);
      // SV UVM uses %0t for time
    case UVM_TIME:     return format("%0s%0d", radix_str, val);
    case UVM_DEC:      return format("%0s%0d", radix_str, val);
    default:           return format("%0s%0x", radix_str, val);
    }
  }


// Function- uvm_get_array_index_int
//
// The following functions check to see if a string is representing an array
// index, and if so, what the index is.

public int uvm_get_array_index_int(string arg, out bool is_wildcard) {
  import std.conv;
  int retval = 0;
  is_wildcard = true;
  auto i = arg.length - 1;
  if(arg[i] is ']') {
    while(i > 0 && (arg[i] !is '[')) {
      --i;
      if((arg[i] is '*') || (arg[i] is '?')) {
	i=0;
      }
      else if((arg[i] < '0') || (arg[i] > '9') && (arg[i] !is '[')) {
	retval = -1; //illegal integral index
	i=0;
      }
    }
  }
  else {
    is_wildcard = false;
    return 0;
  }

  if(i>0) {
    arg = arg[i+1..$-1];
    retval = arg.to!int();
    is_wildcard = false;
  }
  return retval;
}

// Function- uvm_get_array_index_string
//
//
public string uvm_get_array_index_string(string arg, out bool is_wildcard) {
  string retval;
  is_wildcard = true;
  auto i = arg.length - 1;
  if(arg[i] is ']')
    while(i > 0 && (arg[i] !is '[')) {
      if((arg[i] is '*') || (arg[i] is '?')) {
	i=0;
      }
      --i;
    }
  if(i > 0) {
    retval = arg[i+1..$-1];
    is_wildcard = false;
  }
  return retval;
}


// Function- uvm_is_array
//
//
public bool uvm_is_array(string arg) {
  return arg[$-1] is ']';
}


// Function- uvm_has_wildcard
//
//
public bool uvm_has_wildcard (string arg) {
  //if it is a regex then return true
  if( (arg.length > 1) && (arg[0] is '/') && (arg[$-1] is '/') ) {
    return true;
  }

  //check if it has globs
  foreach(c; arg) {
    if( (c is '*') || (c is '+') || (c is '?') ) {
      return true;
    }
  }
  return false;
}

//------------------------------------------------------------------------------
// CLASS: uvm_utils
//
// This class contains useful template functions.
//
//------------------------------------------------------------------------------

import uvm.base.uvm_component;
// typedef class uvm_component;
// typedef class uvm_root;
// typedef class uvm_object;

// SV puts default TYPE as int, but then returning null for TYPE
// object (see function find) does not make any sense
final class uvm_utils (TYPE=uvm_void, string FIELD="config") {
  // typedef TYPE types_t[$];
  alias TYPE[] types_t;
  // Function: find_all
  //
  // Recursively finds all component instances of the parameter type ~TYPE~,
  // starting with the component given by ~start~. Uses <uvm_root::find_all>.

  static public types_t find_all(uvm_component start) {
    uvm_component list[];
    types_t types;
    uvm_root top = uvm_root.get();
    top.find_all("*", list, start);
    foreach (comp; list) {
      TYPE typ;
      if (cast(typ) comp) {
	types ~= typ;
      }
    }
    if (types.length is 0) {
      uvm_warning("find_type-no match", "Instance of type '" ~
		  TYPE.type_name ~
		  " not found in component hierarchy beginning at " ~
		  start.get_full_name());
    }
    return types;
  }

  static public TYPE find(uvm_component start) {
    types_t types = find_all(start);
    if (types.length is 0) {
      return null;
    }
    if (types.length > 1) {
      uvm_warning("find_type-multi match",
		  "More than one instance of type '" ~
		  TYPE.type_name ~
		  " found in component hierarchy beginning at " ~
		  start.get_full_name());
      return null;
    }
    return types[0];
  }

  static public TYPE create_type_by_name(string type_name, string contxt) {
    uvm_object obj;
    TYPE  typ;
    obj = factory.create_object_by_name(type_name,contxt,type_name);
    if (cast(typ) obj)
      uvm_report_error("WRONG_TYPE",
		       "The type_name given '" ~
		       type_name ~ "' with context '" ~ contxt ~
		       "' did not produce the expected type.");
    return typ;
  }

  // Function: get_config
  //
  // This method gets the object config of type ~TYPE~
  // associated with component ~comp~.
  // We check for the two kinds of error which may occur with this kind of
  // operation.

  static public TYPE get_config(uvm_component comp, bool is_fatal) {
    uvm_object obj;
    TYPE cfg;

    if (!comp.get_config_object(FIELD, obj, 0)) {
      if (is_fatal) {
	comp.uvm_report_fatal("NO_SET_CFG",
			      "no set_config to field '" ~ FIELD ~
			      "' for component '" ~
			      comp.get_full_name() ~ "'",
			      UVM_MEDIUM, uvm_file , uvm_line  );
      }
      else {
	comp.uvm_report_warning("NO_SET_CFG",
				"no set_config to field '" ~ FIELD ~
				"' for component '" ~
				comp.get_full_name() ~ "'",
				UVM_MEDIUM, uvm_file , uvm_line  );
      }
      return null;
    }

    if (! cast(cfg) obj) {
      if (is_fatal) {
	comp.uvm_report_fatal( "GET_CFG_TYPE_FAIL",
			       "set_config_object with field name " ~
			       FIELD ~ " is not of type '" ~
			       TYPE.type_name ~ "'",
			       UVM_NONE , uvm_file , uvm_line );
      }
      else {
	comp.uvm_report_warning( "GET_CFG_TYPE_FAIL",
				 "set_config_object with field name " ~
				 FIELD ~ " is not of type '" ~
				 TYPE.type_name ~ "'",
				 UVM_NONE , uvm_file , uvm_line );
      }
    }
    return cfg;
  }
}

version(UVM_USE_PROCESS_CONTAINER) {
  import esdl.base.core;
  final class process_container_c
  {
    mixin(uvm_sync!process_container_c);

    @uvm_immutable_sync private Process _p;

    this(Process p) {
      synchronized(this) {
	_p = p;
      }
    }
  }
}
