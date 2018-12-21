//
//------------------------------------------------------------------------------
// Copyright 2014-2018 Coverify Systems Technology
// Copyright 2007-2014 Mentor Graphics Corporation
// Copyright 2015 Analog Devices, Inc.
// Copyright 2014 Semifore
// Copyright 2017 Intel Corporation
// Copyright 2018 Qualcomm, Inc.
// Copyright 2011 Synopsys, Inc.
// Copyright 2007-2018 Cadence Design Systems, Inc.
// Copyright 2013 Verilab
// Copyright 2013-2018 NVIDIA Corporation
// Copyright 2017 Cisco Systems, Inc.
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


module uvm.base.uvm_factory;

import uvm.base.uvm_object: uvm_object;
import uvm.base.uvm_component: uvm_component;


import uvm.base.uvm_once;

import uvm.meta.misc;
import uvm.meta.mcd;

// import esdl.data.queue;
import std.string: format;

// typedef class uvm_object;
// typedef class uvm_component;
// typedef class uvm_object_wrapper;
// typedef class uvm_factory_override;

struct m_uvm_factory_type_pair_t
{
  uvm_object_wrapper m_type;
  string             m_type_name;
} 

//Instance overrides by requested type lookup
final class uvm_factory_queue_class
{
  uvm_factory_override[] _queue;

  public uvm_factory_override[] get_queue() {
    synchronized(this) {
      return _queue.dup;
    }
  }

  uvm_factory_queue_class clone() {
    auto clone_ = new uvm_factory_queue_class;
    auto q = get_queue();
    synchronized(clone_) {
      clone_._queue = q;
    }
    return clone_;
  }

  final uvm_factory_override opIndex(size_t index) {
    synchronized(this) {
      return _queue[index];
    }
  }

  final int opApply(int delegate(ref size_t, ref uvm_factory_override) dg) {
    synchronized(this) {
      int retval = 0;
      for(size_t i = 0; i != _queue.length; ++i) {
	retval = dg(i, _queue[i]);
	if(retval) break;
      }
      return retval;
    }
  }

  final int opApply(int delegate(ref uvm_factory_override) dg) {
    synchronized(this) {
      int retval = 0;
      for(size_t i = 0; i != _queue.length; ++i) {
	retval = dg(_queue[i]);
	if(retval) break;
      }
      return retval;
    }
  }

  final size_t length() {
    synchronized(this) {
      return _queue.length;
    }
  }

  // Function -- NODOCS -- pop_front
  //
  // Returns the first element in the queue (index=0),
  // or ~null~ if the queue is empty.

  final uvm_factory_override pop_front() {
    synchronized(this) {
      auto retval = _queue[0];
      _queue = _queue[1..$];
      return retval;
    }
  }


  // Function -- NODOCS -- pop_back
  //
  // Returns the last element in the queue (index=size()-1),
  // or ~null~ if the queue is empty.

  final uvm_factory_override pop_back() {
    synchronized(this) {
      auto retval = _queue[$-1];
      _queue.length -= 1;
      return retval;
    }
  }


  // Function -- NODOCS -- push_front
  //
  // Inserts the given ~item~ at the front of the queue.

  final void push_front(uvm_factory_override item) {
    synchronized(this) {
      import std.array: insertInPlace;
      _queue.insertInPlace(0, item);
    }
  }

  // Function -- NODOCS -- push_back
  //
  // Inserts the given ~item~ at the back of the queue.

  final void push_back(uvm_factory_override item) {
    synchronized(this) {
      _queue ~= item;
    }
  }

}

//------------------------------------------------------------------------------
// Title -- NODOCS -- UVM Factory
//
// This page covers the classes that define the UVM factory facility.
//------------------------------------------------------------------------------


//------------------------------------------------------------------------------
//
// CLASS -- NODOCS -- uvm_factory
//
//------------------------------------------------------------------------------
//
// As the name implies, uvm_factory is used to manufacture (create) UVM objects
// and components. Object and component types are registered
// with the factory using lightweight proxies to the actual objects and
// components being created. The <uvm_object_registry #(T,Tname)> and
// <uvm_component_registry #(T,Tname)> class are used to proxy <uvm_objects>
// and <uvm_components>.
//
// The factory provides both name-based and type-based interfaces.
//
// type-based - The type-based interface is far less prone to errors in usage.
//   When errors do occur, they are caught at compile-time.
//
// name-based - The name-based interface is dominated
//   by string arguments that can be misspelled and provided in the wrong order.
//   Errors in name-based requests might only be caught at the time of the call,
//   if at all. Further, the name-based interface is not portable across
//   simulators when used with parameterized classes.
//
//
// The ~uvm_factory~ is an abstract class which declares many of its methods
// as ~pure virtual~.  The UVM uses the <uvm_default_factory> class
// as its default factory implementation.
//
// See <uvm_default_factory::Usage> section for details on configuring and using the factory.
//

// @uvm-ieee 1800.2-2017 auto 8.3.1.1
abstract class uvm_factory
{
  static class uvm_once: uvm_once_base
  {
    @uvm_private_sync
    private bool _m_debug_pass;
  }

  mixin(uvm_once_sync_string);

  // Group -- NODOCS -- Retrieving the factory


         
  // @uvm-ieee 1800.2-2017 auto 8.3.1.2.1
  static  uvm_factory get() {
    import uvm.base.uvm_coreservice;
    uvm_coreservice_t s = uvm_coreservice_t.get();
    return s.get_factory();
  }


  // @uvm-ieee 1800.2-2017 auto 8.3.1.2.2
  static void set(uvm_factory f) {
    import uvm.base.uvm_coreservice;
    uvm_coreservice_t s = uvm_coreservice_t.get();
    s.set_factory(f);
  }

  // Group -- NODOCS -- Registering Types

  // Function -- NODOCS -- register
  //
  // Registers the given proxy object, ~obj~, with the factory. The proxy object
  // is a lightweight substitute for the component or object it represents. When
  // the factory needs to create an object of a given type, it calls the proxy's
  // create_object or create_component method to do so.
  //
  // When doing name-based operations, the factory calls the proxy's
  // ~get_type_name~ method to match against the ~requested_type_name~ argument in
  // subsequent calls to <create_component_by_name> and <create_object_by_name>.
  // If the proxy object's ~get_type_name~ method returns the empty string,
  // name-based lookup is effectively disabled.

  // @uvm-ieee 1800.2-2017 auto 8.3.1.3
  abstract void register(uvm_object_wrapper obj);


  // Group -- NODOCS -- Type & Instance Overrides

  // Function -- NODOCS -- set_inst_override_by_type

  // @uvm-ieee 1800.2-2017 auto 8.3.1.4.1
  abstract void set_inst_override_by_type(uvm_object_wrapper original_type,
					  uvm_object_wrapper override_type,
					  string full_inst_path);


  // Function -- NODOCS -- set_inst_override_by_name
  //
  // Configures the factory to create an object of the override's type whenever
  // a request is made to create an object of the original type using a context
  // that matches ~full_inst_path~. The original type is typically a super class
  // of the override type.
  //
  // When overriding by type, the ~original_type~ and ~override_type~ are
  // handles to the types' proxy objects. Preregistration is not required.
  //
  // When overriding by name, the ~original_type_name~ typically refers to a
  // preregistered type in the factory. It may, however, be any arbitrary
  // string. Future calls to any of the ~create_*~ methods with the same string
  // and matching instance path will produce the type represented by
  // ~override_type_name~, which must be preregistered with the factory.
  //
  // The ~full_inst_path~ is matched against the concatentation of
  // {~parent_inst_path~, ".", ~name~} provided in future create requests. The
  // ~full_inst_path~ may include wildcards (* and ?) such that a single
  // instance override can be applied in multiple contexts. A ~full_inst_path~
  // of "*" is effectively a type override, as it will match all contexts.
  //
  // When the factory processes instance overrides, the instance queue is
  // processed in order of override registrations, and the first override
  // match prevails. Thus, more specific overrides should be registered
  // first, followed by more general overrides.

  // @uvm-ieee 1800.2-2017 auto 8.3.1.4.1
  abstract void set_inst_override_by_name(string original_type_name,
					  string override_type_name,
					  string full_inst_path);


