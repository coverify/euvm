//
//------------------------------------------------------------------------------
// Copyright 2014-2021 Coverify Systems Technology
// Copyright 2011 AMD
// Copyright 2007-2018 Cadence Design Systems, Inc.
// Copyright 2018 Cisco Systems, Inc.
// Copyright 2014 Intel Corporation
// Copyright 2007-2020 Mentor Graphics Corporation
// Copyright 2014-2020 NVIDIA Corporation
// Copyright 2018 Qualcomm, Inc.
// Copyright 2011-2014 Synopsys, Inc.
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

module uvm.base.uvm_registry;
import uvm.base.uvm_scope;
import uvm.meta.misc;

import uvm.base.uvm_object: uvm_object;
import uvm.base.uvm_factory: uvm_object_wrapper;

// `ifndef UVM_REGISTRY_SVH
// `define UVM_REGISTRY_SVH

//------------------------------------------------------------------------------
// Title: Factory Component and Object Wrappers
//
// This section defines the proxy component and object classes used by the
// factory.
//------------------------------------------------------------------------------



// Class: uvm_component_registry#(T,Tname)
// Implementation of uvm_component_registry#(T,Tname), as defined by section
// 8.2.3.1 of 1800.2-2020.
  
// @uvm-ieee 1800.2-2020 auto 8.2.3.1
template uvm_component_registry(T, bool NAMED=true)
{
  import std.traits: fullyQualifiedName;
  static if (NAMED)
    alias uvm_component_registry = uvm_component_registry!(T, fullyQualifiedName!T);
  else alias uvm_component_registry = uvm_component_registry!(T, "<unknown>");
}

class uvm_component_registry(T, string Tname): uvm_object_wrapper
{
  import uvm.base.uvm_component: uvm_component;
  alias this_type = uvm_component_registry !(T,Tname);
  alias common_type =
    uvm_registry_common!(this_type, uvm_registry_component_creator, T, Tname);

  // Function -- NODOCS -- create_component
  //
  // Creates a component of type T having the provided ~name~ and ~parent~.
  // This is an override of the method in <uvm_object_wrapper>. It is
  // called by the factory after determining the type of object to create.
  // You should not call this method directly. Call <create> instead.

  // @uvm-ieee 1800.2-2020 auto 8.2.3.2.1
  override uvm_component create_component (string name,
				  uvm_component parent) {
    T obj = new T(name, parent);
    return obj;
  }

  static string type_name() {
    return common_type.type_name();
  }

  // Function -- NODOCS -- get_type_name
  //
  // Returns the value given by the string parameter, ~Tname~. This method
  // overrides the method in <uvm_object_wrapper>.

  // @uvm-ieee 1800.2-2020 auto 8.2.3.2.2
  override string get_type_name() {
    common_type common = common_type.get();
    return common.get_type_name();
  }

  static class uvm_scope: uvm_scope_base
  {
    @uvm_public_sync
    this_type _m_inst;
  }
    
  mixin (uvm_scope_sync_string);
  
  static this_type get() {
    synchronized (_uvm_scope_inst) {
      if (_uvm_scope_inst._m_inst is null) {
	_uvm_scope_inst._m_inst = new this_type();
      }
      return _uvm_scope_inst._m_inst;
    }
  }

  // @uvm-ieee 1800.2-2020 auto 8.2.3.2.7
  override void initialize() {
    common_type common = common_type.get();
    common.initialize();
  }

  // Function -- NODOCS -- create
  //
  // Returns an instance of the component type, ~T~, represented by this proxy,
  // subject to any factory overrides based on the context provided by the
  // ~parent~'s full name. The ~contxt~ argument, if supplied, supersedes the
  // ~parent~'s context. The new instance will have the given leaf ~name~
  // and ~parent~.

  // @uvm-ieee 1800.2-2020 auto 8.2.3.2.4
  static T create(string name, uvm_component parent, string contxt="") {
    return common_type.create(name, parent, contxt);
  }


  // Function -- NODOCS -- set_type_override
  //
  // Configures the factory to create an object of the type represented by
  // ~override_type~ whenever a request is made to create an object of the type,
  // ~T~, represented by this proxy, provided no instance override applies. The
  // original type, ~T~, is typically a super class of the override type.

