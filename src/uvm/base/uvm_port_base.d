//
//------------------------------------------------------------------------------
//   Copyright 2007-2011 Mentor Graphics Corporation
//   Copyright 2007-2011 Cadence Design Systems, Inc.
//   Copyright 2010 Synopsys, Inc.
//   Copyright 2014 Coverify Systems Technology
//   All Rights Reserved Worldwide
//
//   Licensed under the Apache License, Version 2.0 (the "License"); you may not
//   use this file except in compliance with the License.  You may obtain a copy
//   of the License at
//
//       http://www.apache.org/licenses/LICENSE-2.0
//
//   Unless required by applicable law or agreed to in writing, software
//   distributed under the License is distributed on an "AS IS" BASIS, WITHOUT
//   WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.  See the
//   License for the specific language governing permissions and limitations
//   under the License.
//------------------------------------------------------------------------------

module uvm.base.uvm_port_base;
import uvm.base.uvm_component;
import uvm.base.uvm_phase;
import uvm.base.uvm_object_globals;
import uvm.base.uvm_root;
import uvm.base.uvm_domain;

import uvm.meta.misc;
import std.string: format;
import std.conv: to;


enum int UVM_UNBOUNDED_CONNECTIONS = -1;
enum string s_connection_error_id = "Connection Error";
enum string s_connection_warning_id = "Connection Warning";
enum string s_spaces = "                       ";

// typedef class uvm_port_component_base;
// alias uvm_port_component_base uvm_port_list[string];
alias uvm_port_component_base[string] uvm_port_list;


// TITLE: Port Base Classes
//


//------------------------------------------------------------------------------
//
// CLASS: uvm_port_component_base
//
//------------------------------------------------------------------------------
// This class defines an interface for obtaining a port's connectivity lists
// after or during the end_of_elaboration phase.  The sub-class,
// <uvm_port_component #(PORT)>, implements this interface.
//
// The connectivity lists are returned in the form of handles to objects of this
// type. This allowing traversal of any port's fan-out and fan-in network
// through recursive calls to <get_connected_to> and <get_provided_to>. Each
// port's full name and type name can be retrieved using get_full_name and
// get_type_name methods inherited from <uvm_component>.
//------------------------------------------------------------------------------

abstract class uvm_port_component_base: uvm_component
{

  public this(string name="", uvm_component parent=null) {
    super(name,parent);
  }

  // Function: get_connected_to
  //
  // For a port or export type, this function fills ~list~ with all
  // of the ports, exports and implementations that this port is
  // connected to.

  abstract public void get_connected_to(out uvm_port_list list);
  abstract public uvm_port_list get_connected_to();

  // Function: get_provided_to
  //
  // For an implementation or export type, this function fills ~list~ with all
  // of the ports, exports and implementations that this port is
  // provides its implementation to.

  abstract public void get_provided_to(out uvm_port_list list);
  abstract public uvm_port_list get_provided_to();

  // Function: is_port
  //
  abstract public bool is_port();

  // Function: is_export
  //
  abstract public bool is_export();

  // Function: is_imp
  //
  // These function determine the type of port. The functions are
  // mutually exclusive; one will return 1 and the other two will
  // return 0.

  abstract public bool is_imp();

  // Turn off auto config by not calling build_phase()
  override public void build_phase(uvm_phase phase) {
    build(); //for backward compat
    return;
  }

  // task
  public void do_task_phase (uvm_phase phase) {
  }
}


//------------------------------------------------------------------------------
//
// CLASS: uvm_port_component #(PORT)
//
//------------------------------------------------------------------------------
// See description of <uvm_port_component_base> for information about this class
//------------------------------------------------------------------------------


class uvm_port_component (PORT=uvm_object): uvm_port_component_base
{
  mixin uvm_sync;

  // These needs further investigation
  // The component becomes accessible via the port -- FIXME
  override void _uvm__auto_build() {}

