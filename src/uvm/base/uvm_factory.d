//
//------------------------------------------------------------------------------
//   Copyright 2007-2011 Mentor Graphics Corporation
//   Copyright 2007-2011 Cadence Design Systems, Inc.
//   Copyright 2010-2011 Synopsys, Inc.
//   Copyright 2014 Coverify Systems Technology
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

import uvm.base.uvm_object;
import uvm.base.uvm_component;
import uvm.base.uvm_globals;
import uvm.base.uvm_object_globals;

import uvm.meta.misc;
import uvm.meta.mcd;

import esdl.data.queue;
import std.string: format;

// typedef class uvm_object;
// typedef class uvm_component;
// typedef class uvm_object_wrapper;
// typedef class uvm_factory_override;

//Instance overrides by requested type lookup
final class uvm_factory_queue_class
{
  mixin uvm_sync;

  @uvm_private_sync private Queue!uvm_factory_override _queue;

  final public uvm_factory_override opIndex(size_t index) {
    synchronized(this) {
      return _queue[index];
    }
  }

  final public int opApply(int delegate(ref uvm_factory_override) dg) {
    synchronized(this) {
      int result = 0;
      for(size_t i = 0; i < _queue.length; ++i) {
	result = dg(_queue[i]);
	if(result) break;
      }
      return result;
    }
  }

  final public size_t length() {
    synchronized(this) {
      return _queue.length();
    }
  }

  // Function: pop_front
  //
  // Returns the first element in the queue (index=0),
  // or ~null~ if the queue is empty.

  final public uvm_factory_override pop_front() {
    synchronized(this) {
      auto ret = _queue.front();
      _queue.removeFront();
      return ret;
    }
  }


  // Function: pop_back
  //
  // Returns the last element in the queue (index=size()-1),
  // or ~null~ if the queue is empty.

  final public uvm_factory_override pop_back() {
    synchronized(this) {
      auto ret = _queue.back();
      _queue.removeBack();
      return ret;
    }
  }


  // Function: push_front
  //
  // Inserts the given ~item~ at the front of the queue.

  final public void push_front(uvm_factory_override item) {
    synchronized(this) {
      _queue.pushFront(item);
    }
  }

  // Function: push_back
  //
  // Inserts the given ~item~ at the back of the queue.

  final public void push_back(uvm_factory_override item) {
    synchronized(this) {
      _queue.pushBack(item);
    }
  }

}

//------------------------------------------------------------------------------
// Title: UVM Factory
//
// This page covers the classes that define the UVM factory facility.
//------------------------------------------------------------------------------


//------------------------------------------------------------------------------
//
// CLASS: uvm_factory
//
//------------------------------------------------------------------------------
//
// As the name implies, uvm_factory is used to manufacture (create) UVM objects
// and components. Only one instance of the factory is present in a given
// simulation (termed a singleton). Object and component types are registered
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
// See <Usage> section for details on configuring and using the factory.
//

final class uvm_once_factory
{
  @uvm_private_sync private bool _m_debug_pass;
  @uvm_immutable_sync private uvm_factory _m_inst;
  this() {
    synchronized(this) {
      _m_inst = new uvm_factory();
    }
  }
}

final class uvm_factory
{
  mixin(uvm_once_sync!(uvm_once_factory));

  // systemverilog version defines this function as empty -- god knows
  // why they need to do that
  // protected this() { }

  // Function: get()
  // Get the factory singleton
  //
  static public uvm_factory get() {
    synchronized(uvm_once) {
      return m_inst;
    }
  }


  // Group: Registering Types

  // Function: register
  //
  // Registers the given proxy object, ~obj~, with the factory. The proxy object
  // is a lightweight substitute for the component or object it represents. When
  // the factory needs to create an object of a given type, it calls the proxy's
  // create_object or create_component method to do so.
  //
  // When doing name-based operations, the factory calls the proxy's
  // get_type_name method to match against the ~requested_type_name~ argument in
  // subsequent calls to <create_component_by_name> and <create_object_by_name>.
  // If the proxy object's get_type_name method returns the empty string,
  // name-based lookup is effectively disabled.