  // @uvm-ieee 1800.2-2020 auto 8.2.3.2.5
  static void set_type_override (uvm_object_wrapper override_type,
				 bool replace=1) {
    common_type.set_type_override(override_type, replace);
  }


  // Function -- NODOCS -- set_inst_override
  //
  // Configures the factory to create a component of the type represented by
  // ~override_type~ whenever a request is made to create an object of the type,
  // ~T~, represented by this proxy,  with matching instance paths. The original
  // type, ~T~, is typically a super class of the override type.
  //
  // If ~parent~ is not specified, ~inst_path~ is interpreted as an absolute
  // instance path, which enables instance overrides to be set from outside
  // component classes. If ~parent~ is specified, ~inst_path~ is interpreted
  // as being relative to the ~parent~'s hierarchical instance path, i.e.
  // ~{parent.get_full_name(),".",inst_path}~ is the instance path that is
  // registered with the override. The ~inst_path~ may contain wildcards for
  // matching against multiple contexts.

  // @uvm-ieee 1800.2-2020 auto 8.2.3.2.6
  static void set_inst_override(uvm_object_wrapper override_type,
				string inst_path,
				uvm_component parent=null) {
    common_type.set_inst_override(override_type, inst_path, parent);
  }

  // Function: set_type_alias
  // Sets a type alias for this wrapper in the default factory.
  //
  // If this wrapper is not yet registered with a factory (see <uvm_factory::register>),
  // then the alias is deferred until registration occurs.
  //
  // @uvm-contrib This API is being considered for potential contribution to 1800.2
  static bool set_type_alias(string alias_name) {
    common_type.set_type_alias(alias_name);
    return true;
  }

}


// Class: uvm_object_registry#(T,Tname)
// Implementation of uvm_object_registry#(T,Tname), as defined by section
// 8.2.4.1 of 1800.2-2020.

// @uvm-ieee 1800.2-2020 auto 8.2.4.1
template uvm_object_registry(T, bool NAMED=true)
{
  import std.traits: fullyQualifiedName;
  static if (NAMED)
    alias uvm_object_registry = uvm_object_registry!(T, fullyQualifiedName!T);
  else alias uvm_object_registry = uvm_object_registry!(T, "<unknown>");
}

class uvm_object_registry(T, string Tname): uvm_object_wrapper
{
  import uvm.base.uvm_component: uvm_component;
  alias this_type = uvm_object_registry!(T,Tname);
  alias common_type =
    uvm_registry_common!(this_type, uvm_registry_object_creator, T, Tname);

  // Function -- NODOCS -- create_object
  //
  // Creates an object of type ~T~ and returns it as a handle to a
  // <uvm_object>. This is an override of the method in <uvm_object_wrapper>.
  // It is called by the factory after determining the type of object to create.
  // You should not call this method directly. Call <create> instead.

  // @uvm-ieee 1800.2-2020 auto 8.2.4.2.1
  override uvm_object create_object(string name="") {
    T obj;
    if (name == "") obj = new T();
    else obj = new T(name);
    return obj;
  }

  static string type_name() {
    return common_type.type_name();
  }

  // Function -- NODOCS -- get_type_name
  //
  // Returns the value given by the string parameter, ~Tname~. This method
  // overrides the method in <uvm_object_wrapper>.

  // @uvm-ieee 1800.2-2020 auto 8.2.4.2.2
  override string get_type_name() {
    common_type common = common_type.get();
    return common.get_type_name();
  }

  //
  // Returns the singleton instance of this type. Type-based factory operation
  // depends on there being a single proxy instance for each registered type.

  static class uvm_scope: uvm_scope_base
  {
    @uvm_public_sync
    this_type _m_inst;
  }
    
  mixin (uvm_scope_sync_string);
  
  static this_type get() {
    synchronized (_uvm_scope_inst) {
      if (_uvm_scope_inst._m_inst is null) {
	_uvm_scope_inst._m_inst = new this_type();
      }
      return _uvm_scope_inst._m_inst;
    }
  }


  // Function -- NODOCS -- create
  //
  // Returns an instance of the object type, ~T~, represented by this proxy,
  // subject to any factory overrides based on the context provided by the
  // ~parent~'s full name. The ~contxt~ argument, if supplied, supersedes the
  // ~parent~'s context. The new instance will have the given leaf ~name~,
  // if provided.