  @uvm_immutable_sync private PORT _m_port;

  public this(string name, uvm_component parent, PORT port) {
    synchronized(this) {
      super(name, parent);
      if(port is null) {
	uvm_report_fatal("Bad usage", "Null handle to port", UVM_NONE);
      }
      _m_port = port;
    }
  }

  override public string get_type_name() {
    if(m_port is null) return "uvm_port_component";
    return m_port.get_type_name();
  }

  override public void resolve_bindings() {
    m_port.resolve_bindings();
  }

  // Function: get_port
  //
  // Retrieve the actual port object that this proxy refers to.

  final public PORT get_port() {
    return m_port;
  }

  override public void get_connected_to(out uvm_port_list list) {
    m_port.get_connected_to(list);
  }

  override public uvm_port_list get_connected_to() {
    return m_port.get_connected_to();
  }

  override public void get_provided_to(out uvm_port_list list) {
    m_port.get_provided_to(list);
  }

  override public uvm_port_list get_provided_to() {
    return m_port.get_provided_to();
  }

  final override public bool is_port () {
    return m_port.is_port();
  }

  final override public bool is_export () {
    return m_port.is_export();
  }

  final override public bool is_imp () {
    return m_port.is_imp();
  }

};				// extra semicolon for emacs indent


//------------------------------------------------------------------------------
//
// CLASS: uvm_port_base #(IF)
//
//------------------------------------------------------------------------------
//
// Transaction-level communication between components is handled via its ports,
// exports, and imps, all of which derive from this class.
//
// The uvm_port_base extends IF, which is the type of the interface implemented
// by derived port, export, or implementation. IF is also a type parameter to
// uvm_port_base.
//
//   IF  - The interface type implemented by the subtype to this base port
//
// The UVM provides a complete set of ports, exports, and imps for the OSCI-
// standard TLM interfaces. They can be found in the ../src/tlm/ directory.
// For the TLM interfaces, the IF parameter is always <uvm_tlm_if_base #(T1,T2)>.
//
// Just before <uvm_component.end_of_elaboration>, an internal
// <uvm_component.resolve_bindings> process occurs, after which each port and
// export holds a list of all imps connected to it via hierarchical connections
// to other ports and exports. In effect, we are collapsing the port's fanout,
// which can span several levels up and down the component hierarchy, into a
// single array held local to the port. Once the list is determined, the port's
// min and max connection settings can be checked and enforced.
//
// uvm_port_base possesses the properties of components in that they have a
// hierarchical instance path and parent. Because SystemVerilog does not support
// multiple inheritance, uvm_port_base can not extend both the interface it
// implements and <uvm_component>. Thus, uvm_port_base contains a local instance
// of uvm_component, to which it delegates such commands as get_name,
// get_full_name, and get_parent.
//
//------------------------------------------------------------------------------

abstract class uvm_port_base(IF = uvm_void): IF
{

  mixin uvm_sync;

  alias uvm_port_base!IF this_type;

  // local, protected, and non-user properties

  @uvm_protected_sync
  private uint                                _m_if_mask;
  @uvm_protected_sync
  private this_type                           _m_if;    // REMOVE
  private size_t                              _m_def_index;
  @uvm_immutable_sync
  private uvm_port_component!this_type        _m_comp;
  private this_type[string]                     _m_provided_by;
  private this_type[string]                     _m_provided_to;
  private uvm_port_type_e                       _m_port_type;
  private int                                   _m_min_size;
  private int                                   _m_max_size;
  private bool                                  _m_resolved;
  private this_type[string]                     _m_imp_list;