  // Function -- NODOCS -- set_type_override_by_type


  // @uvm-ieee 1800.2-2017 auto 8.3.1.4.2
  abstract void set_type_override_by_type(uvm_object_wrapper original_type,
					  uvm_object_wrapper override_type,
					  bool replace = true);


  // Function -- NODOCS -- set_type_override_by_name
  //
  // Configures the factory to create an object of the override's type whenever
  // a request is made to create an object of the original type, provided no
  // instance override applies. The original type is typically a super class of
  // the override type.
  //
  // When overriding by type, the ~original_type~ and ~override_type~ are
  // handles to the types' proxy objects. Preregistration is not required.
  //
  // When overriding by name, the ~original_type_name~ typically refers to a
  // preregistered type in the factory. It may, however, be any arbitrary
  // string. Future calls to any of the ~create_*~ methods with the same string
  // and matching instance path will produce the type represented by
  // ~override_type_name~, which must be preregistered with the factory.
  //
  // When ~replace~ is 1, a previous override on ~original_type_name~ is
  // replaced, otherwise a previous override, if any, remains intact.

  // set_type_override_by_name
  // -------------------------

  // @uvm-ieee 1800.2-2017 auto 8.3.1.4.2
  abstract void set_type_override_by_name(string original_type_name,
					  string override_type_name,
					  bool replace = true);


  // Group -- NODOCS -- Creation

  // Function -- NODOCS -- create_object_by_type

  // @uvm-ieee 1800.2-2017 auto 8.3.1.5
  abstract uvm_object create_object_by_type(uvm_object_wrapper requested_type,
					    string parent_inst_path="",
					    string name="");


  // Function -- NODOCS -- create_component_by_type

  // @uvm-ieee 1800.2-2017 auto 8.3.1.5
  abstract uvm_component create_component_by_type(uvm_object_wrapper requested_type,
						  string parent_inst_path,
						  string name,
						  uvm_component parent);

  // Function -- NODOCS -- create_object_by_name

  // @uvm-ieee 1800.2-2017 auto 8.3.1.5
  abstract uvm_object create_object_by_name(string requested_type_name,
					    string parent_inst_path="",
					    string name="");


  // Function: create_component_by_name
  //
  // Creates and returns a component or object of the requested type, which may
  // be specified by type or by name. A requested component must be derived
  // from the <uvm_component> base class, and a requested object must be derived
  // from the <uvm_object> base class.
  //
  // When requesting by type, the ~requested_type~ is a handle to the type's
  // proxy object. Preregistration is not required.
  //
  // When requesting by name, the ~request_type_name~ is a string representing
  // the requested type, which must have been registered with the factory with
  // that name prior to the request. If the factory does not recognize the
  // ~requested_type_name~, an error is produced and a ~null~ handle returned.
  //
  // If the optional ~parent_inst_path~ is provided, then the concatenation,
  // {~parent_inst_path~, ".",~name~}, forms an instance path (context) that
  // is used to search for an instance override. The ~parent_inst_path~ is
  // typically obtained by calling the <uvm_component::get_full_name> on the
  // parent.
  //
  // If no instance override is found, the factory then searches for a type
  // override.
  //
  // Once the final override is found, an instance of that component or object
  // is returned in place of the requested type. New components will have the
  // given ~name~ and ~parent~. New objects will have the given ~name~, if
  // provided.
  //
  // Override searches are recursively applied, with instance overrides taking
  // precedence over type overrides. If ~foo~ overrides ~bar~, and ~xyz~
  // overrides ~foo~, then a request for ~bar~ will produce ~xyz~. Recursive
  // loops will result in an error, in which case the type returned will be
  // that which formed the loop. Using the previous example, if ~bar~
  // overrides ~xyz~, then ~bar~ is returned after the error is issued.

  // @uvm-ieee 1800.2-2017 auto 8.3.1.5
  abstract uvm_component create_component_by_name(string requested_type_name,
						  string parent_inst_path,
						  string name,
						  uvm_component parent);


  // Group: Debug

  // Function -- NODOCS -- debug_create_by_type

  // debug_create_by_type
  // --------------------

  abstract void debug_create_by_type(uvm_object_wrapper requested_type,
				     string parent_inst_path="",
				     string name="");

  // Function -- NODOCS -- debug_create_by_name
  //
  // These methods perform the same search algorithm as the ~create_*~ methods,
  // but they do not create new objects. Instead, they provide detailed
  // information about what type of object it would return, listing each
  // override that was applied to arrive at the result. Interpretation of the
  // arguments are exactly as with the ~create_*~ methods.

  // debug_create_by_name
  // --------------------

  abstract void  debug_create_by_name(string requested_type_name,
				      string parent_inst_path="",
				      string name="");

  // Function -- NODOCS -- find_override_by_type

  // find_override_by_type
  // ---------------------

  // @uvm-ieee 1800.2-2017 auto 8.3.1.7.1
  abstract uvm_object_wrapper find_override_by_type(uvm_object_wrapper requested_type,
						    string full_inst_path);

  // Function -- NODOCS -- find_override_by_name
  //
  // These methods return the proxy to the object that would be created given
  // the arguments. The ~full_inst_path~ is typically derived from the parent's
  // instance path and the leaf name of the object to be created, i.e.
  // { parent.get_full_name(), ".", name }.

  // find_override_by_name
  // ---------------------

  // @uvm-ieee 1800.2-2017 auto 8.3.1.7.1
  abstract uvm_object_wrapper find_override_by_name(string requested_type_name,
						    string full_inst_path);


  // Function -- NODOCS -- find_wrapper_by_name
  //
  // This method returns the <uvm_object_wrapper> associated with a given
  // ~type_name~.

  // find_wrapper_by_name
  // ------------

  // @uvm-ieee 1800.2-2017 auto 8.3.1.7.2
  abstract uvm_object_wrapper find_wrapper_by_name(string type_name);


  // Function -- NODOCS -- print
  //
  // Prints the state of the uvm_factory, including registered types, instance
  // overrides, and type overrides.
  //
  // When ~all_types~ is 0, only type and instance overrides are displayed. When
  // ~all_types~ is 1 (default), all registered user-defined types are printed as
  // well, provided they have names associated with them. When ~all_types~ is 2,
  // the UVM types (prefixed with uvm_) are included in the list of registered
  // types.

  // print
  // -----

  // @uvm-ieee 1800.2-2017 auto 8.3.1.7.5
  abstract void print(int all_types=1);

}

//------------------------------------------------------------------------------
//
// CLASS -- NODOCS -- uvm_default_factory
//
//------------------------------------------------------------------------------
//
// Default implementation of the UVM factory.  The library implements the
// following public API beyond what is documented in IEEE 1800.2.
   
// @uvm-ieee 1800.2-2017 auto 8.3.3
class uvm_default_factory: uvm_factory
{

  mixin(uvm_sync_string);
  // Group -- NODOCS -- Registering Types

  // Function -- NODOCS -- register
  //
  // Registers the given proxy object, ~obj~, with the factory.

  override void register(uvm_object_wrapper obj) {
    import uvm.base.uvm_globals;
    import uvm.base.uvm_object_globals;
    synchronized(this) {
      if(obj is null) {
	uvm_report_fatal("NULLWR", "Attempting to register a null object" ~
			 " with the factory", uvm_verbosity.UVM_NONE);
      }
      if(obj.get_type_name() != "" && obj.get_type_name() != "<unknown>") {
	if(obj.get_type_name() in _m_type_names) {
	  uvm_report_warning("TPRGED", "Type name '" ~ obj.get_type_name() ~
			     "' already registered with factory. No " ~
			     "string-based lookup support for multiple" ~
			     " types with the same type name.", uvm_verbosity.UVM_NONE);
	}
	else {
	  _m_type_names[obj.get_type_name()] = obj;
	}
      }

      if(obj in _m_types) {
	if(obj.get_type_name() != "" && obj.get_type_name() != "<unknown>") {
	  uvm_report_warning("TPRGED", "Object type '" ~ obj.get_type_name() ~
			     "' already registered with factory. ", uvm_verbosity.UVM_NONE);
	}
      }
      else {
	uvm_factory_override[] overrides;
	_m_types[obj] = true;
	// If a named override happens before the type is registered, need to copy
	// the override queue.
	// Note:Registration occurs via static initialization, which occurs ahead of
	// procedural (e.g. initial) blocks. There should not be any preexisting overrides.
	if(obj.get_type_name() in _m_inst_override_name_queues) {
	  _m_inst_override_queues[obj] =
	    _m_inst_override_name_queues[obj.get_type_name()].clone();
	  _m_inst_override_name_queues.remove(obj.get_type_name());
	}
	if(_m_wildcard_inst_overrides.length != 0) {
	  if(obj !in _m_inst_override_queues) {
	    _m_inst_override_queues[obj] = new uvm_factory_queue_class;
	  }
	  foreach(inst_override; _m_wildcard_inst_overrides) {
	    if(uvm_is_match(inst_override.orig_type_name, obj.get_type_name())) {
	      _m_inst_override_queues[obj].push_back(inst_override);
	    }
	  }
	}
      }
    }
  }


