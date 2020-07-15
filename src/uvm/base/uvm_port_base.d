//
//------------------------------------------------------------------------------
// Copyright 2014-2019 Coverify Systems Technology
// Copyright 2007-2018 Mentor Graphics Corporation
// Copyright 2015 Analog Devices, Inc.
// Copyright 2014 Semifore
// Copyright 2014 Intel Corporation
// Copyright 2010-2018 Synopsys, Inc.
// Copyright 2007-2018 Cadence Design Systems, Inc.
// Copyright 2010 AMD
// Copyright 2014-2018 NVIDIA Corporation
// Copyright 2012-2017 Cisco Systems, Inc.
// Copyright 2017 Verific
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
import uvm.base.uvm_component: uvm_component;
import uvm.base.uvm_phase: uvm_phase;
import uvm.base.uvm_object_globals: uvm_port_type_e;

import uvm.meta.misc;
import esdl.rand: _esdl__Norand;

import std.string: format;
import std.conv: to;


enum int UVM_UNBOUNDED_CONNECTIONS = -1;
enum string s_connection_error_id = "Connection Error";
enum string s_connection_warning_id = "Connection Warning";
enum string s_spaces = "                       ";

// TITLE: Port Base Classes
//


//
// CLASS: uvm_port_list
//
// Associative array of uvm_port_component_base class handles, indexed by string
//
// @uvm-accellera The details of this API are specific to the Accellera implementation, and are not being considered for contribution to 1800.2

alias uvm_port_list = uvm_port_component_base[string];


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
// Each port's full name and type name can be retrieved using ~get_full_name~ 
// and ~get_type_name~ methods inherited from <uvm_component>.
//
// @uvm-accellera The details of this API are specific to the Accellera implementation, and are not being considered for contribution to 1800.2
//------------------------------------------------------------------------------

abstract class uvm_port_component_base: uvm_component
{

  this(string name="", uvm_component parent=null) {
    super(name, parent);
  }

  // Function: get_connected_to
  //
  // For a port or export type, this function fills ~list~ with all
  // of the ports, exports and implementations that this port is
  // connected to.
  //
  // @uvm-accellera The details of this API are specific to the Accellera implementation, and are not being considered for contribution to 1800.2
  
  abstract void get_connected_to(out uvm_port_list list);
  abstract uvm_port_list get_connected_to();

  // Function -- NODOCS -- is_port
  //
  abstract bool is_port();

  // Function -- NODOCS -- is_export
  //
  abstract bool is_export();

  // Function -- NODOCS -- is_imp
  //
  // These function determine the type of port. The functions are
  // mutually exclusive; one will return 1 and the other two will
  // return 0.

  abstract bool is_imp();

  // Turn off auto config by not calling build_phase()
  override bool use_automatic_config() {
    return false;
  }
   
  // task
  void do_task_phase (uvm_phase phase) {}
}


//------------------------------------------------------------------------------
//
// CLASS -- NODOCS -- uvm_port_component #(PORT)
//
//------------------------------------------------------------------------------
// This implementation of uvm_port_component class from IEEE 1800.2 declares all the
// API described in the LRM, plus it inherits from uvm_port_component_base for the
// purpose of providing the get_connected_to() method.
//
// @uvm-accellera The details of this API are specific to the Accellera implementation, and are not being considered for contribution to 1800.2
//------------------------------------------------------------------------------
class uvm_port_component(PORT=uvm_object): uvm_port_component_base
{
  mixin (uvm_sync_string);

  // These needs further investigation
  // The component becomes accessible via the port -- FIXME
  override void uvm__auto_build() { }

  @uvm_immutable_sync
  private PORT _m_port;

  this(string name, uvm_component parent, PORT port) {
    import uvm.base.uvm_object_globals;
    synchronized (this) {
      super(name, parent);
      if (port is null) {
	uvm_report_fatal("Bad usage", "Null handle to port", uvm_verbosity.UVM_NONE);
      }
      _m_port = port;
    }
  }

  override string get_type_name() {
    if (m_port is null) return "uvm_port_component";
    return m_port.get_type_name();
  }

  override void resolve_bindings() {
    m_port.resolve_bindings();
  }

  // Function -- NODOCS -- get_port
  //
  // Retrieve the actual port object that this proxy refers to.

  final PORT get_port() {
    return m_port;
  }

  // Function: get_connected_to
  //
  // Implementation of the pure function declared in uvm_port_component_base
  //
  // @uvm-accellera The details of this API are specific to the Accellera implementation, and are not being considered for contribution to 1800.2