  final public void register(uvm_object_wrapper obj) {
    synchronized(this) {
      if(obj is null) {
	uvm_report_fatal("NULLWR", "Attempting to register a null object"
			 " with the factory", UVM_NONE);
      }
      if(obj.get_type_name() != "" && obj.get_type_name() != "<unknown>") {
	if(obj.get_type_name() in _m_type_names) {
	  uvm_report_warning("TPRGED", "Type name '" ~ obj.get_type_name() ~
			     "' already registered with factory. No "
			     "string-based lookup " ~
			     "support for multiple types with the same"
			     " type name.", UVM_NONE);
	}
	else {
	  _m_type_names[obj.get_type_name()] = obj;
	}
      }

      if(obj in _m_types) {
	if(obj.get_type_name() != "" && obj.get_type_name() != "<unknown>") {
	  uvm_report_warning("TPRGED", "Object type '" ~ obj.get_type_name() ~
			     "' already registered with factory. ", UVM_NONE);
	}
      }
      else {
	_m_types[obj] = true;
	// If a named override happens before the type is registered, need to copy
	// the override queue.
	// Note:Registration occurs via static initialization, which occurs ahead of
	// procedural (e.g. initial) blocks. There should not be any preexisting overrides.
	if(obj.get_type_name() in _m_inst_override_name_queues) {
	  _m_inst_override_queues[obj] = new uvm_factory_queue_class;
	  _m_inst_override_queues[obj].queue =
	    _m_inst_override_name_queues[obj.get_type_name()].queue;
	  _m_inst_override_name_queues.remove(obj.get_type_name());
	}
	if(_m_wildcard_inst_overrides.length != 0) {
	  if(obj !in _m_inst_override_queues) {
	    _m_inst_override_queues[obj] = new uvm_factory_queue_class;
	  }
	  foreach(i, inst_override; _m_wildcard_inst_overrides) {
	    if(uvm_is_match(inst_override.orig_type_name, obj.get_type_name())) {
	      _m_inst_override_queues[obj].push_back(inst_override);
	    }
	  }
	}
      }
    }
  }


  // Group: Type & Instance Overrides

  // Function: set_inst_override_by_type

  // set_inst_override_by_type
  // -------------------------

  final public void set_inst_override_by_type(uvm_object_wrapper original_type,
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

  // Function: set_inst_override_by_name
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
  // string. Future calls to any of the create_* methods with the same string
  // and matching instance path will produce the type represented by
  // ~override_type_name~, which must be preregistered with the factory.
  //
  // The ~full_inst_path~ is matched against the contentation of
  // {~parent_inst_path~, ".", ~name~} provided in future create requests. The
  // ~full_inst_path~ may include wildcards (* and ?) such that a single
  // instance override can be applied in multiple contexts. A ~full_inst_path~
  // of "*" is effectively a type override, as it will match all contexts.
  //
  // When the factory processes instance overrides, the instance queue is
  // processed in order of override registrations, and the first override
  // match prevails. Thus, more specific overrides should be registered
  // first, followed by more general overrides.

  // set_inst_override_by_name
  // -------------------------

  final public void set_inst_override_by_name(string original_type_name,
					      string override_type_name,
					      string full_inst_path) {
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
	uvm_report_error("TYPNTF", "Cannot register instance override with"
			 " type name '" ~ original_type_name ~
			 "' and instance path '" ~ full_inst_path ~
			 "' because the type it's supposed " ~
			 "to produce ~  '" ~ override_type_name ~
			 "',  is not registered with the factory.", UVM_NONE);
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
	    if(uvm_is_match(original_type_name,i)) {
	      this.set_inst_override_by_name(i, override_type_name,
					     full_inst_path);
	    }
	  }
	  _m_wildcard_inst_overrides.pushBack(ovrrd);
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



  // Function: set_type_override_by_type

  // set_type_override_by_type
  // -------------------------

  final public void set_type_override_by_type(uvm_object_wrapper original_type,
					      uvm_object_wrapper override_type,
					      bool replace = true) {
    synchronized(this) {
      bool replaced = false;

      // check that old and new are not the same
      if(original_type is override_type) {
	if(original_type.get_type_name() == "" ||
	   original_type.get_type_name() == "<unknown>") {
	  uvm_report_warning("TYPDUP", "Original and override type " ~
			     "arguments are identical", UVM_NONE);
	}
	else {
	  uvm_report_warning("TYPDUP", "Original and override type " ~
			     "arguments are identical: " ~
			     original_type.get_type_name(), UVM_NONE);
	}
	return;
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
	    string msg = "Original object type '" ~
	      original_type.get_type_name() ~
	      "' already registered to produce '" ~
	      type_override.ovrd_type_name ~ "'";
	    if(!replace) {
	      msg ~= ".  Set 'replace' argument to replace the existing entry.";
	      uvm_report_info("TPREGD", msg, UVM_MEDIUM);
	      return;
	    }
	    msg ~= ".  Replacing with override to produce type '" ~
	      override_type.get_type_name() ~ "'.";
	    uvm_report_info("TPREGR", msg, UVM_MEDIUM);
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
					      original_type,
					      override_type);

	_m_type_overrides.pushBack(ovrrd);
      }

    }
  }