  // @uvm-ieee 1800.2-2020 auto 8.2.4.2.4
  static T create(string name="", uvm_component parent=null,
		  string contxt="") {
    return common_type.create(name, parent, contxt);
  }


  // Function -- NODOCS -- set_type_override
  //
  // Configures the factory to create an object of the type represented by
  // ~override_type~ whenever a request is made to create an object of the type
  // represented by this proxy, provided no instance override applies. The
  // original type, ~T~, is typically a super class of the override type.

  // @uvm-ieee 1800.2-2020 auto 8.2.4.2.5
  static void set_type_override(uvm_object_wrapper override_type,
				bool replace=true) {
    common_type.set_type_override(override_type, replace);
  }


  // Function -- NODOCS -- set_inst_override
  //
  // Configures the factory to create an object of the type represented by
  // ~override_type~ whenever a request is made to create an object of the type
  // represented by this proxy, with matching instance paths. The original
  // type, ~T~, is typically a super class of the override type.
  //
  // If ~parent~ is not specified, ~inst_path~ is interpreted as an absolute
  // instance path, which enables instance overrides to be set from outside
  // component classes. If ~parent~ is specified, ~inst_path~ is interpreted
  // as being relative to the ~parent~'s hierarchical instance path, i.e.
  // ~{parent.get_full_name(),".",inst_path}~ is the instance path that is
  // registered with the override. The ~inst_path~ may contain wildcards for
  // matching against multiple contexts.

  // @uvm-ieee 1800.2-2020 auto 8.2.4.2.6
  static void set_inst_override(uvm_object_wrapper override_type,
				string inst_path,
				uvm_component parent=null) {
    common_type.set_inst_override(override_type, inst_path, parent);
  }

  // Function: set_type_alias
  // Sets a type alias for this wrapper in the default factory.
  //
  // If this wrapper is not yet registered with a factory (see <uvm_factory::register>),
  // then the alias is deferred until registration occurs.
  //
  // @uvm-contrib This API is being considered for potential contribution to 1800.2
  static bool set_type_alias(string alias_name) {
    common_type.set_type_alias(alias_name);
    return true;
  }

  // @uvm-ieee 1800.2-2020 auto 8.2.4.2.7
  override void initialize() {
    common_type common = common_type.get();
    common.initialize();
  }
}

// Class: uvm_abstract_component_registry#(T,Tname)
// Implementation of uvm_abstract_component_registry#(T,Tname), as defined by section
// 8.2.5.1.1 of 1800.2-2020.

// @uvm-ieee 1800.2-2020 auto 8.2.5.1.1
template uvm_abstract_component_registry(T, bool NAMED=true)
{
  import std.traits: fullyQualifiedName;
  static if (NAMED)
    alias uvm_abstract_component_registry = uvm_abstract_component_registry!(T, fullyQualifiedName!T);
  else alias uvm_abstract_component_registry = uvm_abstract_component_registry!(T, "<unknown>");
}