  override void get_connected_to(out uvm_port_list list) {
    PORT[string] list1;
    m_port.get_connected_to(list1);
    foreach (name, port; list1) {
      list[name] = port.get_comp();
    }
  }

  override uvm_port_list get_connected_to() {
    PORT[string] list1 = m_port.get_connected_to();
    uvm_port_list list;
    foreach (name, port; list1) {
      list[name] = port.get_comp();
    }
    return list;
  }

  final override bool is_port () {
    return m_port.is_port();
  }

  final override bool is_export () {
    return m_port.is_export();
  }

  final override bool is_imp () {
    return m_port.is_imp();
  }

};				// extra semicolon for emacs indent


//------------------------------------------------------------------------------
//
// CLASS -- NODOCS -- uvm_port_base #(IF)
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
// The UVM provides a complete set of ports, exports, and imps to enable transaction-level communication between entities.
// They can be found in the ../src/tlm*/ directory. See Section 12.1 of the IEEE Spec for details.
//
// Just before <uvm_component.end_of_elaboration_phase>, an internal
// <uvm_component.resolve_bindings> process occurs, after which each port and
// export holds a list of all imps connected to it via hierarchical connections
// to other ports and exports. In effect, we are collapsing the port's fanout,
// which can span several levels up and down the component hierarchy, into a
// single array held local to the port. Once the list is determined, the port's
// min and max connection settings can be checked and enforced.
//
// uvm_port_base possesses the properties of components in that they have a
// hierarchical instance path and parent. Because SystemVerilog does not support
// multiple inheritance, uvm_port_base cannot extend both the interface it
// implements and <uvm_component>. Thus, uvm_port_base contains a local instance
// of uvm_component, to which it delegates such commands as get_name,
// get_full_name, and get_parent.
// The connectivity lists are returned in the form of handles to objects of this
// type. This allowing traversal of any port's fan-out and fan-in network
// through recursive calls to <get_connected_to> and <get_provided_to>. 
//
//------------------------------------------------------------------------------

// Class: uvm_port_base
// The library implements the following public API beyond what is documented
// in 1800.2.

// @uvm-ieee 1800.2-2017 auto 5.5.1
abstract class uvm_port_base(IF = uvm_void): IF, _esdl__Norand
{

  mixin (uvm_sync_string);

  alias this_type = uvm_port_base!IF;

  // local, protected, and non-user properties

  @uvm_protected_sync
  private uint                                  _m_if_mask;
  @uvm_protected_sync
  private this_type                             _m_if;    // REMOVE
  private size_t                                _m_def_index;
  @uvm_immutable_sync
  private uvm_port_component!this_type          _m_comp;
  private this_type[string]                     _m_provided_by;
  private this_type[string]                     _m_provided_to;
  private uvm_port_type_e                       _m_port_type;
  private int                                   _m_min_size;
  private int                                   _m_max_size;
  private bool                                  _m_resolved;
  private this_type[string]                     _m_imp_list;

  // Function -- NODOCS -- new
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
  // port's ~check_connection_relationships~ bit via ~uvm_config_int::set()~. See
  // <connect> for more information.

  // @uvm-ieee 1800.2-2017 auto 5.5.2.1
  this(string name,
	      uvm_component parent,
	      uvm_port_type_e port_type,
	      int min_size = 0,
	      int max_size = 1
	      ) {
    import uvm.base.uvm_config_db;
    import uvm.base.uvm_object_globals;
    synchronized (this) {
      // uvm_component comp;
      _m_port_type = port_type;
      _m_min_size  = min_size;
      _m_max_size  = max_size;
      _m_comp = new uvm_port_component!this_type(name, parent, this);

      int tmp;
      if (!uvm_config_db!int.get(_m_comp, "", "check_connection_relationships",
				 tmp)) {
	_m_comp.set_report_id_action(s_connection_warning_id, uvm_action_type.UVM_NO_ACTION);
      }
    }
  }


  // Function -- NODOCS -- get_name
  //
  // Returns the leaf name of this port.

  // @uvm-ieee 1800.2-2017 auto 5.5.2.2
  string get_name() {
    return m_comp.get_name();
  }


  // Function -- NODOCS -- get_full_name
  //
  // Returns the full hierarchical name of this port.

  // @uvm-ieee 1800.2-2017 auto 5.5.2.3
  string get_full_name() {
    return m_comp.get_full_name();
  }


  // Function -- NODOCS -- get_parent
  //
  // Returns the handle to this port's parent, or ~null~ if it has no parent.