  // Group -- NODOCS -- Type & Instance Overrides

  // Function -- NODOCS -- set_inst_override_by_type

  override void set_inst_override_by_type(uvm_object_wrapper original_type,
						uvm_object_wrapper override_type,
						string full_inst_path) {
    synchronized(this) {
      // register the types if not already done so
      if(original_type !in _m_types) {
	register(original_type);
      }

      if(override_type !in _m_types) {
	register(override_type);
      }

      if(check_inst_override_exists(original_type, override_type,
				    full_inst_path)) {
	return;
      }

      if(original_type !in _m_inst_override_queues) {
	_m_inst_override_queues[original_type] = new uvm_factory_queue_class;
      }

      uvm_factory_override ovrrd =
	new uvm_factory_override(full_inst_path, original_type.get_type_name(),
				 original_type, override_type);

      _m_inst_override_queues[original_type].push_back(ovrrd);
    }
  }

  // Function -- NODOCS -- set_inst_override_by_name
  //
  // Configures the factory to create an object of the override's type whenever
  // a request is made to create an object of the original type using a context
  // that matches ~full_inst_path~.
  // 
  // ~original_type_name~ may be the factory-registered type name or an aliased name
  // specified with <set_inst_alias> in the context of ~full_inst_path~.

  override void set_inst_override_by_name(string original_type_name,
						string override_type_name,
						string full_inst_path) {
    import uvm.base.uvm_globals;
    import uvm.base.uvm_object_globals;
    synchronized(this) {
      uvm_object_wrapper original_type;
      uvm_object_wrapper override_type;

      if(original_type_name in _m_type_names) {
	original_type = _m_type_names[original_type_name];
      }

      if(override_type_name in _m_type_names) {
	override_type = _m_type_names[override_type_name];
      }

      // check that type is registered with the factory
      if(override_type is null) {
	uvm_report_error("TYPNTF", "Cannot register instance override with" ~
			 " type name '" ~ original_type_name ~
			 "' and instance path '" ~ full_inst_path ~
			 "' because the type it's supposed " ~
			 "to produce ~  '" ~ override_type_name ~
			 "',  is not registered with the factory.", uvm_verbosity.UVM_NONE);
	return;
      }

      if(original_type is null) {
	_m_lookup_strs[original_type_name] = true;
      }

      uvm_factory_override ovrrd
	= new uvm_factory_override(full_inst_path, original_type_name,
				   original_type, override_type);

      if(original_type !is null) {
	if(check_inst_override_exists(original_type, override_type,
				      full_inst_path)) {
	  return;
	}
	if(original_type !in _m_inst_override_queues) {
	  _m_inst_override_queues[original_type] =
	    new uvm_factory_queue_class;
	}
	_m_inst_override_queues[original_type].push_back(ovrrd);
      }
      else {
	if(m_has_wildcard(original_type_name)) {
	  foreach(i, type_name; _m_type_names) {
	    if(uvm_is_match(original_type_name, i)) {
	      this.set_inst_override_by_name(i, override_type_name,
					     full_inst_path);
	    }
	  }
	  _m_wildcard_inst_overrides ~= ovrrd;
	}
	else {
	  if(original_type_name !in _m_inst_override_name_queues) {
	    _m_inst_override_name_queues[original_type_name] =
	      new uvm_factory_queue_class;
	  }
	  _m_inst_override_name_queues[original_type_name].push_back(ovrrd);
	}
      }
    }
  }



  // Function -- NODOCS -- set_type_override_by_type

  override void set_type_override_by_type(uvm_object_wrapper original_type,
						uvm_object_wrapper override_type,
						bool replace = true) {
    import uvm.base.uvm_globals;
    import uvm.base.uvm_object_globals;
    synchronized(this) {
      bool replaced = false;

      // check that old and new are not the same
      if(original_type is override_type) {
	if(original_type.get_type_name() == "" ||
	   original_type.get_type_name() == "<unknown>") {
	  uvm_report_warning("TYPDUP", "Original and override type " ~
			     "arguments are identical", uvm_verbosity.UVM_NONE);
	}
	else {
	  uvm_report_warning("TYPDUP", "Original and override type " ~
			     "arguments are identical: " ~
			     original_type.get_type_name(), uvm_verbosity.UVM_NONE);
	}
      }

      // register the types if not already done so, for the benefit of string-based lookup
      if(original_type !in _m_types) {
	register(original_type);
      }

      if(override_type !in _m_types) {
	register(override_type);
      }

      // check for existing type override
      foreach(index, type_override; _m_type_overrides) {
	synchronized(type_override) {
	  if(type_override.orig_type is original_type ||
	     (type_override.orig_type_name != "<unknown>" &&
	      type_override.orig_type_name != "" &&
	      type_override.orig_type_name == original_type.get_type_name())) {
	    string msg =
	      "Original object type '" ~ original_type.get_type_name() ~
	      "' already registered to produce '" ~
	      type_override.ovrd_type_name ~ "'";
	    if(!replace) {
	      msg ~= ".  Set 'replace' argument to replace the existing entry.";
	      uvm_report_info("TPREGD", msg, uvm_verbosity.UVM_MEDIUM);
	      return;
	    }
	    msg ~= ".  Replacing with override to produce type '" ~
	      override_type.get_type_name() ~ "'.";
	    uvm_report_info("TPREGR", msg, uvm_verbosity.UVM_MEDIUM);
	    replaced = true;
	    type_override.orig_type = original_type;
	    type_override.orig_type_name = original_type.get_type_name();
	    type_override.ovrd_type = override_type;
	    type_override.ovrd_type_name = override_type.get_type_name();
	  }
	}
      }

      // make a new entry
      if(!replaced) {
	auto ovrrd = new uvm_factory_override("*",
					      original_type.get_type_name(),
					      original_type, override_type);

	_m_type_overrides ~= ovrrd;
      }
    }
  }


  // Function -- NODOCS -- set_type_override_by_name
  //
  // Configures the factory to create an object of the override's type whenever
  // a request is made to create an object of the original type, provided no
  // instance override applies.
  //
  // ~original_type_name~ may be the factory-registered type name or an aliased name
  // specified with <set_type_alias>.