class uvm_abstract_component_registry(T, string Tname):
  uvm_object_wrapper
{
  import uvm.base.uvm_component: uvm_component;
  alias this_type = uvm_abstract_component_registry!(T, Tname);
  alias common_type =
    uvm_registry_common!(this_type, uvm_registry_component_creator, T, Tname);

  // Function -- NODOCS -- create_component
  //
  // Creates a component of type T having the provided ~name~ and ~parent~.
  // This is an override of the method in <uvm_object_wrapper>. It is
  // called by the factory after determining the type of object to create.
  // You should not call this method directly. Call <create> instead.

  // @uvm-ieee 1800.2-2020 auto 8.2.5.1.2
  override uvm_component create_component (string name,
					   uvm_component parent) {
    import std.string: format;
    import uvm.base.uvm_globals: uvm_error;
    uvm_error("UVM/ABST_RGTRY/CREATE_ABSTRACT_CMPNT",
	      format("Cannot create an instance of abstract class %s" ~
		     " (with name %s and parent %s). Check for missing" ~
		     " factory overrides for %s.", this.get_type_name(),
		     name, parent.get_full_name(), this.get_type_name()));
    return null;
  }

  static string type_name() {
    return common_type.type_name();
  }

  // Function -- NODOCS -- get_type_name
  //
  // Returns the value given by the string parameter, ~Tname~. This method
  // overrides the method in <uvm_object_wrapper>.

  override string get_type_name() {
    common_type common = common_type.get();
    return common.get_type_name();
  }


  // Function -- NODOCS -- get
  //
  // Returns the singleton instance of this type. Type-based factory operation
  // depends on there being a single proxy instance for each registered type.

  static class uvm_scope: uvm_scope_base
  {
    @uvm_public_sync
    this_type _m_inst;
  }
    
  mixin (uvm_scope_sync_string);
  
  static this_type get() {
    synchronized (_uvm_scope_inst) {
      if (_uvm_scope_inst._m_inst is null) {
	_uvm_scope_inst._m_inst = new this_type();
      }
      return _uvm_scope_inst._m_inst;
    }
  }

  // Function -- NODOCS -- create
  //
  // Returns an instance of the component type, ~T~, represented by this proxy,
  // subject to any factory overrides based on the context provided by the
  // ~parent~'s full name. The ~contxt~ argument, if supplied, supersedes the
  // ~parent~'s context. The new instance will have the given leaf ~name~
  // and ~parent~.

  static T create(string name, uvm_component parent, string contxt="") {
    return common_type.create(name, parent, contxt);
  }


  // Function -- NODOCS -- set_type_override
  //
  // Configures the factory to create an object of the type represented by
  // ~override_type~ whenever a request is made to create an object of the type,
  // ~T~, represented by this proxy, provided no instance override applies. The
  // original type, ~T~, is typically a super class of the override type.

  static void set_type_override(uvm_object_wrapper override_type,
				bool replace=true) {
    common_type.set_type_override(override_type, replace);
  }


  // Function -- NODOCS -- set_inst_override
  //
  // Configures the factory to create a component of the type represented by
  // ~override_type~ whenever a request is made to create an object of the type,
  // ~T~, represented by this proxy,  with matching instance paths. The original
  // type, ~T~, is typically a super class of the override type.
  //
  // If ~parent~ is not specified, ~inst_path~ is interpreted as an absolute
  // instance path, which enables instance overrides to be set from outside
  // component classes. If ~parent~ is specified, ~inst_path~ is interpreted
  // as being relative to the ~parent~'s hierarchical instance path, i.e.
  // ~{parent.get_full_name(),".",inst_path}~ is the instance path that is
  // registered with the override. The ~inst_path~ may contain wildcards for
  // matching against multiple contexts.

  static void set_inst_override(uvm_object_wrapper override_type,
				string inst_path,
				uvm_component parent=null) {
    common_type.set_inst_override(override_type, inst_path, parent);
  }

  // Function: set_type_alias
  // Sets a type alias for this wrapper in the default factory.
  //
  // If this wrapper is not yet registered with a factory (see <uvm_factory.register>),
  // then the alias is deferred until registration occurs.
  //
  // @uvm-contrib This API is being considered for potential contribution to 1800.2
  static bool set_type_alias(string alias_name) {
    common_type.set_type_alias(alias_name);
    return true;
  }

  override void initialize() {
    common_type common = common_type.get();
    common.initialize();
  }
}


// Class: uvm_abstract_object_registry#(T,Tname)
// Implementation of uvm_abstract_object_registry#(T,Tname), as defined by section
// 8.2.5.2.1 of 1800.2-2020.

// @uvm-ieee 1800.2-2020 auto 8.2.5.2.1
template uvm_abstract_object_registry(T, bool NAMED=true)
{
  import std.traits: fullyQualifiedName;
  static if (NAMED)
    alias uvm_abstract_object_registry = uvm_abstract_object_registry!(T, fullyQualifiedName!T);
  else alias uvm_abstract_object_registry = uvm_abstract_object_registry!(T, "<unknown>");
}