  // @uvm-ieee 1800.2-2017 auto 5.5.2.4
  uvm_component get_parent() {
    return m_comp.get_parent();
  }


  // Function -- NODOCS -- get_comp
  //
  // Returns a handle to the internal proxy component representing this port.
  //
  // Ports are considered components. However, they do not inherit
  // <uvm_component>. Instead, they contain an instance of
  // <uvm_port_component #(PORT)> that serves as a proxy to this port.
  //
  // @uvm-accellera The details of this API are specific to the Accellera implementation, and are not being considered for contribution to 1800.2

  uvm_port_component_base get_comp() {
    return m_comp;
  }


  // Function -- NODOCS -- get_type_name
  //
  // Returns the type name to this port. Derived port classes must implement
  // this method to return the concrete type. Otherwise, only a generic
  // "uvm_port", "uvm_export" or "uvm_implementation" is returned.

  // @uvm-ieee 1800.2-2017 auto 5.5.2.5
  string get_type_name() {
    import uvm.base.uvm_object_globals;
    synchronized (this) {
      switch (_m_port_type) {
      case uvm_port_type_e.UVM_PORT : return "port";
      case uvm_port_type_e.UVM_EXPORT : return "export";
      case uvm_port_type_e.UVM_IMPLEMENTATION : return "implementation";
      default:
	assert (false, "Invalid port type");
      }
    }
  }


  // Function -- NODOCS -- min_size
  //
  // Returns the minimum number of implementation ports that must
  // be connected to this port by the end_of_elaboration phase.

  // @uvm-ieee 1800.2-2017 auto 5.5.2.7
  final int max_size() {
    synchronized (this) {
      return _m_max_size;
    }
  }


  // Function -- NODOCS -- max_size
  //
  // Returns the maximum number of implementation ports that must
  // be connected to this port by the end_of_elaboration phase.

  // @uvm-ieee 1800.2-2017 auto 5.5.2.6
  final int min_size() {
    synchronized (this) {
      return _m_min_size;
    }
  }


  // Function -- NODOCS -- is_unbounded
  //
  // Returns 1 if this port has no maximum on the number of implementation
  // ports this port can connect to. A port is unbounded when the ~max_size~
  // argument in the constructor is specified as ~UVM_UNBOUNDED_CONNECTIONS~.

  // @uvm-ieee 1800.2-2017 auto 5.5.2.8
  final bool is_unbounded() {
    synchronized (this) {
      return (_m_max_size == UVM_UNBOUNDED_CONNECTIONS);
    }
  }


  // Function -- NODOCS -- is_port

  // @uvm-ieee 1800.2-2017 auto 5.5.2.9
  final bool is_port() {
    import uvm.base.uvm_object_globals;
    synchronized (this) {
      return _m_port_type == uvm_port_type_e.UVM_PORT;
    }
  }

  // Function -- NODOCS -- is_export

  // @uvm-ieee 1800.2-2017 auto 5.5.2.10
  final bool is_export() {
    import uvm.base.uvm_object_globals;
    synchronized (this) {
      return _m_port_type == uvm_port_type_e.UVM_EXPORT;
    }
  }

  // Function -- NODOCS -- is_imp
  //
  // Returns 1 if this port is of the type given by the method name,
  // 0 otherwise.

  // @uvm-ieee 1800.2-2017 auto 5.5.2.11
  final bool is_imp() {
    import uvm.base.uvm_object_globals;
    synchronized (this) {
      return _m_port_type == uvm_port_type_e.UVM_IMPLEMENTATION;
    }
  }


  // Function -- NODOCS -- size
  //
  // Gets the number of implementation ports connected to this port. The value
  // is not valid before the end_of_elaboration phase, as port connections have
  // not yet been resolved.

  // @uvm-ieee 1800.2-2017 auto 5.5.2.12
  final size_t size () {
    synchronized (this) {
      return _m_imp_list.length;
    }
  }


  final void set_if(size_t index=0) {
    synchronized (this) {
      _m_if = get_if(index);
      if (_m_if !is null) {
	_m_def_index = index;
      }
    }
  }

  final int m_get_if_mask() {
    synchronized (this) {
      return _m_if_mask;
    }
  }


  // Function -- NODOCS -- set_default_index
  //
  // Sets the default implementation port to use when calling an interface
  // method. This method should only be called on UVM_EXPORT types. The value
  // must not be set before the end_of_elaboration phase, when port connections
  // have not yet been resolved.