  // Function: new
  //
  // The first two arguments are the normal <uvm_component> constructor
  // arguments.
  //
  // The ~port_type~ can be one of <UVM_PORT>, <UVM_EXPORT>, or
  // <UVM_IMPLEMENTATION>.
  //
  // The ~min_size~ and ~max_size~ specify the minimum and maximum number of
  // implementation (imp) ports that must be connected to this port base by the
  // end of elaboration. Setting ~max_size~ to ~UVM_UNBOUNDED_CONNECTIONS~ sets no
  // maximum, i.e., an unlimited number of connections are allowed.
  //
  // By default, the parent/child relationship of any port being connected to
  // this port is not checked. This can be overridden by configuring the
  // port's ~check_connection_relationships~ bit via <set_config_int>. See
  // <connect> for more information.

  public this(string name,
	      uvm_component parent,
	      uvm_port_type_e port_type,
	      int min_size = 0,
	      int max_size = 1
	      ) {
    synchronized(this) {
      // uvm_component comp;
      _m_port_type = port_type;
      _m_min_size  = min_size;
      _m_max_size  = max_size;
      _m_comp = new uvm_port_component!this_type(name, parent, this);

      int tmp;
      if (!_m_comp.get_config_int("check_connection_relationships", tmp)) {
	_m_comp.set_report_id_action(s_connection_warning_id, UVM_NO_ACTION);
      }
    }
  }


  // Function: get_name
  //
  // Returns the leaf name of this port.

  public string get_name() {
    return m_comp.get_name();
  }


  // Function: get_full_name
  //
  // Returns the full hierarchical name of this port.

  public string get_full_name() {
    return m_comp.get_full_name();
  }


  // Function: get_parent
  //
  // Returns the handle to this port's parent, or null if it has no parent.

  public uvm_component get_parent() {
    return m_comp.get_parent();
  }


  // Function: get_comp
  //
  // Returns a handle to the internal proxy component representing this port.
  //
  // Ports are considered components. However, they do not inherit
  // <uvm_component>. Instead, they contain an instance of
  // <uvm_port_component #(PORT)> that serves as a proxy to this port.

  public uvm_port_component_base get_comp() {
    return m_comp;
  }


  // Function: get_type_name
  //
  // Returns the type name to this port. Derived port classes must implement
  // this method to return the concrete type. Otherwise, only a generic
  // "uvm_port", "uvm_export" or "uvm_implementation" is returned.

  public string get_type_name() {
    synchronized(this) {
      switch(_m_port_type) {
      case UVM_PORT : return "port";
      case UVM_EXPORT : return "export";
      case UVM_IMPLEMENTATION : return "implementation";
      default:
	assert(false, "Invalid port type");
      }
    }
  }


  // Function: min_size
  //
  // Returns the mininum number of implementation ports that must
  // be connected to this port by the end_of_elaboration phase.

  final public int max_size() {
    synchronized(this) {
      return _m_max_size;
    }
  }


  // Function: max_size
  //
  // Returns the maximum number of implementation ports that must
  // be connected to this port by the end_of_elaboration phase.

  final public int min_size() {
    synchronized(this) {
      return _m_min_size;
    }
  }


  // Function: is_unbounded
  //
  // Returns 1 if this port has no maximum on the number of implementation
  // ports this port can connect to. A port is unbounded when the ~max_size~
  // argument in the constructor is specified as ~UVM_UNBOUNDED_CONNECTIONS~.

  final public bool is_unbounded() {
    synchronized(this) {
      return (_m_max_size is UVM_UNBOUNDED_CONNECTIONS);
    }
  }


  // Function: is_port

  final public bool is_port() {
    synchronized(this) {
      return _m_port_type is UVM_PORT;
    }
  }

  // Function: is_export

  final public bool is_export() {
    synchronized(this) {
      return _m_port_type is UVM_EXPORT;
    }
  }

  // Function: is_imp
  //
  // Returns 1 if this port is of the type given by the method name,
  // 0 otherwise.

  final public bool is_imp() {
    synchronized(this) {
      return _m_port_type is UVM_IMPLEMENTATION;
    }
  }


  // Function: size
  //
  // Gets the number of implementation ports connected to this port. The value
  // is not valid before the end_of_elaboration phase, as port connections have
  // not yet been resolved.