  override void set_type_override_by_name(string original_type_name,
					  string override_type_name,
					  bool replace = true) {
    import uvm.base.uvm_globals;
    import uvm.base.uvm_object_globals;
    synchronized(this) {
      bool replaced = false;

      uvm_object_wrapper original_type;
      uvm_object_wrapper override_type;

      if(original_type_name in _m_type_names) {
	original_type = _m_type_names[original_type_name];
      }

      if(override_type_name in _m_type_names) {
	override_type = _m_type_names[override_type_name];
      }

      // check that type is registered with the factory
      if(override_type is null) {
	uvm_report_error("TYPNTF",
			 "Cannot register override for original type '" ~
			 original_type_name ~ "' because the override type '" ~
			 override_type_name ~
			 "' is not registered with the factory.", uvm_verbosity.UVM_NONE);
	return;
      }

      // check that old and new are not the same
      if(original_type_name == override_type_name) {
	uvm_report_warning("TYPDUP", "Requested and actual type name " ~
			   " arguments are identical: " ~ original_type_name ~
			   ". Ignoring this override.", uvm_verbosity.UVM_NONE);
	return;
      }

      foreach(index, type_override; _m_type_overrides) {
	if(type_override.orig_type_name == original_type_name) {
	  if(!replace) {
	    uvm_report_info("TPREGD", "Original type '" ~ original_type_name ~
			    "' already registered to produce '" ~
			    type_override.ovrd_type_name ~
			    "'.  Set 'replace' argument to replace the " ~
			    "existing entry.", uvm_verbosity.UVM_MEDIUM);
	    return;
	  }
	  uvm_report_info("TPREGR", "Original object type '" ~
			  original_type_name ~
			  "' already registered to produce '" ~
			  type_override.ovrd_type_name ~
			  "'.  Replacing with override to produce type '" ~
			  override_type_name ~ "'.", uvm_verbosity.UVM_MEDIUM);
	  replaced = true;
	  type_override.ovrd_type = override_type;
	  type_override.ovrd_type_name = override_type_name;
	}
      }

      if(original_type is null) {
	_m_lookup_strs[original_type_name] = true;
      }

      if(!replaced) {
	auto ovrrd = new uvm_factory_override("*", original_type_name,
					      original_type, override_type);

	_m_type_overrides ~= ovrrd;
	//    _m_type_names[original_type_name] = override.ovrd_type;
      }

    }
  }



  // Group -- NODOCS -- Creation

  // Function -- NODOCS -- create_object_by_type

  override uvm_object create_object_by_type(uvm_object_wrapper requested_type,
					    string parent_inst_path="",
					    string name="") {
    synchronized(this) {

      string full_inst_path;

      if(parent_inst_path == "") {
	full_inst_path = name;
      }
      else if(name != "") {
	full_inst_path = parent_inst_path ~ "." ~ name;
      }
      else {
	full_inst_path = parent_inst_path;
      }

      _m_override_info.length = 0;

      requested_type = find_override_by_type(requested_type, full_inst_path);

      return requested_type.create_object(name);

    }
  }

  // Function -- NODOCS -- create_component_by_type


  override uvm_component create_component_by_type(uvm_object_wrapper requested_type,
						  string parent_inst_path,
						  string name,
						  uvm_component parent) {
    synchronized(this) {
      string full_inst_path;

      if(parent_inst_path == "") {
	full_inst_path = name;
      }
      else if(name != "") {
	full_inst_path = parent_inst_path ~ "." ~ name;
      }
      else {
	full_inst_path = parent_inst_path;
      }

      _m_override_info.length = 0;

      requested_type = find_override_by_type(requested_type, full_inst_path);

      return requested_type.create_component(name, parent);

    }
  }

  // Function -- NODOCS -- create_object_by_name

  override uvm_object create_object_by_name(string requested_type_name,
					    string parent_inst_path="",
					    string name="") {
    import uvm.base.uvm_globals;
    import uvm.base.uvm_object_globals;
    synchronized(this) {
      uvm_object_wrapper wrapper;
      string inst_path;

      if(parent_inst_path == "") {
	inst_path = name;
      }
      else if(name != "") {
	inst_path = parent_inst_path ~ "." ~ name;
      }
      else {
	inst_path = parent_inst_path;
      }

      _m_override_info.length = 0;

      wrapper = find_override_by_name(requested_type_name, inst_path);

      // if no override exists, try to use requested_type_name directly
      if(wrapper is null) {
	if(requested_type_name !in _m_type_names) {
	  // return null;

	  // SV works via static initialization -- In Vlang we do not
	  // have that option since we create uvm_root dynamically
	  // For VLang we have a special recourse == We invoke the
	  // Object.factory
	  auto obj = Object.factory(requested_type_name);
	  if(obj is null) {
	    uvm_report_warning("BDTYP", "Cannot create an object of type '" ~
			       requested_type_name ~
			       "' because it is not registered with the factory.",
			       uvm_verbosity.UVM_NONE);

	    uvm_report_warning("BDTYP", "Object.factory Cannot create an " ~
			       "object of type '" ~ requested_type_name ~ "'.",
			       uvm_verbosity.UVM_NONE);
	    return null;
	  }
	  else {
	    auto uobj = cast(uvm_object) obj;
	    if(uobj is null) {
	      uvm_report_warning("BDTYP", "Object.factory created an object " ~
				 "but could not cast it to uvm_object type '" ~
				 requested_type_name ~ "'.",
				 uvm_verbosity.UVM_NONE);
	    }
	    uobj.set_name(name);
	    return uobj;
	  }
	}
	wrapper = _m_type_names[requested_type_name];
      }

      return wrapper.create_object(name);

    }
  }

  // Function -- NODOCS -- create_component_by_name
  //
  // Creates and returns a component or object of the requested type, which may
  // be specified by type or by name.

  override uvm_component create_component_by_name(string requested_type_name,
						  string parent_inst_path,
						  string name,
						  uvm_component parent) {
    import uvm.base.uvm_globals;
    import uvm.base.uvm_object_globals;
    synchronized(this) {
      uvm_object_wrapper wrapper;
      string inst_path;

      if(parent_inst_path == "") {
	inst_path = name;
      }
      else if(name != "") {
	inst_path = parent_inst_path ~ "." ~ name;
      }
      else {
	inst_path = parent_inst_path;
      }

      _m_override_info.length = 0;

      wrapper = find_override_by_name(requested_type_name, inst_path);

      // if no override exists, try to use requested_type_name directly
      if(wrapper is null) {
	if(requested_type_name !in _m_type_names) {
	  // return null;

	  // SV works via static initialization -- In Vlang we do not
	  // have that option since we create uvm_root dynamically
	  // For VLang we have a special recourse == Try to invoke the
	  // Object.factory
	  auto comp = Object.factory(requested_type_name);
	  if(comp is null) {
	    uvm_report_warning("BDTYP", "Cannot create a component of type '" ~
			       requested_type_name ~
			       "' because it is not registered with the factory.",
			       uvm_verbosity.UVM_NONE);
	    uvm_report_warning("BDTYP", "Object.factory Cannot create an " ~
			       "object of type '" ~ requested_type_name ~ "'.",
			       uvm_verbosity.UVM_NONE);
	    return null;
	  }
	  else {
	    auto ucomp = cast(uvm_component) comp;
	    if(ucomp is null) {
	      uvm_report_warning("BDTYP", "Object.factory created an " ~
				 "object but could not cast it to " ~
				 "uvm_component type '" ~
				 requested_type_name ~ "'.",
				 uvm_verbosity.UVM_NONE);
	    }
	    ucomp._set_name_force(name);
	    return ucomp;
	  }
	}
	wrapper = _m_type_names[requested_type_name];
      }

      return wrapper.create_component(name, parent);

    }
  }

  // Group: Debug

  // Function: debug_create_by_type
  // Debug traces for ~create_*_by_type~ methods.
  //
  // This method performs the same search algorithm as the <create_object_by_type> and
  // <create_component_by_type> methods, however instead of creating the new object or component,
  // the method shall generate a report message detailing how the object or component would
  // have been constructed after all overrides are accounted for.
  //
  // @uvm-accellera The details of this API are specific to the Accellera implementation, and are not being considered for contribution to 1800.2
  override void debug_create_by_type(uvm_object_wrapper requested_type,
				     string parent_inst_path="",
				     string name="") {
    m_debug_create("", requested_type, parent_inst_path, name);
  }

  // Function: debug_create_by_name
  // Debug traces for ~create_*_by_name~ methods.
  //
  // This method performs the same search algorithm as the <create_object_by_name> and
  // <create_component_by_name> methods, however instead of creating the new object or component,
  // the method shall generate a report message detailing how the object or component would
  // have been constructed after all overrides are accounted for.
  //
  // @uvm-accellera The details of this API are specific to the Accellera implementation, and are not being considered for contribution to 1800.2

  override void  debug_create_by_name(string requested_type_name,
				      string parent_inst_path="",
				      string name="") {
    m_debug_create(requested_type_name, null, parent_inst_path, name);
  }


  // Function -- NODOCS -- find_override_by_type