class uvm_abstract_object_registry(T, string Tname):
  uvm_object_wrapper
{
  import uvm.base.uvm_component: uvm_component;
  alias this_type = uvm_abstract_object_registry!(T, Tname);
  alias common_type =
    uvm_registry_common!(this_type, uvm_registry_object_creator, T, Tname);

  // Function -- NODOCS -- create_object
  //
  // Creates an object of type ~T~ and returns it as a handle to a
  // <uvm_object>. This is an override of the method in <uvm_object_wrapper>.
  // It is called by the factory after determining the type of object to create.
  // You should not call this method directly. Call <create> instead.

  // @uvm-ieee 1800.2-2020 auto 8.2.5.2.2
  override uvm_object create_object(string name="") {
    import std.string: format;
    import uvm.base.uvm_globals: uvm_error;
    uvm_error("UVM/ABST_RGTRY/CREATE_ABSTRACT_OBJ",
      format("Cannot create an instance of abstract class %s" ~
	     " (with name %s). Check for missing factory overrides" ~
	     " for %s.", this.get_type_name(), name, this.get_type_name()));
    return null;
  }

  static string type_name() {
    return common_type.type_name();
  }

  // Function -- NODOCS -- get_type_name
  //
  // Returns the value given by the string parameter, ~Tname~. This method
  // overrides the method in <uvm_object_wrapper>.

  override string get_type_name() {
    common_type common = common_type.get();
    return common.get_type_name();
  }

  // Function -- NODOCS -- get
  //
  // Returns the singleton instance of this type. Type-based factory operation
  // depends on there being a single proxy instance for each registered type.

  static class uvm_scope: uvm_scope_base
  {
    @uvm_public_sync
    this_type _m_inst;
  }
    
  mixin (uvm_scope_sync_string);
  
  static this_type get() {
    synchronized (_uvm_scope_inst) {
      if (_uvm_scope_inst._m_inst is null) {
	_uvm_scope_inst._m_inst = new this_type();
      }
      return _uvm_scope_inst._m_inst;
    }
  }


  // Function -- NODOCS -- create
  //
  // Returns an instance of the object type, ~T~, represented by this proxy,
  // subject to any factory overrides based on the context provided by the
  // ~parent~'s full name. The ~contxt~ argument, if supplied, supersedes the
  // ~parent~'s context. The new instance will have the given leaf ~name~,
  // if provided.

  static T create(string name = "", uvm_component parent = null,
		  string contxt = "") {
    return common_type.create(name, parent, contxt);
  }


  // Function -- NODOCS -- set_type_override
  //
  // Configures the factory to create an object of the type represented by
  // ~override_type~ whenever a request is made to create an object of the type
  // represented by this proxy, provided no instance override applies. The
  // original type, ~T~, is typically a super class of the override type.

  static void set_type_override(uvm_object_wrapper override_type,
				bool replace = true) {
    common_type.set_type_override(override_type, replace);
  }


  // Function -- NODOCS -- set_inst_override
  //
  // Configures the factory to create an object of the type represented by
  // ~override_type~ whenever a request is made to create an object of the type
  // represented by this proxy, with matching instance paths. The original
  // type, ~T~, is typically a super class of the override type.
  //
  // If ~parent~ is not specified, ~inst_path~ is interpreted as an absolute
  // instance path, which enables instance overrides to be set from outside
  // component classes. If ~parent~ is specified, ~inst_path~ is interpreted
  // as being relative to the ~parent~'s hierarchical instance path, i.e.
  // ~{parent.get_full_name(),".",inst_path}~ is the instance path that is
  // registered with the override. The ~inst_path~ may contain wildcards for
  // matching against multiple contexts.

  static void set_inst_override(uvm_object_wrapper override_type,
				string inst_path,
				uvm_component parent=null) {
    common_type.set_inst_override(override_type, inst_path, parent);
  }

  // Function: set_type_alias
  // Sets a type alias for this wrapper in the default factory.
  //
  // If this wrapper is not yet registered with a factory (see <uvm_factory::register>),
  // then the alias is deferred until registration occurs.
  //
  // @uvm-contrib This API is being considered for potential contribution to 1800.2
  static bool set_type_alias(string alias_name) {
    common_type.set_type_alias( alias_name );
    return true;
  }

  override void initialize() {
    common_type common = common_type.get();
    common.initialize();
  }
}


//------------------------------------------------------------------------------
//
// CLASS -- NODOCS -- uvm_registry_common #(T,Tname)
//
// This is a helper class which implements the functioanlity that is identical
// between uvm_component_registry and uvm_abstract_component_registry.
//
//------------------------------------------------------------------------------