  final public size_t size () {
    synchronized(this) {
      return _m_imp_list.length;
    }
  }


  final public void set_if(size_t index=0) {
    synchronized(this) {
      _m_if = get_if(index);
      if (_m_if !is null) {
	_m_def_index = index;
      }
    }
  }

  final public int m_get_if_mask() {
    synchronized(this) {
      return _m_if_mask;
    }
  }


  // Function: set_default_index
  //
  // Sets the default implementation port to use when calling an interface
  // method. This method should only be called on UVM_EXPORT types. The value
  // must not be set before the end_of_elaboration phase, when port connections
  // have not yet been resolved.

  final public void set_default_index(size_t index) {
    synchronized(this) {
      _m_def_index = index;
    }
  }


  // Function: connect
  //
  // Connects this port to the given ~provider~ port. The ports must be
  // compatible in the following ways
  //
  // - Their type parameters must match
  //
  // - The ~provider~'s interface type (blocking, non-blocking, analysis, etc.)
  //   must be compatible. Each port has an interface mask that encodes the
  //   interface(s) it supports. If the bitwise AND of these masks is equal to
  //   the this port's mask, the requirement is met and the ports are
  //   compatible. For example, an uvm_blocking_put_port #(T) is compatible with
  //   an uvm_put_export #(T) and uvm_blocking_put_imp #(T) because the export
  //   and imp provide the interface required by the uvm_blocking_put_port.
  //
  // - Ports of type <UVM_EXPORT> can only connect to other exports or imps.
  //
  // - Ports of type <UVM_IMPLEMENTATION> can not be connected, as they are
  //   bound to the component that implements the interface at time of
  //   construction.
  //
  // In addition to type-compatibility checks, the relationship between this
  // port and the ~provider~ port will also be checked if the port's
  // ~check_connection_relationships~ configuration has been set. (See <new>
  // for more information.)
  //
  // Relationships, when enabled, are checked are as follows:
  //
  // - If this port is an UVM_PORT type, the ~provider~ can be a parent port,
  //   or a sibling export or implementation port.
  //
  // - If this port is an <UVM_EXPORT> type, the provider can be a child
  //   export or implementation port.
  //
  // If any relationship check is violated, a warning is issued.
  //
  // Note- the <uvm_component.connect> method is related to but not the same
  // as this method. The component's connect method is a phase callback where
  // port's connect method calls are made.

  public void connect (this_type provider) {
    synchronized(this) {
      uvm_root top = uvm_root.get();
      if (end_of_elaboration_ph.get_state() is UVM_PHASE_EXECUTING || // TBD tidy
	  end_of_elaboration_ph.get_state() is UVM_PHASE_DONE ) {
	m_comp.uvm_report_warning("Late Connection",
				  "Attempt to connect " ~
				  this.get_full_name() ~
				  " (of type " ~ this.get_type_name() ~
				  ") at or after end_of_elaboration phase."
				  "  Ignoring.");
	return;
      }

      if (provider is null) {
	m_comp.uvm_report_error(s_connection_error_id,
				"Cannot connect to null port handle", UVM_NONE);
	return;
      }

      if (provider is this) {
	m_comp.uvm_report_error(s_connection_error_id,
				"Cannot connect a port instance to itself",
				UVM_NONE);
	return;
      }

      if (provider is this) {
	m_comp.uvm_report_error(s_connection_error_id,
				"Cannot connect a port instance to itself",
				UVM_NONE);
	return;
      }

      if ((provider.m_if_mask & _m_if_mask) !is _m_if_mask) {
	m_comp.uvm_report_error(s_connection_error_id,
				provider.get_full_name() ~
				" (of type " ~ provider.get_type_name() ~
				") does not provide the complete interface"
				" required of this port (type " ~
				get_type_name() ~ ")", UVM_NONE);
	return;
      }

      // IMP.connect(anything) is illegal
      if (is_imp()) {
	m_comp.uvm_report_error(s_connection_error_id,
				format("Cannot call an imp port's connect"
				       " method. An imp is connected only"
				       " to the component passed in its"
				       " constructor. (You attempted to bind"
				       " this imp to %s)",
				       provider.get_full_name()), UVM_NONE);
	return;
      }

      // EXPORT.connect(PORT) are illegal
      if (is_export() && provider.is_port()) {
	m_comp.uvm_report_error(s_connection_error_id,
				format("Cannot connect exports to ports"
				       " Try calling port.connect(export)"
				       " instead. (You attempted to bind"
				       " this export to %s).",
				       provider.get_full_name()), UVM_NONE);
	return;
      }

      m_check_relationship(provider);

      _m_provided_by[provider.get_full_name()] = provider;
      synchronized(provider) {
	provider._m_provided_to[get_full_name()] = this;
      }
    }
  }