  override uvm_object_wrapper find_override_by_type(uvm_object_wrapper requested_type,
						    string full_inst_path) {
    import uvm.base.uvm_globals;
    import uvm.base.uvm_object_globals;
    synchronized(this) {
      uvm_object_wrapper ovrrd;
      uvm_factory_override lindex;

      uvm_factory_queue_class qc =
	(requested_type in _m_inst_override_queues) ?
	_m_inst_override_queues[requested_type] : null;

      foreach(index, override_info; _m_override_info) {
	if( //index !is _m_override_info.size()-1 &&
	   override_info.orig_type is requested_type) {
	  uvm_report_error("OVRDLOOP",
			   "Recursive loop detected while finding override.",
			   uvm_verbosity.UVM_NONE);
	  if(!m_debug_pass) {
	    debug_create_by_type(requested_type, full_inst_path);
	  }
	  override_info.mark_used();
	  return requested_type;
	}
      }

      // inst override; return first match; takes precedence over type overrides
      if(full_inst_path != "" && qc !is null) {
	// for(int index = 0; index < qc.length; ++index) {
	foreach(qovrrd; qc) {
	  if((qovrrd.orig_type is requested_type ||
	      (qovrrd.orig_type_name != "<unknown>" &&
	       qovrrd.orig_type_name != "" &&
	       qovrrd.orig_type_name == requested_type.get_type_name())) &&
	     uvm_is_match(qovrrd.full_inst_path, full_inst_path)) {
	    _m_override_info ~= qovrrd;
	    if(m_debug_pass) {
	      if(ovrrd is null) {
		ovrrd = qovrrd.ovrd_type;
		qovrrd.selected = true;
		lindex = qovrrd;
	      }
	    }
	    else {
	      qovrrd.mark_used();
	      if(qovrrd.ovrd_type is requested_type) {
		return requested_type;
	      }
	      else {
		return find_override_by_type(qovrrd.ovrd_type, full_inst_path);
	      }
	    }
	  }
	}
      }

      // type override - exact match
      foreach(index, type_override; _m_type_overrides) {
	if(type_override.orig_type is requested_type ||
	   (type_override.orig_type_name != "<unknown>" &&
	    type_override.orig_type_name != "" &&
	    requested_type !is null &&
	    type_override.orig_type_name == requested_type.get_type_name())) {
	  _m_override_info ~= type_override;
	  if(m_debug_pass) {
	    if(ovrrd is null) {
	      ovrrd = type_override.ovrd_type;
	      type_override.selected = true;
	      lindex = type_override;
	    }
	  }
	  else {
	    type_override.mark_used();
	    if(type_override.ovrd_type is requested_type) {
	      return requested_type;
	    }
	    else {
	      return find_override_by_type(type_override.ovrd_type,
					   full_inst_path);
	    }
	  }
	}
      }

      // type override with wildcard match
      //foreach(_m_type_overrides[index])
      //  if(uvm_is_match(index,requested_type.get_type_name())) {
      //    _m_override_info.pushBack(m_inst_overrides[index]);
      //    return find_override_by_type(_m_type_overrides[index],full_inst_path);
      //  }

      if(m_debug_pass && ovrrd !is null) {
	lindex.mark_used();
	if(ovrrd is requested_type) {
	  return requested_type;
	}
	else {
	  return find_override_by_type(ovrrd, full_inst_path);
	}
      }
      return requested_type;

    }
  }

  // Function -- NODOCS -- find_override_by_name
  //
  // These methods return the proxy to the object that would be created given
  // the arguments.

  override uvm_object_wrapper find_override_by_name(string requested_type_name,
						    string full_inst_path) {
    import uvm.base.uvm_globals;
    import uvm.base.uvm_object_globals;
    synchronized(this) {
      uvm_object_wrapper rtype;
      uvm_factory_queue_class qc;
      uvm_factory_override lindex;

      uvm_object_wrapper ovrrd;

      if(requested_type_name in _m_type_names) {
	rtype = _m_type_names[requested_type_name];
      }

      /***
	  if(rtype is null) {
	  if(requested_type_name != "") {
	  uvm_report_warning("TYPNTF", {"Requested type name ",
	  requested_type_name, " is not registered with the factory. The instance override to ",
	  full_inst_path, " is ignored"}, uvm_verbosity.UVM_NONE);
	  }
	  _m_lookup_strs[requested_type_name] = true;
	  return null;
	  }
      ***/

      if(full_inst_path != "") {
	if(rtype is null) {
	  if(requested_type_name in _m_inst_override_name_queues) {
	    qc = _m_inst_override_name_queues[requested_type_name];
	  }
	}
	else {
	  if(rtype in _m_inst_override_queues) {
	    qc = _m_inst_override_queues[rtype];
	  }
	}
	if(qc !is null) {
	  foreach(index, qovrrd; qc) {
	    // for(int index = 0; index<qc.length; ++index) {
	    if(uvm_is_match(qovrrd.orig_type_name, requested_type_name) &&
	       uvm_is_match(qovrrd.full_inst_path, full_inst_path)) {
	      _m_override_info ~= qovrrd;
	      if(m_debug_pass) {
		if(ovrrd is null) {
		  ovrrd = qovrrd.ovrd_type;
		  qovrrd.selected = true;
		  lindex = qovrrd;
		}
	      }
	      else {
		qovrrd.mark_used();
		if(qovrrd.ovrd_type.get_type_name() == requested_type_name) {
		  return qovrrd.ovrd_type;
		}
		else {
		  return find_override_by_type(qovrrd.ovrd_type,
					       full_inst_path);
		}
	      }
	    }
	  }
	}
      }

      if(rtype !is null &&
	 (rtype !in _m_inst_override_queues) &&
	 _m_wildcard_inst_overrides.length != 0) {
	_m_inst_override_queues[rtype] = new uvm_factory_queue_class;
	foreach(i, inst_override; _m_wildcard_inst_overrides) {
	  if(uvm_is_match(inst_override.orig_type_name, requested_type_name))
	    _m_inst_override_queues[rtype].push_back(inst_override);
	}
      }

      // type override - exact match
      foreach(index, type_override; _m_type_overrides) {
	if(type_override.orig_type_name == requested_type_name) {
	  _m_override_info ~= type_override;
	  if(m_debug_pass) {
	    if(ovrrd is null) {
	      ovrrd = type_override.ovrd_type;
	      type_override.selected = true;
	      lindex = type_override;
	    }
	  }
	  else {
	    type_override.mark_used();
	    return find_override_by_type(type_override.ovrd_type,
					 full_inst_path);
	  }
	}
      }

      if(m_debug_pass && ovrrd !is null) {
	lindex.mark_used();
	return find_override_by_type(ovrrd, full_inst_path);
      }

      // No override found
      return null;

    }
  }

  override uvm_object_wrapper find_wrapper_by_name(string type_name) {
    import uvm.base.uvm_globals;
    import uvm.base.uvm_object_globals;
    synchronized(this) {
      if(type_name in _m_type_names) {
	return _m_type_names[type_name];
      }

      uvm_report_warning("UnknownTypeName",
			 "find_wrapper_by_name: Type name '" ~ type_name ~
			 "' not registered with the factory.", uvm_verbosity.UVM_NONE);
      return null;
    }
  }

  // Function -- NODOCS -- print
  //
  // Prints the state of the uvm_factory, including registered types, instance
  // overrides, and type overrides.
  //