  // @uvm-ieee 1800.2-2017 auto 5.5.2.12
  final void set_default_index(size_t index) {
    synchronized (this) {
      _m_def_index = index;
    }
  }


  // Function -- NODOCS -- connect
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
  //   compatible. For example, a uvm_blocking_put_port #(T) is compatible with
  //   a uvm_put_export #(T) and uvm_blocking_put_imp #(T) because the export
  //   and imp provide the interface required by the uvm_blocking_put_port.
  //
  // - Ports of type <UVM_EXPORT> can only connect to other exports or imps.
  //
  // - Ports of type <UVM_IMPLEMENTATION> cannot be connected, as they are
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
  // - If this port is a UVM_PORT type, the ~provider~ can be a parent port,
  //   or a sibling export or implementation port.
  //
  // - If this port is a <UVM_EXPORT> type, the provider can be a child
  //   export or implementation port.
  //
  // If any relationship check is violated, a warning is issued.
  //
  // Note- the <uvm_component.connect_phase> method is related to but not the same
  // as this method. The component's ~connect~ method is a phase callback where
  // port's ~connect~ method calls are made.

  // @uvm-ieee 1800.2-2017 auto 5.5.2.14
  void connect (this_type provider) {
    import uvm.base.uvm_domain;
    import uvm.base.uvm_object_globals;
    synchronized (this) {
      // next two lines add dependency on uvm_root -- otherwise redundant code from SV UVM
      // uvm_coreservice_t cs = uvm_coreservice_t.get();
      // uvm_root top = cs.get_root();
      if (end_of_elaboration_ph.get_state() == uvm_phase_state.UVM_PHASE_EXECUTING || // TBD tidy
	  end_of_elaboration_ph.get_state() == uvm_phase_state.UVM_PHASE_DONE ) {
	m_comp.uvm_report_warning("Late Connection", "Attempt to connect " ~
				  this.get_full_name() ~ " (of type " ~
				  this.get_type_name() ~ ") at or after " ~
				  "end_of_elaboration phase.  Ignoring.");
	return;
      }

      if (provider is null) {
	m_comp.uvm_report_error(s_connection_error_id,
				"Cannot connect to null port handle", uvm_verbosity.UVM_NONE);
	return;
      }

      if (provider is this) {
	m_comp.uvm_report_error(s_connection_error_id,
				"Cannot connect a port instance to itself",
				uvm_verbosity.UVM_NONE);
	return;
      }

      if ((provider.m_if_mask & _m_if_mask) !is _m_if_mask) {
	m_comp.uvm_report_error(s_connection_error_id,
				provider.get_full_name() ~ " (of type " ~
				provider.get_type_name() ~
				") does not provide the complete interface" ~
				" required of this port (type " ~
				get_type_name() ~ ")", uvm_verbosity.UVM_NONE);
	return;
      }

      // IMP.connect(anything) is illegal
      if (is_imp()) {
	m_comp.uvm_report_error(s_connection_error_id,
				format("Cannot call an imp port's connect" ~
				       " method. An imp is connected only" ~
				       " to the component passed in its" ~
				       " constructor. (You attempted to bind" ~
				       " this imp to %s)",
				       provider.get_full_name()), uvm_verbosity.UVM_NONE);
	return;
      }

      // EXPORT.connect(PORT) are illegal
      if (is_export() && provider.is_port()) {
	m_comp.uvm_report_error(s_connection_error_id,
				format("Cannot connect exports to ports" ~
				       " Try calling port.connect(export)" ~
				       " instead. (You attempted to bind" ~
				       " this export to %s).",
				       provider.get_full_name()), uvm_verbosity.UVM_NONE);
	return;
      }

      m_check_relationship(provider);

      synchronized (provider) {
	_m_provided_by[provider.get_full_name()] = provider;
	provider._m_provided_to[get_full_name()] = this;
      }
    }
  }


  // Function -- NODOCS -- debug_connected_to
  //
  // The ~debug_connected_to~ method outputs a visual text display of the
  // port/export/imp network to which this port connects (i.e., the port's
  // fanout).
  //
  // This method must not be called before the end_of_elaboration phase, as port
  // connections are not resolved until then.
  //
  // @uvm-accellera The details of this API are specific to the Accellera implementation, and are not being considered for contribution to 1800.2