class uvm_registry_common(Tregistry, Tcreator, Tcreated,
			  string Tname)
{
  import uvm.base.uvm_component: uvm_component;
  alias this_type = uvm_registry_common!(Tregistry,Tcreator,Tcreated,Tname);

  static class uvm_scope: uvm_scope_base
  {
    @uvm_private_sync
    string[] _m__type_aliases;
    @uvm_public_sync
    this_type _m_inst;
  }
    
  mixin (uvm_scope_sync_string);
  
  static string type_name() {
    synchronized (_uvm_scope_inst) {
      if ((Tname == "<unknown>") &&
	  (_uvm_scope_inst._m__type_aliases.length != 0)) {
        return _uvm_scope_inst._m__type_aliases[0];
      }
      return Tname;
    }
  }

  string get_type_name() {
    return type_name();
  }

  static this_type get() {
    synchronized (_uvm_scope_inst) {
      if (_uvm_scope_inst._m_inst is null) {
	_uvm_scope_inst._m_inst = new this_type();
      }
     return _uvm_scope_inst._m_inst;
    }
  }

  static Tcreated create(string name, uvm_component parent, string contxt) {
    import uvm.base.uvm_globals: uvm_report_fatal;
    import uvm.base.uvm_object_globals: uvm_verbosity;
    uvm_object obj;
    if (contxt == "" && parent !is null) {
      contxt = parent.get_full_name();
    }
    obj = Tcreator.create_by_type(Tregistry.get(), contxt, name, parent);
    Tcreated tobj = cast (Tcreated) obj;
    if (tobj is null) {
      string msg = "Factory did not return a " ~ Tcreator.base_type_name() ~
	" of type '" ~ Tregistry.type_name ~
        "'. A component of type '" ~
	(obj is null ? "null" : obj.get_type_name()) ~
        "' was returned instead. Name=" ~ name ~ " Parent=" ~
        (parent is null ? "null" : parent.get_type_name()) ~
	" contxt=" ~ contxt;
      uvm_report_fatal("FCTTYP", msg, uvm_verbosity.UVM_NONE);
    }
    return tobj;
  }

  static void set_type_override(uvm_object_wrapper override_type,
				bool replace) {
    import uvm.base.uvm_factory: uvm_factory;
    uvm_factory factory = uvm_factory.get();
    factory.set_type_override_by_type(Tregistry.get(), override_type,
				      replace);
  }

  static void set_inst_override(uvm_object_wrapper override_type,
				string inst_path,
				uvm_component parent) {
    // string full_inst_path;
    import uvm.base.uvm_factory: uvm_factory;
    uvm_factory factory = uvm_factory.get();

    if (parent !is null) {
      if (inst_path == "") {
        inst_path = parent.get_full_name();
      }
      else {
        inst_path = parent.get_full_name() ~ "." ~ inst_path;
      }
    }
    factory.set_inst_override_by_type(Tregistry.get(),
				      override_type, inst_path);
  }

  static void set_type_alias(string alias_name) {
    import std.algorithm.sorting;
    import uvm.base.uvm_factory: uvm_factory;
    synchronized (_uvm_scope_inst) {
      _uvm_scope_inst._m__type_aliases ~= alias_name;
      _uvm_scope_inst._m__type_aliases.sort();
      // if (uvm_pkg.get_core_state() != UVM_CORE_UNINITIALIZED) {
      uvm_factory factory = uvm_factory.get();
      Tregistry rgtry = Tregistry.get();
      if (factory.is_type_registered(rgtry)) {
	factory.set_type_alias(alias_name, rgtry);
      }
      // }
    }
  }

  // static function bit __deferred_init();
  //    Tregistry rgtry = Tregistry::get();
  //    // If the core is uninitialized, we defer initialization
  //    if (uvm_pkg::get_core_state() == UVM_CORE_UNINITIALIZED) begin
  // 	     uvm_pkg::uvm_deferred_init.push_back(rgtry);
  //    end
  //    // If the core is initialized, then we're static racing,
  //    // initialize immediately
  //    else begin
  // 	     rgtry.initialize();
  //    end
  //    return 1;
  // endfunction
  // local static bit m__initialized=__deferred_init();

  void initialize() {
    synchronized (_uvm_scope_inst) {
      import uvm.base.uvm_factory: uvm_factory;
      uvm_factory factory = uvm_factory.get();
      Tregistry rgtry = Tregistry.get();
      factory.register(rgtry);
      // add aliases that were set before
      // the wrapper was registered with the factory
      foreach (type_alias; _uvm_scope_inst._m__type_aliases) {
	factory.set_type_alias(type_alias, rgtry);
      }
    }
  }
}