  override void print(int all_types=1) {
    import uvm.base.uvm_globals;
    import uvm.base.uvm_object_globals;
    synchronized(this) {
      uvm_factory_queue_class[string] sorted_override_queues;

      string qs;

      int id = 0;

      //sort the override queues
      foreach(obj, override_queue; _m_inst_override_queues) {
	string tmp = obj.get_type_name();
	if(tmp == "") {
	  tmp = format("__unnamed_id_%0d", id++);
	}
	sorted_override_queues[tmp] = override_queue;

      }
      foreach(i, override_name_queue; _m_inst_override_name_queues) {
	sorted_override_queues[i] = override_name_queue;
      }

      qs ~= "\n#### Factory Configuration (*)\n\n";

      // print instance overrides
      if(_m_type_overrides.length is 0 && sorted_override_queues.length is 0) {
	qs ~= "  No instance or type overrides are registered with this factory\n";
      }
      else {
	size_t max1,max2,max3;
	string dash = "---------------------------------------------------------------------------------------------------";
	string space= "                                                                                                   ";

	// print instance overrides
	if(sorted_override_queues.length is 0) {
	  qs ~= "No instance overrides are registered with this factory\n";
	}
	else {
	  foreach(j, qc; sorted_override_queues) {
	    foreach(i, qovrrd; qc) { // for(int i=0; i<qc.length; ++i) {
	      if(qovrrd.orig_type_name.length > max1) {
		max1 = qovrrd.orig_type_name.length;
	      }
	      if(qovrrd.full_inst_path.length > max2) {
		max2 = qovrrd.full_inst_path.length;
	      }
	      if(qovrrd.ovrd_type_name.length > max3) {
		max3 = qovrrd.ovrd_type_name.length;
	      }
	    }
	  }
	  if(max1 < 14) {
	    max1 = 14;
	  }
	  if(max2 < 13) {
	    max2 = 13;
	  }
	  if(max3 < 13) {
	    max3 = 13;
	  }

	  qs ~= "Instance Overrides:\n\n";
	  qs ~= format("  %0s%0s  %0s%0s  %0s%0s\n",
		       "Requested Type", space[1..max1-13],
		       "Override Path", space[1..max2-12],
		       "Override Type", space[1..max3-12]);
	  qs ~= format("  %0s  %0s  %0s\n", dash[1..max1+1],
		       dash[1..max2+1],
		       dash[1..max3+1]);

	  foreach(j, qc; sorted_override_queues) {
	    foreach(i, qovrrd; qc) { // for(int i=0; i<qc.length; ++i) {
	      qs ~= format("  %0s%0s  %0s%0s", qovrrd.orig_type_name,
			   space[0..max1-qovrrd.orig_type_name.length],
			   qovrrd.full_inst_path,
			   space[0..max2-qovrrd.full_inst_path.length]);
	      qs ~= format("  %0s\n",     qovrrd.ovrd_type_name);
	    }
	  }
	}

	// print type overrides
	if(_m_type_overrides.length is 0) {
	  qs ~= "\nNo type overrides are registered with this factory\n";
	}
	else {
	  // Resize for type overrides
	  if(max1 < 14) max1 = 14;
	  if(max2 < 13) max2 = 13;
	  if(max3 < 13) max3 = 13;

	  foreach(i, type_override; _m_type_overrides) {
	    if(type_override.orig_type_name.length > max1) {
	      max1=type_override.orig_type_name.length;
	    }
	    if(type_override.ovrd_type_name.length > max2) {
	      max2=type_override.ovrd_type_name.length;
	    }
	  }
	  if(max1 < 14) {
	    max1 = 14;
	  }
	  if(max2 < 13) {
	    max2 = 13;
	  }
	  qs ~= "\nType Overrides:\n\n";
	  qs ~= format("  %0s%0s  %0s%0s\n",
		       "Requested Type",space[0..max1-14],
		       "Override Type", space[0..max2-13]);
	  qs ~= format("  %0s  %0s\n",
		       dash[0..max1],
		       dash[0..max2]);
	  foreach(index, type_override; _m_type_overrides) {
	    qs ~= format("  %0s%0s  %0s\n",
			 type_override.orig_type_name,
			 space[0..max1-type_override.orig_type_name.length],
			 type_override.ovrd_type_name);
	  }
	}
      }

      // print all registered types, if all_types >= 1
      if(all_types >= 1 && _m_type_names.length != 0) {
	bool banner;
	qs ~= format("\nAll types registered with the factory: %0d total\n",
		     _m_types.length);
	foreach(key, type_name; _m_type_names) {
	  // filter out uvm_ classes (if all_types<2) and non-types (lookup strings)
	  if(!(all_types < 2 &&
	       uvm_is_match("uvm_*",	type_name.get_type_name())) &&
	     key == type_name.get_type_name()) {
	    if(!banner) {
	      qs ~= "  Type Name\n";
	      qs ~= "  ---------\n";
	      banner = true;
	    }
	    qs ~= format("  %s\n", type_name.get_type_name());
	  }
	}
      }

      qs ~= "(*) Types with no associated type name will be printed" ~
	" as <unknown>\n\n####\n\n";

      uvm_info("UVM/FACTORY/PRINT", qs, uvm_verbosity.UVM_NONE);

    }
  }

  //----------------------------------------------------------------------------
  // PRIVATE MEMBERS

  // m_debug_create
  // --------------

  protected void  m_debug_create(string requested_type_name,
				 uvm_object_wrapper requested_type,
				 string parent_inst_path,
				 string name) {
    import uvm.base.uvm_globals;
    import uvm.base.uvm_object_globals;
    synchronized(this) {
      string full_inst_path;
      uvm_object_wrapper result;

      if(parent_inst_path == "") {
	full_inst_path = name;
      }
      else if(name != "") {
	full_inst_path = parent_inst_path ~ "." ~ name;
      }
      else {
	full_inst_path = parent_inst_path;
      }

      _m_override_info.length = 0;

      if(requested_type is null) {
	if(requested_type_name !in _m_type_names &&
	   requested_type_name !in _m_lookup_strs) {
	  uvm_report_warning("Factory Warning",
			     "The factory does not recognize '" ~
			     requested_type_name ~
			     "' as a registered type.", uvm_verbosity.UVM_NONE);
	  return;
	}
	m_debug_pass = true;

	result = find_override_by_name(requested_type_name, full_inst_path);
      }
      else {
	m_debug_pass = true;
	if(requested_type !in _m_types) {
	  register(requested_type);
	}
	result = find_override_by_type(requested_type, full_inst_path);
	if(requested_type_name == "") {
	  requested_type_name = requested_type.get_type_name();
	}
      }

      m_debug_display(requested_type_name, result, full_inst_path);
      m_debug_pass = false;

      foreach(index, override_info; _m_override_info) {
	override_info.selected = false;
      }
    }
  }


  // m_debug_display
  // ---------------

  protected void  m_debug_display(string requested_type_name,
				  uvm_object_wrapper result,
				  string full_inst_path) {
    import uvm.base.uvm_globals;
    import uvm.base.uvm_object_globals;
    synchronized(this) {

      size_t    max1,max2,max3;
      string dash  = "---------------------------------------------------------" ~
	"------------------------------------------";
      string space = "                                                         " ~
	"                                          ";

      string qs;

      qs ~= "\n#### Factory Override Information (*)\n\n";
      qs ~= format("Given a request for an object of type '%s' with an " ~
		   "instance\npath of '%s', the factory encountered\n\n",
		   requested_type_name, full_inst_path);

      if(_m_override_info.length is 0) {
	qs ~= "no relevant overrides.\n\n";
      }
      else {

	qs ~= "the following relevant overrides. An 'x' next to a match" ~
	  " indicates a\nmatch that was ignored.\n\n";

	foreach(i, override_info; _m_override_info) {
	  if(override_info.orig_type_name.length > max1) {
	    max1=override_info.orig_type_name.length;
	  }
	  if(override_info.full_inst_path.length > max2) {
	    max2=override_info.full_inst_path.length;
	  }
	  if(override_info.ovrd_type_name.length > max3) {
	    max3=override_info.ovrd_type_name.length;
	  }
	}

	if(max1 < 13) {
	  max1 = 13;
	}
	if(max2 < 13) {
	  max2 = 13;
	}
	if(max3 < 13) {
	  max3 = 13;
	}

	qs ~= format("  Original Type%0s  Instance Path%0s  Override Type%0s\n",
		     space[0..max1-13], space[0..max2-13], space[0..max3-13]);

	qs ~= format("  %0s  %0s  %0s\n",
		     dash[0..max1], dash[0..max2], dash[0..max3]);

	foreach(i, override_info; _m_override_info) {
	  qs ~= format("%s%0s%0s\n",
		       override_info.selected ? "  " : "x ",
		       override_info.orig_type_name,
		       space[0..max1-override_info.orig_type_name.length]);
	  qs ~= format("  %0s%0s", override_info.full_inst_path,
		       space[0..max2-override_info.full_inst_path.length]);
	  qs ~= format("  %0s%0s", override_info.ovrd_type_name,
		       space[0..max3-override_info.ovrd_type_name.length]);
	  if(override_info.full_inst_path == "*") {
	    qs ~= "  <type override>";
	  }
	  else {
	    qs ~= "\n";
	  }
	}
	qs ~= "\n";
      }


      qs ~= "Result:\n\n";
      qs ~= format("  The factory will produce an object of type '%0s'\n",
		   result is null ? requested_type_name : result.get_type_name());

      qs ~= "\n(*) Types with no associated type name will be printed as <unknown>\n\n####\n\n";

      uvm_info("UVM/FACTORY/DUMP", qs, uvm_verbosity.UVM_NONE);
    }
  }