  // Function: set_type_override_by_name
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
  // string. Future calls to any of the create_* methods with the same string
  // and matching instance path will produce the type represented by
  // ~override_type_name~, which must be preregistered with the factory.
  //
  // When ~replace~ is 1, a previous override on ~original_type_name~ is
  // replaced, otherwise a previous override, if any, remains intact.

  // set_type_override_by_name
  // -------------------------

  final public void set_type_override_by_name(string original_type_name,
					      string override_type_name,
					      bool replace = true) {
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
			 "' is not registered with the factory.", UVM_NONE);
	return;
      }

      // check that old and new are not the same
      if(original_type_name == override_type_name) {
	uvm_report_warning("TYPDUP", "Requested and actual type name " ~
			   " arguments are identical: " ~ original_type_name ~
			   ". Ignoring this override.", UVM_NONE);
	return;
      }

      foreach(index, type_override; _m_type_overrides) {
	if(type_override.orig_type_name == original_type_name) {
	  if(!replace) {
	    uvm_report_info("TPREGD", "Original type '" ~ original_type_name ~
			    "' already registered to produce '" ~
			    type_override.ovrd_type_name ~
			    "'.  Set 'replace' argument to replace the "
			    "existing entry.", UVM_MEDIUM);
	    return;
	  }
	  uvm_report_info("TPREGR", "Original object type '" ~
			  original_type_name ~
			  "' already registered to produce '" ~
			  type_override.ovrd_type_name ~
			  "'.  Replacing with override to produce type '" ~
			  override_type_name ~ "'.", UVM_MEDIUM);
	  replaced = true;
	  type_override.ovrd_type = override_type;
	  type_override.ovrd_type_name = override_type_name;
	}
      }

      if(original_type is null) {
	_m_lookup_strs[original_type_name] = true;
      }

      if(!replaced) {
	auto ovrrd = new uvm_factory_override("*",
					      original_type_name,
					      original_type,
					      override_type);

	_m_type_overrides.pushBack(ovrrd);
	//    _m_type_names[original_type_name] = override.ovrd_type;
      }

    }
  }


  // Group: Creation

  // Function: create_object_by_type

  // create_object_by_type
  // ---------------------

  final public uvm_object create_object_by_type(uvm_object_wrapper requested_type,
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

      _m_override_info.clear();

      requested_type = find_override_by_type(requested_type, full_inst_path);

      return requested_type.create_object(name);

    }
  }


  // Function: create_component_by_type

  // create_component_by_type
  // ------------------------

  final public uvm_component create_component_by_type(uvm_object_wrapper requested_type,
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

      _m_override_info.clear();

      requested_type = find_override_by_type(requested_type, full_inst_path);

      return requested_type.create_component(name, parent);

    }
  }

  // Function: create_object_by_name

  // create_object_by_name
  // ---------------------

  final public uvm_object create_object_by_name(string requested_type_name,
						string parent_inst_path="",
						string name="") {
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

      _m_override_info.clear();

      wrapper = find_override_by_name(requested_type_name, inst_path);

      // if no override exists, try to use requested_type_name directly
      if(wrapper is null) {
	if(requested_type_name !in _m_type_names) {
	  // return null;
	  
	  // SV works via static initialization -- In Vlang we do not
	  // have that option since we create uvm_root dynamically
	  // For VLang we have a special recourse == Try to invoke the
	  // Object.factory
	  auto obj = Object.factory(requested_type_name);
	  if(obj is null) {
	    uvm_report_warning("BDTYP", "Cannot create an object of type '" ~
			       requested_type_name ~
			       "' because it is not registered with the factory.",
			       UVM_NONE);

	    uvm_report_warning("BDTYP", "Object.factory Cannot create an object of type '" ~
			       requested_type_name ~
			       "'.",
			       UVM_NONE);
	  }
	  auto uobj = cast(uvm_object) obj;
	  if(uobj is null) {
	    uvm_report_warning("BDTYP", "Object.factory created an object but could cast it to uvm_object type '" ~
			       requested_type_name ~
			       "'.",
			       UVM_NONE);
	  }
	  return uobj;
	}
	wrapper = _m_type_names[requested_type_name];
      }

      return wrapper.create_object(name);

    }
  }


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
  // ~requested_type_name~, an error is produced and a null handle returned.
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

  // create_component_by_name
  // ------------------------

  final public uvm_component create_component_by_name(string requested_type_name,
						      string parent_inst_path,
						      string name,
						      uvm_component parent) {
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

      _m_override_info.clear();

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
			       UVM_NONE);
	    uvm_report_warning("BDTYP", "Object.factory Cannot create an object of type '" ~
			       requested_type_name ~
			       "'.",
			       UVM_NONE);
	  }
	  auto ucomp = cast(uvm_component) comp;
	  if(ucomp is null) {
	    uvm_report_warning("BDTYP", "Object.factory created an object but could cast it to uvm_component type '" ~
			       requested_type_name ~
			       "'.",
			       UVM_NONE);
	  }
	  return ucomp;
	}
	wrapper = _m_type_names[requested_type_name];
      }

      return wrapper.create_component(name, parent);

    }
  }


  // Group: Debug

  // Function: debug_create_by_type

  // debug_create_by_type
  // --------------------

  final public void debug_create_by_type(uvm_object_wrapper requested_type,
					 string parent_inst_path="",
					 string name="") {
    m_debug_create("", requested_type, parent_inst_path, name);
  }

  // Function: debug_create_by_name
  //
  // These methods perform the same search algorithm as the create_* methods,
  // but they do not create new objects. Instead, they provide detailed
  // information about what type of object it would return, listing each
  // override that was applied to arrive at the result. Interpretation of the
  // arguments are exactly as with the create_* methods.

  // debug_create_by_name
  // --------------------

  final public void  debug_create_by_name(string requested_type_name,
					  string parent_inst_path="",
					  string name="") {
    m_debug_create(requested_type_name, null, parent_inst_path, name);
  }


  // Function: find_override_by_type

  // find_override_by_type
  // ---------------------

  final public uvm_object_wrapper find_override_by_type(uvm_object_wrapper requested_type,
							string full_inst_path) {
    synchronized(this) {
      uvm_object_wrapper ovrrd;
      uvm_factory_queue_class qc = null;
      if(requested_type in _m_inst_override_queues) {
	qc = _m_inst_override_queues[requested_type];
      }

      foreach(index, override_info; _m_override_info) {
	if( //index !is _m_override_info.size()-1 &&
	   override_info.orig_type is requested_type) {
	  uvm_report_error("OVRDLOOP",
			   "Recursive loop detected while finding override.",
			   UVM_NONE);
	  if(!m_debug_pass) {
	    debug_create_by_type(requested_type, full_inst_path);
	  }
	  return requested_type;
	}
      }

      // inst override; return first match; takes precedence over type overrides
      if(full_inst_path != "" && qc !is null) {
	for(int index = 0; index < qc.length; ++index) {
	  if((qc[index].orig_type is requested_type ||
	      (qc[index].orig_type_name != "<unknown>" &&
	       qc[index].orig_type_name != "" &&
	       qc[index].orig_type_name == requested_type.get_type_name())) &&
	     uvm_is_match(qc[index].full_inst_path, full_inst_path)) {
	    _m_override_info.pushBack(qc[index]);
	    if(m_debug_pass) {
	      if(ovrrd is null) {
		ovrrd = qc[index].ovrd_type;
		qc[index].selected = true;
	      }
	    }
	    else {
	      if(qc[index].ovrd_type is requested_type) {
		return requested_type;
	      }
	      else {
		return find_override_by_type(qc[index].ovrd_type,full_inst_path);
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
	  _m_override_info.pushBack(type_override);
	  if(m_debug_pass) {
	    if(ovrrd is null) {
	      ovrrd = type_override.ovrd_type;
	      type_override.selected = true;
	    }
	  }
	  else {
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

  // Function: find_override_by_name
  //
  // These methods return the proxy to the object that would be created given
  // the arguments. The ~full_inst_path~ is typically derived from the parent's
  // instance path and the leaf name of the object to be created, i.e.
  // { parent.get_full_name(), ".", name }.

  // find_override_by_name
  // ---------------------

  final public uvm_object_wrapper find_override_by_name(string requested_type_name,
							string full_inst_path) {
    synchronized(this) {
      uvm_object_wrapper rtype;
      uvm_factory_queue_class qc;

      uvm_object_wrapper ovrrd;

      if(requested_type_name in _m_type_names) {
	rtype = _m_type_names[requested_type_name];
      }

      /***
	  if(rtype is null) {
	  if(requested_type_name != "") {
	  uvm_report_warning("TYPNTF", {"Requested type name ",
	  requested_type_name, " is not registered with the factory. The instance override to ",
	  full_inst_path, " is ignored"}, UVM_NONE);
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
	  for(int index = 0; index<qc.length; ++index) {
	    if(uvm_is_match(qc[index].orig_type_name, requested_type_name) &&
	       uvm_is_match(qc[index].full_inst_path, full_inst_path)) {
	      _m_override_info.pushBack(qc[index]);
	      if(m_debug_pass) {
		if(ovrrd is null) {
		  ovrrd = qc[index].ovrd_type;
		  qc[index].selected = true;
		}
	      }
	      else {
		if(qc[index].ovrd_type.get_type_name() == requested_type_name) {
		  return qc[index].ovrd_type;
		}
		else {
		  return find_override_by_type(qc[index].ovrd_type,
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
	  _m_override_info.pushBack(type_override);
	  if(m_debug_pass) {
	    if(ovrrd is null) {
	      ovrrd = type_override.ovrd_type;
	      type_override.selected = true;
	    }
	  }
	  else {
	    return find_override_by_type(type_override.ovrd_type,
					 full_inst_path);
	  }
	}
      }

      if(m_debug_pass && ovrrd !is null) {
	return find_override_by_type(ovrrd, full_inst_path);
      }

      // No override found
      return null;

    }
  }


  // find_by_name
  // ------------

  final public uvm_object_wrapper find_by_name(string type_name) {
    synchronized(this) {
      if(type_name in _m_type_names) {
	return _m_type_names[type_name];
      }

      uvm_report_warning("UnknownTypeName",
			 "find_by_name: Type name '" ~ type_name ~
			 "' not registered with the factory.", UVM_NONE);
      return null;
    }
  }


  // Function: print
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

  final public void print(int all_types=1) {
    synchronized(this) {
      uvm_factory_queue_class[string] sorted_override_queues;

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

      vdisplay("\n#### Factory Configuration (*)\n");

      // print instance overrides
      if(_m_type_overrides.length is 0 && sorted_override_queues.length is 0) {
	vdisplay("  No instance or type overrides are registered with this factory");
      }
      else {
	ulong max1,max2,max3;
	string dash = "---------------------------------------------------------------------------------------------------";
	string space= "                                                                                                   ";

	// print instance overrides
	if(sorted_override_queues.length is 0) {
	  vdisplay("No instance overrides are registered with this factory");
	}
	else {
	  foreach(j, qc; sorted_override_queues) {
	    for(int i=0; i<qc.length; ++i) {
	      if(qc[i].orig_type_name.length > max1)
		max1=qc[i].orig_type_name.length;
	      if(qc[i].full_inst_path.length > max2)
		max2=qc[i].full_inst_path.length;
	      if(qc[i].ovrd_type_name.length > max3)
		max3=qc[i].ovrd_type_name.length;
	    }
	  }
	  if(max1 < 14) max1 = 14;
	  if(max2 < 13) max2 = 13;
	  if(max3 < 13) max3 = 13;

	  vdisplay("Instance Overrides:\n");
	  vdisplay("  %0s%0s  %0s%0s  %0s%0s",
		   "Requested Type", space[1..max1-13],
		   "Override Path", space[1..max2-12],
		   "Override Type", space[1..max3-12]);
	  vdisplay("  %0s  %0s  %0s", dash[1..max1+1],
		   dash[1..max2+1],
		   dash[1..max3+1]);

	  foreach(j, qc;sorted_override_queues) {
	    for(int i=0; i<qc.length; ++i) {
	      vwrite("  %0s%0s",qc[i].orig_type_name,
		     space[1..max1-qc[i].orig_type_name.length+1]);
	      vwrite("  %0s%0s",  qc[i].full_inst_path,
		     space[1..max2-qc[i].full_inst_path.length+1]);
	      vdisplay("  %0s",     qc[i].ovrd_type_name);
	    }
	  }
	}

	// print type overrides
	if(_m_type_overrides.length is 0) {
	  vdisplay("\nNo type overrides are registered with this factory");
	}
	else {
	  // Resize for type overrides
	  if(max1 < 14) max1 = 14;
	  if(max2 < 13) max2 = 13;
	  if(max3 < 13) max3 = 13;

	  foreach(i, type_override; _m_type_overrides) {
	    if(type_override.orig_type_name.length > max1)
	      max1=type_override.orig_type_name.length;
	    if(type_override.ovrd_type_name.length > max2)
	      max2=type_override.ovrd_type_name.length;
	  }
	  if(max1 < 14) max1 = 14;
	  if(max2 < 13) max2 = 13;
	  vdisplay("\nType Overrides:\n");
	  vdisplay("  %0s%0s  %0s%0s",
		   "Requested Type",space[1..max1-13],
		   "Override Type", space[1..max2-12]);
	  vdisplay("  %0s  %0s",
		   dash[1..max1+1],
		   dash[1..max2+1]);
	  foreach(index, type_override; _m_type_overrides) {
	    vdisplay("  %0s%0s  %0s",
		     type_override.orig_type_name,
		     space[1..max1-type_override.orig_type_name.length+1],
		     type_override.ovrd_type_name);
	  }
	}
      }

      // print all registered types, if all_types >= 1
      if(all_types >= 1 && _m_type_names.length != 0) {
	bool banner;
	vdisplay("\nAll types registered with the factory: %0d total",
		 _m_types.length);
	vdisplay("(types without type names will not be printed)\n");
	foreach(key, type_name; _m_type_names) {
	  // filter out uvm_ classes (if all_types<2) and non-types (lookup strings)
	  if(!(all_types < 2 &&
	       uvm_is_match("uvm_*",	type_name.get_type_name())) &&
	     key == type_name.get_type_name()) {
	    if(!banner) {
	      vdisplay("  Type Name");
	      vdisplay("  ---------");
	      banner = true;
	    }
	    vdisplay("  ", type_name.get_type_name());
	  }
	}
      }

      vdisplay("(*) Types with no associated type name will be printed"
	       " as <unknown>");

      vdisplay("\n####\n");

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

      _m_override_info.clear();

      if(requested_type is null) {
	if(requested_type_name !in _m_type_names &&
	   requested_type_name !in _m_lookup_strs) {
	  uvm_report_warning("Factory Warning",
			     "The factory does not recognize '" ~
			     requested_type_name ~
			     "' as a registered type.", UVM_NONE);
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
    synchronized(this) {

      ulong    max1,max2,max3;
      string dash  = "---------------------------------------------------------"
	"------------------------------------------";
      string space = "                                                         "
	"                                          ";

      vdisplay("\n#### Factory Override Information (*)\n");
      vwrite("Given a request for an object of type '", requested_type_name,
	     "' with an instance\npath of '", full_inst_path,
	     "', the factory encountered\n");

      if(_m_override_info.length is 0) {
	vdisplay("no relevant overrides.\n");
      }
      else {

	vdisplay("the following relevant overrides. An 'x' next to a match"
		 " indicates a", "\nmatch that was ignored.\n");

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

	if(max1 < 13) max1 = 13;
	if(max2 < 13) max2 = 13;
	if(max3 < 13) max3 = 13;

	vdisplay("  %0s%0s", "Original Type", space[1..max1-12],
		 "  %0s%0s", "Instance Path", space[1..max2-12],
		 "  %0s%0s", "Override Type", space[1..max3-12]);

	vdisplay("  %0s  %0s  %0s",dash[1..max1+1],
		 dash[1..max2+1],
		 dash[1..max3+1]);

	foreach(i, override_info; _m_override_info) {
	  vwrite("%s%0s%0s",
		 override_info.selected ? "  " : "x ",
		 override_info.orig_type_name,
		 space[1..max1-override_info.orig_type_name.length+1]);
	  vwrite("  %0s%0s", override_info.full_inst_path,
		 space[1..max2-override_info.full_inst_path.length+1]);
	  vwrite("  %0s%0s", override_info.ovrd_type_name,
		 space[1..max3-override_info.ovrd_type_name.length+1]);
	  if(override_info.full_inst_path == "*")
	    vdisplay("  <type override>");
	  else
	    vdisplay();
	}
	vdisplay();
      }


      vdisplay("Result:\n");
      vdisplay("  The factory will produce an object of type '%0s'",
	       result is null ? requested_type_name : result.get_type_name());

      vdisplay("\n(*) Types with no associated type name will be printed as <unknown>");

      vdisplay("\n####\n");

    }
  }


  protected bool[uvm_object_wrapper]      _m_types;
  protected bool[string]                  _m_lookup_strs;
  protected uvm_object_wrapper[string]    _m_type_names;

  protected Queue!uvm_factory_override _m_type_overrides;

  protected uvm_factory_queue_class[uvm_object_wrapper] _m_inst_override_queues;
  protected uvm_factory_queue_class[string]             _m_inst_override_name_queues;
  protected Queue!uvm_factory_override                  _m_wildcard_inst_overrides;

  private Queue!uvm_factory_override                    _m_override_info;

  static public bool m_has_wildcard(string nm) {
    foreach(i, _n; nm) {
      if(_n == '*' || _n == '?') return 1;
    }
    return 0;
  }


  // check_inst_override_exists
  // --------------------------
  final public bool check_inst_override_exists(uvm_object_wrapper original_type,
					       uvm_object_wrapper override_type,
					       string full_inst_path) {
    synchronized(this) {
      uvm_factory_override ovrrd;
      uvm_factory_queue_class qc;

      if(original_type in _m_inst_override_queues) {
	qc = _m_inst_override_queues[original_type];
      }
      else {
	return false;
      }

      for(int index=0; index < qc.length; ++index) {
	ovrrd = qc[index];
	if(ovrrd.full_inst_path == full_inst_path &&
	   ovrrd.orig_type is original_type &&
	   ovrrd.ovrd_type is override_type &&
	   ovrrd.orig_type_name == original_type.get_type_name()) {
	  uvm_report_info("DUPOVRD", "Instance override for '" ~
			  original_type.get_type_name() ~
			  "' already exists: override type '" ~
			  override_type.get_type_name() ~
			  "' with full_inst_path '" ~
			  full_inst_path ~ "'",UVM_HIGH);
	  return true;
	}
      }
      return false;
    }
  }
}

// conflicts with dlang object.Object.factory
// public uvm_factory factory() {
//   return uvm_factory.get();
// }


//------------------------------------------------------------------------------
//
// Group: Usage
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
// - The get_type_name method and static type_name variable are not defined. You
//   will need to implement these manually.
//
// - A type name is not associated with the type when registeriing with the
//   factory, so the factory's *_by_name operations will not work with
//   parameterized classes.
//
// - The factory's <print>, <debug_create_by_type>, and <debug_create_by_name>
//   methods, which depend on type names to convey information, will list
//   parameterized types as <unknown>.
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
//|    const static string type_name = {"driverB #(",T::type_name,")"};
//|    virtual function string get_type_name();
//|      return type_name;
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
//|    const static string type_name = {"driverD1 #(",T::type_name,")"};
//|    virtual function string get_type_name();
//|      ...return type_name;
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
//|    const static string type_name = {"driverD2 #(",T::type_name,")"};
//|    virtual function string get_type_name();
//|      return type_name;
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
// Finally we define an environment class, also not parameterized. Its build
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
// CLASS: uvm_object_wrapper
//
// The uvm_object_wrapper provides an abstract interface for creating object and
// component proxies. Instances of these lightweight proxies, representing every
// <uvm_object>-based and <uvm_component>-based object available in the test
// environment, are registered with the <uvm_factory>. When the factory is
// called upon to create an object or component, it finds and delegates the
// request to the appropriate proxy.
//
//------------------------------------------------------------------------------

abstract class uvm_object_wrapper
{
  // Function: create_object
  //
  // Creates a new object with the optional ~name~.
  // An object proxy (e.g., <uvm_object_registry #(T,Tname)>) implements this
  // method to create an object of a specific type, T.

  public uvm_object create_object(string name="") {
    return null;
  }


  // Function: create_component
  //
  // Creates a new component, passing to its constructor the given ~name~ and
  // ~parent~. A component proxy (e.g. <uvm_component_registry #(T,Tname)>)
  // implements this method to create a component of a specific type, T.

  public uvm_component create_component(string name,
					uvm_component parent) {
    return null;
  }


  // Function: get_type_name
  //
  // Derived classes implement this method to return the type name of the object
  // created by <create_component> or <create_object>. The factory uses this
  // name when matching against the requested type in name-based lookups.

  abstract public string get_type_name();

}


//------------------------------------------------------------------------------
//
// CLASS- uvm_factory_override
//
// Internal class.
//------------------------------------------------------------------------------

final class uvm_factory_override
{
  mixin uvm_sync;

  @uvm_private_sync private string _full_inst_path;
  @uvm_private_sync private string _orig_type_name;
  @uvm_private_sync private string _ovrd_type_name;
  @uvm_private_sync private bool _selected;
  @uvm_private_sync private uvm_object_wrapper _orig_type;
  @uvm_private_sync private uvm_object_wrapper _ovrd_type;

  public this(string full_inst_path,
	      string orig_type_name,
	      uvm_object_wrapper orig_type,
	      uvm_object_wrapper ovrd_type) {
    synchronized(this) {
      if(ovrd_type is null) {
	uvm_report_fatal("NULLWR",
			 "Attempting to register a null override object"
			 " with the factory", UVM_NONE);
      }
      _full_inst_path = full_inst_path;
      _orig_type_name =(orig_type is null) ?
	orig_type_name : orig_type.get_type_name();
      _orig_type      = orig_type;
      _ovrd_type_name = ovrd_type.get_type_name();
      _ovrd_type      = ovrd_type;
    }
  }
}


// Conflicts with D factory

//-----------------------------------------------------------------------------
// our singleton factory; it is statically initialized
//-----------------------------------------------------------------------------

// public uvm_factory factory() {
//   return uvm_factory.get();
// }