  // Function: debug_connected_to
  //
  // The debug_connected_to method outputs a visual text display of the
  // port/export/imp network to which this port connects (i.e., the port's
  // fanout).
  //
  // This method must not be called before the end_of_elaboration phase, as port
  // connections are not resolved until then.

  final public void debug_connected_to (int level=0, int max_level=-1) {
    synchronized(this) {
      string save;
      string indent;

      debug_connected_to(indent, save, level, max_level);

      if (level is 0) {
	if (save != "")
	  save = "This port's fanout network:\n\n  " ~
	    get_full_name() ~ " (" ~ get_type_name() ~ ")\n" ~ save ~ "\n";
	if (_m_imp_list.length is 0) {
	  uvm_root top = uvm_root.get();
	  if (end_of_elaboration_ph.get_state() is UVM_PHASE_EXECUTING ||
	      end_of_elaboration_ph.get_state() is UVM_PHASE_DONE ) { // TBD tidy
	    save ~= "  Connected implementations: none\n";
	  }
	  else {
	    save = save ~
	      "  Connected implementations: not resolved until end-of-elab\n";
	  }
	}
	else {
	  save ~= "  Resolved implementation list:\n";
	  int sz;
	  foreach (nm, port; _m_imp_list) {
	    string s_sz = sz.to!string();
	    save = save ~ indent ~ s_sz ~ ": " ~ nm ~ " (" ~
	      port.get_type_name() ~ ")\n";
	    ++sz;
	  }
	}
	m_comp.uvm_report_info("debug_connected_to", save);
      }
    }
  }

  // Auxilliary function
  // This is introduced in order to take out static variables save and
  // indent as coded in SV version

  final private void debug_connected_to(ref string save, ref string indent,
					int level, int max_level) {
    synchronized(this) {

      if (level <  0) level = 0;
      if (level is 0) { save = ""; indent="  "; }

      if (max_level !is -1 && level >= max_level) {
	return;
      }

      auto num = _m_provided_by.length;

      if (_m_provided_by.length !is 0) {
	int curr_num = 0;
	foreach (nm, port; _m_provided_by) {
	  ++curr_num;
	  save = save ~ indent ~ "  | \n";
	  save = save ~ indent ~ "  |_" ~ nm ~ " (" ~ port.get_type_name() ~
	    ")\n";
	  indent = (num > 1 && curr_num !is num) ?  indent ~ "  | " :
	    indent ~ "    ";
	  port.debug_connected_to(level+1, max_level);
	  indent = indent[0..$-4];
	}
      }
    }
  }


  // Function: debug_provided_to
  //
  // The debug_provided_to method outputs a visual display of the port/export
  // network that ultimately connect to this port (i.e., the port's fanin).
  //
  // This method must not be called before the end_of_elaboration phase, as port
  // connections are not resolved until then.