  private bool[uvm_object_wrapper]      _m_types;
  private bool[string]                  _m_lookup_strs;
  private uvm_object_wrapper[string]    _m_type_names;

  private uvm_factory_override[]  _m_type_overrides;

  uvm_factory_override[] m_type_overrides() {
    synchronized(this) {
      return _m_type_overrides.dup();
    }
  }

  private uvm_factory_queue_class[uvm_object_wrapper] _m_inst_override_queues;

  uvm_factory_queue_class[uvm_object_wrapper] m_inst_override_queues() {
    synchronized(this) {
      return _m_inst_override_queues.dup();
    }
  }
  
  private uvm_factory_queue_class[string]             _m_inst_override_name_queues;

  uvm_factory_queue_class[string] m_inst_override_name_queues() {
    synchronized(this) {
      return _m_inst_override_name_queues.dup();
    }
  }
  
  private uvm_factory_override[]                _m_wildcard_inst_overrides;
  private uvm_factory_override[]                _m_override_info;

  static bool m_has_wildcard(string nm) {
    foreach(i, n_; nm) {
      if(n_ == '*' || n_ == '?') return true;
    }
    return false;
  }


  // check_inst_override_exists
  // --------------------------
  bool check_inst_override_exists(uvm_object_wrapper original_type,
				  uvm_object_wrapper override_type,
				  string full_inst_path) {
    import uvm.base.uvm_globals;
    import uvm.base.uvm_object_globals;
    synchronized(this) {
      uvm_factory_override ovrrd;
      uvm_factory_queue_class qc;

      if(original_type in _m_inst_override_queues) {
	qc = _m_inst_override_queues[original_type];
      }
      else {
	return false;
      }

      foreach(index, qovrrd; qc) {
	// for(int index=0; index < qc.length; ++index) {
	if(qovrrd.full_inst_path == full_inst_path &&
	   qovrrd.orig_type is original_type &&
	   qovrrd.ovrd_type is override_type &&
	   qovrrd.orig_type_name == original_type.get_type_name()) {
	  uvm_report_info("DUPOVRD", "Instance override for '" ~
			  original_type.get_type_name() ~
			  "' already exists: override type '" ~
			  override_type.get_type_name() ~
			  "' with full_inst_path '" ~
			  full_inst_path ~ "'", uvm_verbosity.UVM_HIGH);
	  return true;
	}
      }
      return false;
    }
  }
}

//------------------------------------------------------------------------------
//
// Group -- NODOCS -- Usage
//
// Using the factory involves three basic operations
//
// 1 - Registering objects and components types with the factory
// 2 - Designing components to use the factory to create objects or components
// 3 - Configuring the factory with type and instance overrides, both within and
//     outside components
//
// We'll briefly cover each of these steps here. More reference information can
// be found at <Utility Macros>, <uvm_component_registry #(T,Tname)>,
// <uvm_object_registry #(T,Tname)>, <uvm_component>.
//
// 1 -- Registering objects and component types with the factory:
//
// When defining <uvm_object> and <uvm_component>-based classes, simply invoke
// the appropriate macro. Use of macros are required to ensure portability
// across different vendors' simulators.
//
// Objects that are not parameterized are declared as
//
//|  class packet extends uvm_object;
//|    `uvm_object_utils(packet)
//|  endclass
//|
//|  class packetD extends packet;
//|    `uvm_object_utils(packetD)
//|  endclass
//
// Objects that are parameterized are declared as
//
//|  class packet #(type T=int, int WIDTH=32) extends uvm_object;
//|    `uvm_object_param_utils(packet #(T,WIDTH))
//|   endclass
//
// Components that are not parameterized are declared as
//
//|  class comp extends uvm_component;
//|    `uvm_component_utils(comp)
//|  endclass
//
// Components that are parameterized are declared as
//
//|  class comp #(type T=int, int WIDTH=32) extends uvm_component;
//|    `uvm_component_param_utils(comp #(T,WIDTH))
//|  endclass
//
// The `uvm_*_utils macros for simple, non-parameterized classes will register
// the type with the factory and define the get_type, get_type_name, and create
// virtual methods inherited from <uvm_object>. It will also define a static
// type_name variable in the class, which will allow you to determine the type
// without having to allocate an instance.
//
// The `uvm_*_param_utils macros for parameterized classes differ from
// `uvm_*_utils classes in the following ways:
//
// - The ~get_type_name~ method and static type_name variable are not defined. You
//   will need to implement these manually.
//
// - A type name is not associated with the type when registering with the
//   factory, so the factory's *_by_name operations will not work with
//   parameterized classes.
//
// - The factory's <print>, <debug_create_by_type>, and <debug_create_by_name>
//   methods, which depend on type names to convey information, will list
//   parameterized types as '<unknown>'.
//
// It is worth noting that environments that exclusively use the type-based
// factory methods (*_by_type) do not require type registration. The factory's
// type-based methods will register the types involved "on the fly," when first
// used. However, registering with the `uvm_*_utils macros enables name-based
// factory usage and implements some useful utility functions.
//
//
// 2 -- Designing components that defer creation to the factory:
//
// Having registered your objects and components with the factory, you can now
// make requests for new objects and components via the factory. Using the factory
// instead of allocating them directly (via new) allows different objects to be
// substituted for the original without modifying the requesting class. The
// following code defines a driver class that is parameterized.
//
//|  class driverB #(type T=uvm_object) extends uvm_driver;
//|
//|    // parameterized classes must use the _param_utils version
//|    `uvm_component_param_utils(driverB #(T))
//|
//|    // our packet type; this can be overridden via the factory
//|    T pkt;
//|
//|    // standard component constructor
//|    function new(string name, uvm_component parent=null);
//|      super.new(name,parent);
//|    endfunction
//|
//|    // get_type_name not implemented by macro for parameterized classes
//|    static function string type_name();
//|      return {"driverB #(",T::type_name(),")"};
//|    endfunction : type_name
//|    virtual function string get_type_name();
//|      return type_name();
//|    endfunction
//|
//|    // using the factory allows pkt overrides from outside the class
//|    virtual function void build_phase(uvm_phase phase);
//|      pkt = packet::type_id::create("pkt",this);
//|    endfunction
//|
//|    // print the packet so we can confirm its type when printing
//|    virtual function void do_print(uvm_printer printer);
//|      printer.print_object("pkt",pkt);
//|    endfunction
//|
//|  endclass
//
// For purposes of illustrating type and instance overrides, we define two
// subtypes of the ~driverB~ class. The subtypes are also parameterized, so
// we must again provide an implementation for <uvm_object::get_type_name>,
// which we recommend writing in terms of a static string constant.
//
//|  class driverD1 #(type T=uvm_object) extends driverB #(T);
//|
//|    `uvm_component_param_utils(driverD1 #(T))
//|
//|    function new(string name, uvm_component parent=null);
//|      super.new(name,parent);
//|    endfunction
//|
//|    static function string type_name();
//|      return {"driverD1 #(",T::type_name,")"};
//|    endfunction : type_name
//|    virtual function string get_type_name();
//|      return type_name();
//|    endfunction
//|
//|  endclass
//|
//|  class driverD2 #(type T=uvm_object) extends driverB #(T);
//|
//|    `uvm_component_param_utils(driverD2 #(T))
//|
//|    function new(string name, uvm_component parent=null);
//|      super.new(name,parent);
//|    endfunction
//|
//|    static function string type_name();
//|      return {"driverD2 #(",T::type_name,")"};
//|    endfunction : type_name
//|    virtual function string get_type_name();
//|      return type_name();
//|    endfunction
//|
//|  endclass
//|
//|  // typedef some specializations for convenience
//|  typedef driverB  #(packet) B_driver;   // the base driver
//|  typedef driverD1 #(packet) D1_driver;  // a derived driver
//|  typedef driverD2 #(packet) D2_driver;  // another derived driver
//
// Next, we'll define a agent component, which requires a utils macro for
// non-parameterized types. Before creating the drivers using the factory, we
// override ~driver0~'s packet type to be ~packetD~.
//
//|  class agent extends uvm_agent;
//|
//|    `uvm_component_utils(agent)
//|    ...
//|    B_driver driver0;
//|    B_driver driver1;
//|
//|    function new(string name, uvm_component parent=null);
//|      super.new(name,parent);
//|    endfunction
//|
//|    virtual function void build_phase(uvm_phase phase);
//|
//|      // override the packet type for driver0 and below
//|      packet::type_id::set_inst_override(packetD::get_type(),"driver0.*");
//|
//|      // create using the factory; actual driver types may be different
//|      driver0 = B_driver::type_id::create("driver0",this);
//|      driver1 = B_driver::type_id::create("driver1",this);
//|
//|    endfunction
//|
//|  endclass
//
// Finally we define an environment class, also not parameterized. Its ~build_phase~
// method shows three methods for setting an instance override on a grandchild
// component with relative path name, ~agent1.driver1~, all equivalent.
//
//|  class env extends uvm_env;
//|
//|    `uvm_component_utils(env)
//|
//|    agent agent0;
//|    agent agent1;
//|
//|    function new(string name, uvm_component parent=null);
//|      super.new(name,parent);
//|    endfunction
//|
//|    virtual function void build_phase(uvm_phase phase);
//|
//|      // three methods to set an instance override for agent1.driver1
//|      // - via component convenience method...
//|      set_inst_override_by_type("agent1.driver1",
//|                                B_driver::get_type(),
//|                                D2_driver::get_type());
//|
//|      // - via the component's proxy (same approach as create)...
//|      B_driver::type_id::set_inst_override(D2_driver::get_type(),
//|                                           "agent1.driver1",this);
//|
//|      // - via a direct call to a factory method...
//|      factory.set_inst_override_by_type(B_driver::get_type(),
//|                                        D2_driver::get_type(),
//|                                        {get_full_name(),".agent1.driver1"});
//|
//|      // create agents using the factory; actual agent types may be different
//|      agent0 = agent::type_id::create("agent0",this);
//|      agent1 = agent::type_id::create("agent1",this);
//|
//|    endfunction
//|
//|    // at end_of_elaboration, print topology and factory state to verify
//|    virtual function void end_of_elaboration_phase(uvm_phase phase);
//|      uvm_top.print_topology();
//|    endfunction
//|
//|    virtual task run_phase(uvm_phase phase);
//|      #100 global_stop_request();
//|    endfunction
//|
//|  endclass
//
//
// 3 -- Configuring the factory with type and instance overrides:
//
// In the previous step, we demonstrated setting instance overrides and creating
// components using the factory within component classes. Here, we will
// demonstrate setting overrides from outside components, as when initializing
// the environment prior to running the test.
//
//|  module top;
//|
//|    env env0;
//|
//|    initial begin
//|
//|      // Being registered first, the following overrides take precedence
//|      // over any overrides made within env0's construction & build.
//|
//|      // Replace all base drivers with derived drivers...
//|      B_driver::type_id::set_type_override(D_driver::get_type());
//|
//|      // ...except for agent0.driver0, whose type remains a base driver.
//|      //     (Both methods below have the equivalent result.)
//|
//|      // - via the component's proxy (preferred)
//|      B_driver::type_id::set_inst_override(B_driver::get_type(),
//|                                           "env0.agent0.driver0");
//|
//|      // - via a direct call to a factory method
//|      factory.set_inst_override_by_type(B_driver::get_type(),
//|                                        B_driver::get_type(),
//|                                    {get_full_name(),"env0.agent0.driver0"});
//|
//|      // now, create the environment; our factory configuration will
//|      // govern what topology gets created
//|      env0 = new("env0");
//|
//|      // run the test (will execute build phase)
//|      run_test();
//|
//|    end
//|
//|  endmodule
//
// When the above example is run, the resulting topology (displayed via a call to
// <uvm_root::print_topology> in env's <uvm_component::end_of_elaboration_phase> method)
// is similar to the following:
//
//| # UVM_INFO @ 0 [RNTST] Running test ...
//| # UVM_INFO @ 0 [UVMTOP] UVM testbench topology:
//| # ----------------------------------------------------------------------
//| # Name                     Type                Size                Value
//| # ----------------------------------------------------------------------
//| # env0                     env                 -                  env0@2
//| #   agent0                 agent               -                agent0@4
//| #     driver0              driverB #(packet)   -               driver0@8
//| #       pkt                packet              -                  pkt@21
//| #     driver1              driverD #(packet)   -              driver1@14
//| #       pkt                packet              -                  pkt@23
//| #   agent1                 agent               -                agent1@6
//| #     driver0              driverD #(packet)   -              driver0@24
//| #       pkt                packet              -                  pkt@37
//| #     driver1              driverD2 #(packet)  -              driver1@30
//| #       pkt                packet              -                  pkt@39
//| # ----------------------------------------------------------------------
//
//------------------------------------------------------------------------------