//------------------------------------------------------------------------------
//
// The next two classes are helper classes passed as type parameters to
// uvm_registry_common.  They abstract away the function calls
// uvm_factory::create_component_by_type  and
// uvm_factory::create_object_by_type.  Choosing between the two is handled at
// compile time..
//
//------------------------------------------------------------------------------

abstract class uvm_registry_component_creator
{
  import uvm.base.uvm_component: uvm_component;
  static uvm_component create_by_type(uvm_object_wrapper obj_wrpr,
				      string contxt,
				      string name,
				      uvm_component parent) {
    import uvm.base.uvm_coreservice;
    import uvm.base.uvm_factory;
    uvm_coreservice_t cs = uvm_coreservice_t.get();
    uvm_factory factory = cs.get_factory();
    return factory.create_component_by_type(obj_wrpr, contxt, name, parent);
  }

  static string base_type_name() {
    return "component";
  }
}

abstract class uvm_registry_object_creator
{
  static uvm_object create_by_type(uvm_object_wrapper obj_wrpr,
				   string contxt,
				   string name,
				   uvm_object unused) {
    import uvm.base.uvm_coreservice;
    import uvm.base.uvm_factory;
    uvm_coreservice_t cs = uvm_coreservice_t.get();
    uvm_factory factory = cs.get_factory();
    // unused = unused;  // ... to keep linters happy.
    return factory.create_object_by_type(obj_wrpr, contxt, name);
  }

  static string base_type_name() {
    return "object";
  }
}



// Group -- NODOCS -- Usage
//
// This section describes usage for the uvm_*_registry classes.
//
// The wrapper classes are used to register lightweight proxies of objects and
// components.
//
// To register a particular component type, you need only typedef a
// specialization of its proxy class, which is typically done inside the class.
//
// For example, to register a UVM component of type ~mycomp~
//
//|  class mycomp extends uvm_component;
//|    typedef uvm_component_registry #(mycomp,"mycomp") type_id;
//|  endclass
//
// However, because of differences between simulators, it is necessary to use a
// macro to ensure vendor interoperability with factory registration. To
// register a UVM component of type ~mycomp~ in a vendor-independent way, you
// would write instead:
//
//|  class mycomp extends uvm_component;
//|    `uvm_component_utils(mycomp)
//|    ...
//|  endclass
//
// The <`uvm_component_utils> macro is for non-parameterized classes. In this
// example, the typedef underlying the macro specifies the ~Tname~
// parameter as "mycomp", and ~mycomp~'s get_type_name() is defined to return
// the same. With ~Tname~ defined, you can use the factory's name-based methods to
// set overrides and create objects and components of non-parameterized types.
//
// For parameterized types, the type name changes with each specialization, so
// you cannot specify a ~Tname~ inside a parameterized class and get the behavior
// you want; the same type name string would be registered for all
// specializations of the class! (The factory would produce warnings for each
// specialization beyond the first.) To avoid the warnings and simulator
// interoperability issues with parameterized classes, you must register
// parameterized classes with a different macro.
//
// For example, to register a UVM component of type driver #(T), you
// would write:
//
//|  class driver #(type T=int) extends uvm_component;
//|    `uvm_component_param_utils(driver #(T))
//|    ...
//|  endclass
//
// The <`uvm_component_param_utils> and <`uvm_object_param_utils> macros are used
// to register parameterized classes with the factory. Unlike the non-param
// versions, these macros do not specify the ~Tname~ parameter in the underlying
// uvm_component_registry typedef, and they do not define the get_type_name
// method for the user class. Consequently, you will not be able to use the
// factory's name-based methods for parameterized classes.
//
// The primary purpose for adding the factory's type-based methods was to
// accommodate registration of parameterized types and eliminate the many sources
// of errors associated with string-based factory usage. Thus, use of name-based
// lookup in <uvm_factory> is no longer recommended.