  final void debug_connected_to (int level=0, int max_level=-1) {
    import uvm.base.uvm_domain;
    import uvm.base.uvm_object_globals;
    synchronized (this) {
      string save;
      string indent;

      // save and indent are static in the SV version -- we indulge in
      // some refactoring here to make these variales mapped to stack
      debug_connected_to(indent, save, level, max_level);

      if (level == 0) {
	if (save != "")
	  save = "This port's fanout network:\n\n  " ~
	    get_full_name() ~ " (" ~ get_type_name() ~ ")\n" ~ save ~ "\n";
	if (_m_imp_list.length == 0) {
	  // next two lines add dependency on uvm_root -- otherwise redundant code from SV UVM
	  // uvm_coreservice_t cs = uvm_coreservice_t.get();
	  // uvm_root top = cs.get_root();
	  if (end_of_elaboration_ph.get_state() == uvm_phase_state.UVM_PHASE_EXECUTING ||
	      end_of_elaboration_ph.get_state() == uvm_phase_state.UVM_PHASE_DONE ) { // TBD tidy
	    save ~= "  Connected implementations: none\n";
	  }
	  else {
	    save ~=
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
    synchronized (this) {

      if (level <  0) {
	level = 0;
      }
      if (level == 0) {
	save = "";
	indent = "  ";
      }

      if (max_level != -1 && level >= max_level) {
	return;
      }

      auto num = _m_provided_by.length;

      if (_m_provided_by.length != 0) {
	int curr_num = 0;
	foreach (nm, port; _m_provided_by) {
	  ++curr_num;
	  save = save ~ indent ~ "  | \n";
	  save = save ~ indent ~ "  |_" ~ nm ~ " (" ~ port.get_type_name() ~
	    ")\n";
	  indent = (num > 1 && curr_num !is num) ?
	    indent ~ "  | " : indent ~ "    ";
	  port.debug_connected_to(save, indent, level+1, max_level);
	  indent = indent[0..$-4];
	}
      }
    }
  }


  // Function -- NODOCS -- debug_provided_to
  //
  // The ~debug_provided_to~ method outputs a visual display of the port/export
  // network that ultimately connect to this port (i.e., the port's fanin).
  //
  // This method must not be called before the end_of_elaboration phase, as port
  // connections are not resolved until then.
  //
  // @uvm-accellera The details of this API are specific to the Accellera implementation, and are not being considered for contribution to 1800.2


  final void debug_provided_to (int level=0, int max_level=-1) {
    synchronized (this) {
      string save;
      string indent;

      // save and indent are static in the SV version -- we indulge in
      // some refactoring here to make these variales mapped to stack
      debug_provided_to(save, indent, level, max_level);

      if (level == 0) {
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
    synchronized (this) {
      if (level <  0) level = 0;
      if (level == 0) { save = ""; indent = "  "; }

      if (max_level != -1 && level > max_level) {
	return;
      }

      auto num = _m_provided_to.length;

      if (num != 0) {
	int curr_num = 0;
	foreach (nm, port; _m_provided_to) {
	  ++curr_num;
	  save = save ~ indent ~ "  | \n";
	  save = save ~ indent ~ "  |_" ~ nm ~ " (" ~
	    port.get_type_name() ~ ")\n";
	  indent = (num > 1 && curr_num != num) ?
	    indent ~ "  | " :  indent ~ "    ";
	  port.debug_provided_to(save, indent, level+1, max_level);
	  indent = indent[0..$-4];
	}
      }

    }
  }

  // get_connected_to
  // ----------------

  // @uvm-ieee 1800.2-2017 auto 5.5.2.9
  final void get_connected_to (out uvm_port_base!IF[string] list) {
    synchronized (this) {
      // list = null; // taken care by 'out'
      foreach (name, port; _m_provided_by) {
	list[name] = port;
      }
    }
  }

  final uvm_port_base!IF[string] get_connected_to () {
    synchronized (this) {
      uvm_port_base!IF[string] list;
      foreach (name, port; _m_provided_by) {
	list[name] = port;
      }
      return list;
    }
  }

  // get_provided_to
  // ---------------

  final void get_provided_to (out uvm_port_base!IF[string] list) {
    synchronized (this) {
      foreach (name, port; _m_provided_to) {
	list[name] = port;
      }
    }
  }

  final uvm_port_base!IF[string] get_provided_to () {
    synchronized (this) {
      uvm_port_base!IF[string] list;
      foreach (name, port; _m_provided_to) {
	list[name] = port;
      }
      return list;
    }
  }

  // m_check_relationship
  // --------------------

  final private bool  m_check_relationship(this_type provider) {
    import uvm.base.uvm_object_globals;
    synchronized (this) {

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
      if (from_parent is null || to_parent is null) {
	return true;
      }

      uvm_component from_gparent = from_parent.get_parent();
      uvm_component to_gparent = to_parent.get_parent();

      // Connecting port-to-port: CHILD.port.connect(PARENT.port)
      //
      if (from.is_port() && provider.is_port() && from_gparent !is to_parent) {
	string s = provider.get_full_name() ~
	  " (of type " ~ provider.get_type_name() ~
	  ") is not up one level of hierarchy from this port. " ~
	  "A port-to-port connection takes the form " ~
	  "child_component.child_port.connect(parent_port)";
	m_comp.uvm_report_warning(s_connection_warning_id, s, uvm_verbosity.UVM_NONE);
	return false;
      }

      // Connecting port-to-export: SIBLING.port.connect(SIBLING.export)
      // Connecting port-to-imp:    SIBLING.port.connect(SIBLING.imp)
      //
      else if (from.is_port() && (provider.is_export() || provider.is_imp()) &&
	      from_gparent !is to_gparent) {
	string s = provider.get_full_name() ~
	  " (of type " ~ provider.get_type_name() ~
	  ") is not at the same level of hierarchy as this port. " ~
	  "A port-to-export connection takes the form " ~
	  "component1.port.connect(component2.export)";
	m_comp.uvm_report_warning(s_connection_warning_id, s, uvm_verbosity.UVM_NONE);
	return false;
      }

      // Connecting export-to-export: PARENT.export.connect(CHILD.export)
      // Connecting export-to-imp:    PARENT.export.connect(CHILD.imp)
      //
      else if (from.is_export() && (provider.is_export() || provider.is_imp()) &&
	      from_parent !is to_gparent) {
	string s = provider.get_full_name() ~
	  " (of type " ~ provider.get_type_name() ~
	  ") is not down one level of hierarchy from this export. " ~
	  "An export-to-export or export-to-imp connection takes the form " ~
	  "parent_export.connect(child_component.child_export)";
	m_comp.uvm_report_warning(s_connection_warning_id, s, uvm_verbosity.UVM_NONE);
	return false;
      }

      return true;
    }
  }


  // m_add_list
  //
  // Internal method.

  final private void m_add_list(this_type provider) {
    synchronized (this) {
      for (size_t i = 0; i < provider.size(); ++i) {
	this_type imp = provider.get_if(i);
	if (imp.get_full_name() !in _m_imp_list) {
	  _m_imp_list[imp.get_full_name()] = imp;
	}
      }

    }
  }


  // Function -- NODOCS -- resolve_bindings
  //
  // This callback is called just before entering the end_of_elaboration phase.
  // It recurses through each port's fanout to determine all the imp 
  // destinations. It then checks against the required min and max connections.
  // After resolution, <size> returns a valid value and <get_if>
  // can be used to access a particular imp.
  //
  // This method is automatically called just before the start of the
  // end_of_elaboration phase. Users should not need to call it directly.

  // @uvm-ieee 1800.2-2017 auto 5.5.2.15
  void resolve_bindings() {
    import uvm.base.uvm_object_globals;
    synchronized (this) {
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
				format("connection count of %0d does not" ~
				       " meet required minimum of %0d",
				       size(), min_size()), uvm_verbosity.UVM_NONE);
      }

      if (max_size() !is UVM_UNBOUNDED_CONNECTIONS && size() > max_size() ) {
	m_comp.uvm_report_error(s_connection_error_id,
				format("connection count of %0d exceeds" ~
				       " maximum of %0d",
				       size(), max_size()), uvm_verbosity.UVM_NONE);
      }

      if (size()) {
	set_if(0);
      }
    }
  }


  // Function -- NODOCS -- get_if
  //
  // Returns the implementation (imp) port at the given index from the array of
  // imps this port is connected to. Use <size> to get the valid range for index.
  // This method can only be called at the end_of_elaboration phase or after, as
  // port connections are not resolved before then.

  final uvm_port_base!IF get_if(size_t index=0) {
    import uvm.base.uvm_object_globals;
    synchronized (this) {
      if (size() == 0) {
	m_comp.uvm_report_warning("get_if",
				  "Port size is zero; cannot get interface" ~
				  " at any index", uvm_verbosity.UVM_NONE);
	return null;
      }
      if (index < 0 || index >= size()) {
	string s = format("Index %0d out of range [0,%0d]", index, size()-1);
	m_comp.uvm_report_warning(s_connection_error_id, s, uvm_verbosity.UVM_NONE);
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