  final public void debug_provided_to (int level=0, int max_level=-1) {
    synchronized(this) {
      string save;
      string indent;

      debug_provided_to(save, indent, level, max_level);

      if (level is 0) {
	if (save != "") {
	  save = "This port's fanin network:\n\n  " ~
	    get_full_name() ~ " (" ~ get_type_name() ~ ")\n" ~ save ~ "\n";
	}
	if (_m_provided_to.length is 0) {
	  save = save ~ indent ~ "This port has not been bound\n";
	}
	m_comp.uvm_report_info("debug_provided_to", save);
      }

    }
  }

  // Auxilliary function
  // This is introduced in order to take out static variables save and
  // indent as coded in SV version

  final private void debug_provided_to  (ref string save, ref string indent,
					 int level = 0, int max_level = -1) {
    synchronized(this) {
      if (level <  0) level = 0;
      if (level is 0) { save = ""; indent = "  "; }

      if (max_level !is -1 && level > max_level) {
	return;
      }

      auto num = _m_provided_to.length;

      if (num !is 0) {
	int curr_num = 0;
	foreach (nm, port; _m_provided_to) {
	  ++curr_num;
	  save = save ~ indent ~ "  | \n";
	  save = save ~ indent ~ "  |_" ~ nm ~ " (" ~
	    port.get_type_name() ~ ")\n";
	  indent = (num > 1 && curr_num !is num) ?
	    indent ~ "  | " :  indent ~ "    ";
	  port.debug_provided_to(level+1, max_level);
	  indent = indent[0..$-4];
	}
      }

    }
  }

  // get_connected_to
  // ----------------

  final public void get_connected_to (out uvm_port_list list) {
    synchronized(this) {
      // list = null; // taken care by 'out'
      foreach (name, port; _m_provided_by) {
	list[name] = port.get_comp();
      }
    }
  }

  final public uvm_port_list get_connected_to () {
    synchronized(this) {
      uvm_port_list list;
      foreach (name, port; _m_provided_by) {
	list[name] = port.get_comp();
      }
      return list;
    }
  }

  // get_provided_to
  // ---------------

  final public void get_provided_to (out uvm_port_list list) {
    synchronized(this) {
      // list = null; // taken care by 'out'
      foreach (name, port; _m_provided_to) {
	list[name] = port.get_comp();
      }
    }
  }

  final public uvm_port_list get_provided_to () {
    synchronized(this) {
      uvm_port_list list;
      foreach (name, port; _m_provided_to) {
	list[name] = port.get_comp();
      }
      return list;
    }
  }

  // m_check_relationship
  // --------------------

  final private bool  m_check_relationship(this_type provider) {
    synchronized(this) {

      // Checks that the connection is between ports that are hierarchically
      // adjacent (up or down one level max, or are siblings),
      // and check for legal direction, requirer.connect(provider).

      // if we're an analysis port, allow connection to anywhere
      if (get_type_name() is "uvm_analysis_port") {
	return true;
      }

      this_type from = this;
      uvm_component from_parent = get_parent();
      uvm_component to_parent = provider.get_parent();

      // skip check if we have a parentless port
      if(from_parent is null || to_parent is null) {
	return true;
      }

      uvm_component from_gparent = from_parent.get_parent();
      uvm_component to_gparent = to_parent.get_parent();

      // Connecting port-to-port: CHILD.port.connect(PARENT.port)
      //
      if(from.is_port() && provider.is_port() && from_gparent !is to_parent) {
	string s = provider.get_full_name() ~
	  " (of type " ~ provider.get_type_name() ~
	  ") is not up one level of hierarchy from this port. " ~
	  "A port-to-port connection takes the form " ~
	  "child_component.child_port.connect(parent_port)";
	m_comp.uvm_report_warning(s_connection_warning_id, s, UVM_NONE);
	return false;
      }

      // Connecting port-to-export: SIBLING.port.connect(SIBLING.export)
      // Connecting port-to-imp:    SIBLING.port.connect(SIBLING.imp)
      //
      else if(from.is_port() && (provider.is_export() || provider.is_imp()) &&
	      from_gparent !is to_gparent) {
	string s = provider.get_full_name() ~
	  " (of type " ~ provider.get_type_name() ~
	  ") is not at the same level of hierarchy as this port. " ~
	  "A port-to-export connection takes the form " ~
	  "component1.port.connect(component2.export)";
	m_comp.uvm_report_warning(s_connection_warning_id, s, UVM_NONE);
	return false;
      }

      // Connecting export-to-export: PARENT.export.connect(CHILD.export)
      // Connecting export-to-imp:    PARENT.export.connect(CHILD.imp)
      //
      else if(from.is_export() && (provider.is_export() || provider.is_imp()) &&
	      from_parent !is to_gparent) {
	string s = provider.get_full_name() ~
	  " (of type " ~ provider.get_type_name() ~
	  ") is not down one level of hierarchy from this export. " ~
	  "An export-to-export or export-to-imp connection takes the form " ~
	  "parent_export.connect(child_component.child_export)";
	m_comp.uvm_report_warning(s_connection_warning_id, s, UVM_NONE);
	return false;
      }

      return true;
    }
  }