//------------------------------------------------------------------------------
//
// CLASS -- NODOCS -- uvm_object_wrapper
//
// The uvm_object_wrapper provides an abstract interface for creating object and
// component proxies. Instances of these lightweight proxies, representing every
// <uvm_object>-based and <uvm_component>-based object available in the test
// environment, are registered with the <uvm_factory>. When the factory is
// called upon to create an object or component, it finds and delegates the
// request to the appropriate proxy.
//
//------------------------------------------------------------------------------

// @uvm-ieee 1800.2-2017 auto 8.3.2.1
abstract class uvm_object_wrapper
{
  // Function -- NODOCS -- create_object
  //
  // Creates a new object with the optional ~name~.
  // An object proxy (e.g., <uvm_object_registry #(T,Tname)>) implements this
  // method to create an object of a specific type, T.

  // @uvm-ieee 1800.2-2017 auto 8.3.2.2.1
  uvm_object create_object(string name="") {
    return null;
  }


  // Function -- NODOCS -- create_component
  //
  // Creates a new component, passing to its constructor the given ~name~ and
  // ~parent~. A component proxy (e.g. <uvm_component_registry #(T,Tname)>)
  // implements this method to create a component of a specific type, T.

  // @uvm-ieee 1800.2-2017 auto 8.3.2.2.2
  uvm_component create_component(string name,
				 uvm_component parent) {
    return null;
  }


  // Function -- NODOCS -- get_type_name
  //
  // Derived classes implement this method to return the type name of the object
  // created by <create_component> or <create_object>. The factory uses this
  // name when matching against the requested type in name-based lookups.

  // @uvm-ieee 1800.2-2017 auto 8.3.2.2.3
  abstract string get_type_name();

}


//------------------------------------------------------------------------------
//
// CLASS- uvm_factory_override
//
// Internal class.
//------------------------------------------------------------------------------

final class uvm_factory_override
{
  mixin(uvm_sync_string);

  @uvm_public_sync
  private string _full_inst_path;
  @uvm_public_sync
  private string _orig_type_name;
  @uvm_public_sync
  private string _ovrd_type_name;
  @uvm_public_sync
  private bool _selected;
  @uvm_public_sync
  private uint _used;
  @uvm_public_sync
  private uvm_object_wrapper _orig_type;
  @uvm_public_sync
  private uvm_object_wrapper _ovrd_type;

  this(string full_inst_path,
       string orig_type_name,
       uvm_object_wrapper orig_type,
       uvm_object_wrapper ovrd_type) {
    import uvm.base.uvm_globals;
    import uvm.base.uvm_object_globals;
    synchronized(this) {
      if(ovrd_type is null) {
	uvm_report_fatal("NULLWR",
			 "Attempting to register a null override object" ~
			 " with the factory", uvm_verbosity.UVM_NONE);
      }
      _full_inst_path = full_inst_path;
      _orig_type_name = (orig_type is null) ?
	orig_type_name : orig_type.get_type_name();
      _orig_type      = orig_type;
      _ovrd_type_name = ovrd_type.get_type_name();
      _ovrd_type      = ovrd_type;
    }
  }

  void mark_used() {
    synchronized(this) {
      _used++;
    }
  }
}