  // m_add_list
  //
  // Internal method.

  final private void m_add_list(this_type provider) {
    synchronized(this) {
      for (size_t i = 0; i < provider.size(); ++i) {
	this_type imp = provider.get_if(i);
	if (imp.get_full_name() !in _m_imp_list) {
	  _m_imp_list[imp.get_full_name()] = imp;
	}
      }

    }
  }


  // Function: resolve_bindings
  //
  // This callback is called just before entering the end_of_elaboration phase.
  // It recurses through each port's fanout to determine all the imp destina-
  // tions. It then checks against the required min and max connections.
  // After resolution, <size> returns a valid value and <get_if>
  // can be used to access a particular imp.
  //
  // This method is automatically called just before the start of the
  // end_of_elaboration phase. Users should not need to call it directly.

  public void resolve_bindings() {
    synchronized(this) {
      if (_m_resolved) { // don't repeat ourselves
	return;
      }

      if (is_imp()) {
	_m_imp_list[get_full_name()] = this;
      }
      else {
	foreach (port; _m_provided_by) {
	  port.resolve_bindings();
	  m_add_list(port);
	}
      }

      _m_resolved = true;

      if (size() < min_size() ) {
	m_comp.uvm_report_error(s_connection_error_id,
				format("connection count of %0d does not"
				       " meet required minimum of %0d",
				       size(), min_size()), UVM_NONE);
      }

      if (max_size() !is UVM_UNBOUNDED_CONNECTIONS && size() > max_size() ) {
	m_comp.uvm_report_error(s_connection_error_id,
				format("connection count of %0d exceeds"
				       " maximum of %0d",
				       size(), max_size()), UVM_NONE);
      }

      if (size()) {
	set_if(0);
      }
    }
  }


  // Function: get_if
  //
  // Returns the implementation (imp) port at the given index from the array of
  // imps this port is connected to. Use <size> to get the valid range for index.
  // This method can only be called at the end_of_elaboration phase or after, as
  // port connections are not resolved before then.

  final public uvm_port_base!IF get_if(size_t index=0) {
    synchronized(this) {
      if (size() is 0) {
	m_comp.uvm_report_warning("get_if",
				  "Port size is zero; cannot get interface"
				  " at any index", UVM_NONE);
	return null;
      }
      if (index < 0 || index >= size()) {
	string s = format("Index %0d out of range [0,%0d]", index, size()-1);
	m_comp.uvm_report_warning(s_connection_error_id, s, UVM_NONE);
	return null;
      }
      foreach (nm, port; _m_imp_list) {
	if (index is 0) {
	  return port;
	}
	--index;
      }
      return null;
    }
  }
};				// extra semicolon for emacs indent

// import uvm.base.uvm_object;
// alias uvm_port_component!(uvm_port_base!uvm_object) uvm_port_object_check_compile;
