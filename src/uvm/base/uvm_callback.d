//----------------------------------------------------------------------
//   Copyright 2007-2011 Mentor Graphics Corporation
//   Copyright 2007-2010 Cadence Design Systems, Inc.
//   Copyright 2010-2011 Synopsys, Inc.
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
//----------------------------------------------------------------------

// `include "uvm_macros.svh"

// `ifndef UVM_CALLBACK_SVH
// `define UVM_CALLBACK_SVH

//------------------------------------------------------------------------------
// Title: Callbacks Classes
//
// This section defines the classes used for callback registration, management,
// and user-defined callbacks.
//------------------------------------------------------------------------------

// typedef class uvm_root;
// typedef class uvm_callback;
// typedef class uvm_callbacks_base;


//------------------------------------------------------------------------------
// CLASS: uvm_callback
//
// The ~uvm_callback~ class is the base class for user-defined callback classes.
// Typically, the component developer defines an application-specific callback
// class that extends from this class. In it, he defines one or more virtual
// methods, called a ~callback interface~, that represent the hooks available
// for user override.
//
// Methods intended for optional override should not be declared ~pure.~ Usually,
// all the callback methods are defined with empty implementations so users have
// the option of overriding any or all of them.
//
// The prototypes for each hook method are completely application specific with
// no restrictions.
//------------------------------------------------------------------------------

module uvm.base.uvm_callback;

import uvm.meta.misc;
import uvm.base.uvm_misc;
import uvm.base.uvm_report_object;
import uvm.base.uvm_object_globals;
import uvm.base.uvm_globals;
import uvm.base.uvm_object;
import uvm.base.uvm_pool;
import uvm.base.uvm_queue;
import uvm.base.uvm_root;
import uvm.base.uvm_once;
import uvm.base.uvm_entity;
import uvm.base.uvm_component;
import uvm.base.uvm_coreservice;
import uvm.meta.mcd;
import uvm.meta.meta;

import esdl.data.queue;
import esdl.data.sync;

import std.string: format;
import std.conv: to;

//------------------------------------------------------------------------------
// Class - uvm_callbacks_base
//
// Base class singleton that holds generic queues for all instance
// specific objects. This is an internal class. This class contains a
// global pool that has all of the instance specific callback queues in it.
// All of the typewide callback queues live in the derivative class
// uvm_typed_callbacks#(T). This is not a user visible class.
//
// This class holds the class inheritance hierarchy information
// (super types and derivative types).
//
// Note, all derivative uvm_callbacks#() class singletons access this
// global m_pool object in order to get access to their specific
// instance queue.
//------------------------------------------------------------------------------

class uvm_callbacks_base: uvm_object
{

  static class uvm_once: uvm_once_base
  {
    @uvm_public_sync
    private bool _m_tracing = true;
    @uvm_immutable_sync
    private uvm_callbacks_base _m_b_inst;
    @uvm_immutable_sync
    private uvm_pool!(uvm_object, uvm_queue!(uvm_callback)) _m_pool;
    @uvm_immutable_sync
    private uvm_pool!(ClassInfo, uvm_callbacks_base) _typeid_map;
    this() {
      synchronized(this) {
	_m_b_inst = new uvm_callbacks_base;
	_m_pool = new uvm_pool!(uvm_object, uvm_queue!(uvm_callback));
	_typeid_map = new uvm_pool!(ClassInfo, uvm_callbacks_base);
      }
    }
  };

  mixin(uvm_once_sync_string);
  mixin(uvm_sync_string);

  alias this_type = uvm_callbacks_base;

  // Used for checking interface -- we dont have that in Vlang
  //Type checking interface
  // private this_type[] _m_this_types;     //one to many T->T/CB
  // private void add_this_type(this_type type) {
  //   synchronized(this) {
  //     _m_this_types ~= type;
  //   }
  // }

  @uvm_private_sync
  private ClassInfo _m_super_type;    //one to one relation

  private ClassInfo[] _m_derived_types; //one to many relation
  private void add_derived_type(ClassInfo type) {
    synchronized(this) {
      _m_derived_types ~= type;
    }
  }

  bool m_am_i_a(uvm_object obj) {
    return false;
  }

  bool m_is_for_me(uvm_callback cb) {
    return false;
  }

  // This function is not implemented for Vlang. No check is made if a
  // particular type is registtered as a callback for the given
  // type. Actually such checks are not required in Vlang since the
  // Callback mechanism is mixin template based and has better
  // semantics. Badically registration is done using mixin template
  // and the callbacks add mechanism is enabled only when the mixin
  // template has been instantiated.

  // bool m_is_registered(uvm_object obj, uvm_callback cb) {
  //   return false;
  // }

  uvm_queue!uvm_callback m_get_tw_cb_q(uvm_object obj) {
    return null;
  }

  void m_add_tw_cbs(uvm_callback cb, uvm_apprepend ordering) { }

  bool m_delete_tw_cbs(uvm_callback cb) {
    return false;
  }


  // Not required for Vlang -- see the comment for m_is_registered
  // above

  //Check registration. To test registration, start at this class and
  //work down the class hierarchy. If any class returns true then
  //the pair is legal.
  // bool check_registration(uvm_object obj, uvm_callback cb) {
  //   synchronized(this) {
  //     if (m_is_registered(obj, cb)) {
  //	return true;
  //     }
  //     // Need to look at all possible T/CB pairs of this type
  //     foreach(t; _m_this_types) {
  //	if(m_b_inst !is t && t.m_is_registered(obj, cb)) {
  //	  return true;
  //	}
  //     }
  //     if(obj is null) {
  //	foreach(t; _m_derived_types) {
  //	  this_type dt = typeid_map[t];
  //	  if(dt !is null && dt.check_registration(null, cb)) {
  //	    return true;
  //	  }
  //	}
  //     }
  //     return false;
  //   }
  // }
}



//------------------------------------------------------------------------------
//
// Class - uvm_typed_callbacks#(T)
//
//------------------------------------------------------------------------------
//
// Another internal class. This contains the queue of typewide
// callbacks. It also contains some of the public interface methods,
// but those methods are accessed via the uvm_callbacks#() class
// so they are documented in that class even though the implementation
// is in this class.
//
// The <add>, <delete>, and <display> methods are implemented in this class.

class uvm_typed_callbacks(T = uvm_object): uvm_callbacks_base
{
  mixin(uvm_sync_string);

  @uvm_immutable_sync
  uvm_queue!uvm_callback _m_tw_cb_q;
  enum string m_typename = qualifiedTypeName!T;

  alias this_type  = uvm_typed_callbacks!(T);
  alias super_type = uvm_callbacks_base;

  //The actual global object from the derivative class. Note that this is
  //just a reference to the object that is generated in the derived class.
  __gshared private this_type[uvm_object] _m_t_inst_pool;
  // getter
  static this_type m_t_inst() {
    uvm_coreservice_t cs = uvm_coreservice_t.get();
    uvm_root top = cs.get_root();
    synchronized(typeid(this_type)) {
      if(top in _m_t_inst_pool) {
	return _m_t_inst_pool[top];
      }
      else return null;
    }
  }
  // setter
  static void m_t_inst(this_type inst) {
    uvm_coreservice_t cs = uvm_coreservice_t.get();
    uvm_root top = cs.get_root();
    synchronized(typeid(this_type)) {
      _m_t_inst_pool[top] = inst;
    }
  }

  this() {
    synchronized(this) {
      _m_tw_cb_q = new uvm_queue!uvm_callback("uvm_callback/typewide_queue");
    }
  }

  static this_type m_initialize() {
    synchronized(once) {
      if(m_t_inst is null) {
	// super_type.m_initialize taken care of by once constructor
	// super_type.m_initialize();
	m_t_inst = new this_type();

	// This is taken care of in the "this" method of m_t_inst. That way it
	// becomes effectively immutable
	// synchronized(m_t_inst) {
	//	m_t_inst.m_tw_cb_q = new uvm_queue!uvm_callback("uvm_callback/typewide_queue");
	// }
      }
      return m_t_inst;
    }
  }

  //Type checking interface: is given ~obj~ of type T?
  override bool m_am_i_a(uvm_object obj) {
    if (obj is null) return true;
    return ((cast(T) obj) !is null);
  }

  //Getting the typewide queue
  override  uvm_queue!uvm_callback m_get_tw_cb_q(uvm_object obj) {
    synchronized(this) {
      uvm_queue!uvm_callback m_get_tw_cb_q_;
      if(m_am_i_a(obj)) {
	foreach(derived_type; _m_derived_types) {
	  super_type dt = typeid_map[derived_type];
	  if(dt !is null && dt !is this) {
	    m_get_tw_cb_q_ = dt.m_get_tw_cb_q(obj);
	    if(m_get_tw_cb_q_ !is null) {
	      return m_get_tw_cb_q_;
	    }
	  }
	}
	return /*m_t_inst.*/ m_tw_cb_q;
      }
      else {
	return null;
      }
    }
  }

  // no shared variable -- therefor no synchronized lock is required
  static ptrdiff_t m_cb_find(uvm_queue!uvm_callback q, uvm_callback cb) {
    foreach(i, qc; q) {
      if(qc is cb) {
	return i;
      }
    }
    return -1;
  }

  // no shared variable -- therefor no synchronized lock is required
  static bool m_cb_find_name(uvm_queue!uvm_callback q,
			     string name, string where) {
    foreach(cb; q) {
      if(cb.get_name() == name) {
	uvm_warning("UVM/CB/NAM/SAM", "A callback named \"" ~ name ~
		    "\" is already registered with " ~ where);
	return true;
      }
    }
    return false;
  }

  //For a typewide callback, need to add to derivative types as well.
  override void m_add_tw_cbs(uvm_callback cb, uvm_apprepend ordering) {
    synchronized(this) {
      bool warned;
      if(m_cb_find(/*m_t_inst.*/m_tw_cb_q, cb) == -1) {
	warned = m_cb_find_name(/*m_t_inst.*/m_tw_cb_q, cb.get_name(), "type");
	if(ordering == uvm_apprepend.UVM_APPEND) {
	  /*m_t_inst.*/m_tw_cb_q.push_back(cb);
	}
	else {
	  /*m_t_inst.*/m_tw_cb_q.push_front(cb);
	}
      }
      foreach(obj, unused; /*m_t_inst.*/m_pool) {
	T me = cast(T) obj;
	if(me !is null) {
	  uvm_queue!(uvm_callback) q = /*m_t_inst.*/m_pool.get(obj);
	  if(q is null) {
	    q = new uvm_queue!uvm_callback("uvm_callback/m_add_tw_cbs/q");
	    /*m_t_inst.*/m_pool.add(obj, q);
	  }
	  if(m_cb_find(q, cb) == -1) {
	    if (!warned) {
	      m_cb_find_name(q, cb.get_name(), "object instance " ~
			     me.get_full_name());
	    }
	    if(ordering == uvm_apprepend.UVM_APPEND) {
	      q.push_back(cb);
	    }
	    else {
	      q.push_front(cb);
	    }
	  }
	}
      }
      foreach(derived_type; _m_derived_types) {
	super_type cb_pair = typeid_map[derived_type];
	if(cb_pair !is this) {
	  cb_pair.m_add_tw_cbs(cb, ordering);
	}
      }
    }
  }


  //For a typewide callback, need to remove from derivative types as well.
  override bool m_delete_tw_cbs(uvm_callback cb) {
    synchronized(this) {
      bool m_delete_tw_cbs_;
      ptrdiff_t pos = m_cb_find(/*m_t_inst.*/m_tw_cb_q, cb);
      if(pos != -1) {
	/*m_t_inst.*/m_tw_cb_q.remove(pos);
	m_delete_tw_cbs_ = true;
      }
      foreach(obj, unused; /*m_t_inst.*/m_pool) {
	uvm_queue!(uvm_callback) q = /*m_t_inst.*/m_pool.get(obj);
	if(q is null) {
	  q = new uvm_queue!(uvm_callback)("uvm_callback/m_delete_tw_cbs/q");
	  /*m_t_inst.*/m_pool.add(obj, q);
	}
	pos = m_cb_find(q, cb);
	if(pos != -1) {
	  q.remove(pos);
	  m_delete_tw_cbs_ = true;
	}
      }
      foreach(derived_type; _m_derived_types) {
	super_type cb_pair = typeid_map[derived_type];
	if(cb_pair !is this) {
	  m_delete_tw_cbs_ |= cb_pair.m_delete_tw_cbs(cb);
	}
      }
      return m_delete_tw_cbs_;
    }
  }


  static void display(T obj=null) {
    string[] cbq;
    string[] inst_q;
    string[] mode_q;
    uvm_object bobj = obj;
    string qs;

    string tname, str;

    size_t max_cb_name, max_inst_name;

    m_tracing = false; //don't allow tracing during display

    if(m_typename != "") {
      tname = m_typename;
    }
    else if(obj !is null) {
      tname = obj.get_type_name();
    }
    else {
      tname = "*";
    }

    uvm_queue!(uvm_callback) q = m_t_inst.m_tw_cb_q;
    foreach(cb; q) {
      cbq ~= cb.get_name();
      inst_q ~= "(*)";
      if(cb.is_enabled()) {
	mode_q ~= "ON";
      }
      else {
	mode_q ~= "OFF";
      }

      str = cb.get_name();
      max_cb_name = max_cb_name > str.length ? max_cb_name : str.length;
      str = "(*)";
      max_inst_name = max_inst_name > str.length ? max_inst_name : str.length;
    }

    if(m_t_inst.m_tw_cb_q.size() != 0) {
      qs ~= format("Registered callbacks for all instances of %s\n", tname);
      qs ~= "---------------------------------------------------------------\n";
    }

    if(obj is null) {
      foreach(bobj, unused; m_pool) {
	T me = cast(T) bobj;
	if(me !is null) {
	  if(qs.length == 0) {
	    qs ~= format("Registered callbacks for all instances of %s\n", tname);
	    qs ~= "---------------------------------------------------------------\n";
	  }
	  q = m_pool.get(bobj);
	  if (q is null) {
	    q = new uvm_queue!(uvm_callback)("uvm_callback/display/q");
	    m_pool.add(bobj, q);
	  }
	  foreach(cb; q) {
	    cbq ~= cb.get_name();
	    inst_q ~= bobj.get_full_name();
	    if(cb.is_enabled()) {
	      mode_q ~= "ON";
	    }
	    else {
	      mode_q ~= "OFF";
	    }

	    str = cb.get_name();
	    max_cb_name = max_cb_name > str.length ? max_cb_name : str.length;
	    str = bobj.get_full_name();
	    max_inst_name = max_inst_name > str.length ? max_inst_name : str.length;
	  }
	}
      } // while (m_pool.next(bobj));
      if(qs.length == 0) {
	qs ~= format("No callbacks registered for any instances of type %s\n", tname);
      }
    }
    else {
      if(bobj in m_pool || m_t_inst.m_tw_cb_q.size() != 0) {
	qs ~= format("Registered callbacks for instance %s of %s\n",
		     obj.get_full_name(), tname);
	qs ~= "---------------------------------------------------------------\n";
      }
      if(bobj in m_pool) {
	q = m_pool.get(bobj);
	if(q is null) {
	  q = new uvm_queue!(uvm_callback)("uvm_callback/display/q2");
	  m_pool.add(bobj, q);
	}
	foreach(cb; q) {
	  cbq ~= cb.get_name();
	  inst_q ~= bobj.get_full_name();
	  if(cb.is_enabled()) {
	    mode_q ~= "ON";
	  }
	  else {
	    mode_q ~= "OFF";
	  }

	  str = cb.get_name();
	  max_cb_name = max_cb_name > str.length ? max_cb_name : str.length;
	  str = bobj.get_full_name();
	  max_inst_name = max_inst_name > str.length ? max_inst_name : str.length;
	}
      }
    }
    if(cbq.length == 0) {
      if(obj is null) {
	str = "*";
      }
      else {
	str = obj.get_full_name();
      }
      qs ~= format("No callbacks registered for instance %s of type %s\n",
		   str, tname);
    }

    foreach(i, c; cbq) {
      enum string blanks = "                             ";
      qs ~= format("%s  %s %s on %s  %s\n", c,
		   blanks[0..max_cb_name-cbq[i].length], inst_q[i],
		   blanks[0..max_inst_name - inst_q[i].length], mode_q[i]);
    }
    uvm_info("UVM/CB/DISPLAY", qs, UVM_NONE);

    m_tracing = true; //allow tracing to be resumed
  }
};


//------------------------------------------------------------------------------
//
// CLASS: uvm_callbacks #(T,CB)
//
// The ~uvm_callbacks~ class provides a base class for implementing callbacks,
// which are typically used to modify or augment component behavior without
// changing the component class. To work effectively, the developer of the
// component class defines a set of "hook" methods that enable users to
// customize certain behaviors of the component in a manner that is controlled
// by the component developer. The integrity of the component's overall behavior
// is intact, while still allowing certain customizable actions by the user.
//
// To enable compile-time type-safety, the class is parameterized on both the
// user-defined callback interface implementation as well as the object type
// associated with the callback. The object type-callback type pair are
// associated together using the <`uvm_register_cb> macro to define
// a valid pairing; valid pairings are checked when a user attempts to add
// a callback to an object.
//
// To provide the most flexibility for end-user customization and reuse, it
// is recommended that the component developer also define a corresponding set
// of virtual method hooks in the component itself. This affords users the ability
// to customize via inheritance/factory overrides as well as callback object
// registration. The implementation of each virtual method would provide the
// default traversal algorithm for the particular callback being called. Being
// virtual, users can define subtypes that override the default algorithm,
// perform tasks before and/or after calling super.<method> to execute any
// registered callbacks, or to not call the base implementation, effectively
// disabling that particular hook. A demonstration of this methodology is
// provided in an example included in the kit.
//------------------------------------------------------------------------------


class uvm_callbacks (T=uvm_object, CB=uvm_callback): uvm_typed_callbacks!T
{
  mixin(uvm_sync_string);
  // Parameter: T
  //
  // This type parameter specifies the base object type with which the
  // <CB> callback objects will be registered. This object must be
  // a derivative of ~uvm_object~.

  // Parameter: CB
  //
  // This type parameter specifies the base callback type that will be
  // managed by this callback class. The callback type is typically a
  // interface class, which defines one or more virtual method prototypes
  // that users can override in subtypes. This type must be a derivative
  // of <uvm_callback>.

  alias super_type = uvm_typed_callbacks!T;
  alias this_type  = uvm_callbacks!(T, CB);


  // Singleton instance is used for type checking
  __gshared this_type[uvm_object] _m_inst_pool;
  // getter
  static this_type m_inst() {
    uvm_root top = uvm_root.get();
    synchronized(typeid(this_type)) {
      if(top in _m_inst_pool) {
	return _m_inst_pool[top];
      }
      else return null;
    }
  }
  // setter
  static void m_inst(this_type inst) {
    uvm_root top = uvm_root.get();
    synchronized(typeid(this_type)) {
      _m_inst_pool[top] = inst;
    }
  }


  enum string m_typename = qualifiedTypeName!T;

  // not used anywhere -- defined in SV version
  // enum string m_cb_typename = qualifiedTypeName!CB;

  alias BT = uvm_callbacks!(T, uvm_callback); // base type

  // @uvm_private_sync bool _m_registered;

  // get
  // ---

  static this_type get() {
    if (m_inst is null) {
      super_type.m_initialize();

      m_inst = new this_type();

      static if(is(CB == uvm_callback)) {
	// The base inst in the super class gets set to this base inst
	m_t_inst = m_inst;
	typeid_map[typeid(T)] = m_inst;
      }

      // Used for checking interface -- we dont have that in Vlang
      // else {
      // 	auto base_inst = BT.get();
      // 	base_inst.add_this_type(m_inst);
      // }

      if (m_inst is null) {
	uvm_fatal("CB/INTERNAL", "get(): m_inst is null");
      }
    }
    return m_inst;
  }


  // m_register_pair
  // -------------
  // Register valid callback type

  // static bool m_register_pair() {
  //   this_type inst = get();
  //   inst.m_registered = true;
  //   return true;
  // }

  // calls m_register_pair only if uvm_root is not null
  // static bool m_register_pair_if_uvm() {
  //   this_type inst = get();
  //   inst.m_registered = true;
  //   return true;
  // }

  // override bool m_is_registered(uvm_object obj, uvm_callback cb) {
  //   synchronized(this) {
  //     if(m_is_for_me(cb) && m_am_i_a(obj)) {
  //	return m_registered;
  //     }
  //     // SV version does not have the following line
  //     // as a result m_is_registered default value false is returned
  //     return false;
  //   }
  // }

  //Does type check to see if the callback is valid for this type
  override bool m_is_for_me(uvm_callback cb) {
    synchronized(this) {
      // CB this_cb;
      auto this_cb = cast(CB) cb;
      return(this_cb !is null);
    }
  }

  // Group: Add/delete interface

  // Function: add
  //
  // Registers the given callback object, ~cb~, with the given
  // ~obj~ handle. The ~obj~ handle can be ~null~, which allows
  // registration of callbacks without an object context. If
  // ~ordering~ is UVM_APPEND (default), the callback will be executed
  // after previously added callbacks, else  the callback
  // will be executed ahead of previously added callbacks. The ~cb~
  // is the callback handle; it must be ~non-null~, and if the callback
  // has already been added to the object instance then a warning is
  // issued. Note that the CB parameter is optional. For example, the
  // following are equivalent:
  //
  //| uvm_callbacks!(my_comp).add(comp_a, cb);
  //| uvm_callbacks!(my_comp, my_callback).add(comp_a, cb);

  static void add(T obj, uvm_callback cb,
		  uvm_apprepend ordering = uvm_apprepend.UVM_APPEND) {
    string nm, tnm;

    get();

    if (cb is null) {
      if (obj is null) {
	nm = "(*)";
      }
      else {
	nm = obj.get_full_name();
      }

      if (BT.m_typename != "") {
	tnm = BT.m_typename;
      }
      else if (obj !is null) {
	tnm = obj.get_type_name();
      }
      else {
	tnm = "uvm_object";
      }

      uvm_report_error("CBUNREG",
		       "Null callback object cannot be registered with object " ~
		       nm ~ " (" ~ tnm ~ ")", UVM_NONE);
      return;
    }

    // if (! BT.get().check_registration(obj, cb)) {
    //   if (obj is null) {
    //	nm = "(*)";
    //   }
    //   else {
    //	nm = obj.get_full_name();
    //   }

    //   if (BT.m_typename != "") {
    //	tnm = BT.m_typename;
    //   }
    //   else if(obj !is null) {
    //	tnm = obj.get_type_name();
    //   }
    //   else {
    //	tnm = "uvm_object";
    //   }

    //   uvm_report_warning("CBUNREG",
    //			 "Callback " ~ cb.get_name() ~
    //			 " cannot be registered with object " ~
    //			 nm ~ " because callback type " ~ cb.get_type_name() ~
    //			 " is not registered with object type " ~ tnm, UVM_NONE);
    //   // return statement missing in SV version
    //   return;
    // }

    if(obj is null) {

      if (m_cb_find(m_t_inst.m_tw_cb_q, cb) != -1) {

	if (BT.m_typename != "") {
	  tnm = BT.m_typename;
	}
	else {
	  tnm = "uvm_object";
	}

	uvm_report_warning("CBPREG",
			   "Callback object " ~ cb.get_name() ~
			   " is already registered with type " ~ tnm, UVM_NONE);
      }
      else {
	uvm_cb_trace_noobj(cb,
			   format("Add (%s) typewide callback %0s for type %s",
				  ordering.to!string, cb.get_name(),
				  BT.m_typename));
	m_t_inst.m_add_tw_cbs(cb, ordering);
      }
    }
    else {
      uvm_cb_trace_noobj(cb,
			 format("Add (%s) callback %0s to object %0s ",
				ordering.to!string, cb.get_name(),
				obj.get_full_name()));
      uvm_queue!(uvm_callback) q = m_pool.get(obj);
      if (q is null) {
	q = new uvm_queue!(uvm_callback)("uvm_callback/add/q");
	m_pool.add(obj, q);
      }
      if(q.size() == 0) {
	// Need to make sure that registered report catchers are added. This
	// way users don't need to set up uvm_report_object as a super type.
	uvm_report_object o = cast(uvm_report_object) obj;

	if(o !is null) {
	  uvm_callbacks!(uvm_report_object, uvm_callback).get();
	  uvm_queue!(uvm_callback) qr =
	    uvm_callbacks!(uvm_report_object, uvm_callback).m_t_inst.m_tw_cb_q;
	  foreach(r; qr) q.push_back(r);
	}
	foreach(cb; m_t_inst.m_tw_cb_q) {
	  q.push_back(cb);
	}
      }

      //check if already exists in the queue
      if(m_cb_find(q, cb) !is -1) {
	uvm_report_warning("CBPREG", "Callback object " ~ cb.get_name() ~
			   " is already registered" ~ " with object " ~
			   obj.get_full_name(), UVM_NONE);
      }
      else {
	m_cb_find_name(q, cb.get_name(), "object instance " ~
		       obj.get_full_name());
	if(ordering == uvm_apprepend.UVM_APPEND) {
	  q.push_back(cb);
	}
	else {
	  q.push_front(cb);
	}
      }
    }
  }



  // Function: add_by_name
  //
  // Registers the given callback object, ~cb~, with one or more uvm_components.
  // The components must already exist and must be type T or a derivative. As
  // with <add> the CB parameter is optional. ~root~ specifies the location in
  // the component hierarchy to start the search for ~name~. See <uvm_root.find_all>
  // for more details on searching by name.

  static void add_by_name(string name,
			  uvm_callback cb,
			  uvm_component root,
			  uvm_apprepend ordering=uvm_apprepend.UVM_APPEND) {

    get();

    uvm_component[] cq;
    uvm_coreservice_t cs = uvm_coreservice_t.get();
    uvm_root top = cs.get_root();

    if(cb is null) {
      uvm_report_error("CBUNREG", "Null callback object cannot be registered"
		       " with object(s) " ~ name, UVM_NONE);
      return;
    }
    uvm_cb_trace_noobj(cb, format("Add (%s) callback %0s by name to object(s)"
				  " %0s ", ordering, cb.get_name(), name));
    top.find_all(name, cq, root);
    if(cq.length == 0) {
      uvm_report_warning("CBNOMTC", "add_by_name failed to find any components"
			 " matching the name " ~ name ~ " ~ callback " ~
			 cb.get_name() ~ " will not be registered.", UVM_NONE);
    }
    foreach(c; cq) {
      T t = cast(T) c;
      if(c !is null) {
	add(t, cb, ordering);
      }
    }
  }


  // Function: delete
  //
  // Deletes the given callback object, ~cb~, from the queue associated with
  //  the given ~obj~ handle. The ~obj~ handle can be ~null~, which allows
  // de-registration of callbacks without an object context.
  // The ~cb~ is the callback handle; it must be non-~null~, and if the callback
  // has already been removed from the object instance then a warning is
  // issued. Note that the CB parameter is optional. For example, the
  // following are equivalent:
  //
  //| uvm_callbacks!(my_comp).delete(comp_a, cb);
  //| uvm_callbacks!(my_comp, my_callback).delete(comp_a, cb);

  static void remove(T obj, uvm_callback cb) {
    uvm_object b_obj = obj;	// God knows why b_obj is declared, could we not do with obj itself
    bool found;
    get();
    if(obj is null) {
      uvm_cb_trace_noobj(cb, format("Delete typewide callback %0s for type %s",
				    cb.get_name(), BT.m_typename));
      found = m_t_inst.m_delete_tw_cbs(cb);
    }
    else {
      uvm_cb_trace_noobj(cb, format("Delete callback %0s from object %0s ",
				    cb.get_name(), obj.get_full_name()));
      uvm_queue!(uvm_callback) q = m_pool.get(b_obj);
      ptrdiff_t pos = m_cb_find(q, cb);
      if(pos != -1) {
	q.remove(pos);
	found = true;
      }
    }
    if(!found) {
      string nm;
      if(obj is null) nm = "(*)"; else nm = obj.get_full_name();
      uvm_report_warning("CBUNREG", "Callback " ~ cb.get_name() ~ " cannot be removed from object " ~
			 nm ~ " because it is not currently registered to that object.", UVM_NONE);
    }
  }


  // Function: delete_by_name
  //
  // Removes the given callback object, ~cb~, associated with one or more
  // uvm_component callback queues. As with <delete> the CB parameter is
  // optional. ~root~ specifies the location in the component hierarchy to start
  // the search for ~name~. See <uvm_root.find_all> for more details on searching
  // by name.

  static void delete_by_name(string name, uvm_callback cb,
			     uvm_component root) {
    get();

    uvm_coreservice_t cs = uvm_coreservice_t.get();
    uvm_root top = cs.get_root();

    uvm_cb_trace_noobj(cb, format("Delete callback %0s by name from object(s) %0s ",
				  cb.get_name(), name));
    uvm_component[] cq;
    top.find_all(name, cq, root);
    if(cq.length == 0) {
      uvm_report_warning("CBNOMTC", "delete_by_name failed to find any components matching the name " ~
			 name ~ " ~ callback " ~ cb.get_name() ~ " will not be unregistered.", UVM_NONE);
    }
    foreach(c; cq) {
      T t = cast(T) c;
      if(t !is null) {
	remove(t, cb);
      }
    }
  }


  //--------------------------
  // Group: Iterator Interface
  //--------------------------
  //
  // This set of functions provide an iterator interface for callback queues. A facade
  // class, <uvm_callback_iter> is also available, and is the generally preferred way to
  // iterate over callback queues.

  static void m_get_q (ref uvm_queue!(uvm_callback) q, T obj) {
    if(obj !in m_pool) { //no instance specific
      q = (obj is null) ? m_t_inst.m_tw_cb_q : m_t_inst.m_get_tw_cb_q(obj);
    }
    else {
      q = m_pool.get(obj);
      if(q is null) {
	q = new uvm_queue!(uvm_callback)("uvm_callback/m_get_q/q");
	m_pool.add(obj, q);
      }
    }
  }

  static uvm_queue!(uvm_callback) m_get_q (T obj) {
    uvm_queue!(uvm_callback) q = new uvm_queue!(uvm_callback)("uvm_callback/m_get_q/q");
    m_get_q(q, obj);
    return q;
  }

  // FIXME:
  // Add operator opApply for uvm_callbacks, so the we can efficiently
  // call stuff like foreach directly on a uvm_callbacks class instance
  // But I need to check whether the operator can be static

  // Function: get_all
  // Return a list of all callbacks enabled or disabled

  static CB[] get_all(T obj) {
    CB[] cbs;
    get();
    auto q = m_get_q(obj);
    foreach(c; q) {
      CB cb = cast(CB) c;
      if(cb !is null) {
	cbs ~= cb;
      }
    }
    return cbs;
  }

  // Function: get_all_enabled
  // Return a list of all enabled callbacks

  static CB[] get_all_enabled(T obj) {
    CB[] cbs;
    get();
    auto q = m_get_q(obj);
    foreach(c; q) {
      CB cb = cast(CB) c;
      if(cb !is null && cb.callback_mode()) {
	cbs ~= cb;
      }
    }
    return cbs;
  }

  // Function: get_first
  //
  // Returns the first enabled callback of type CB which resides in the queue for ~obj~.
  // If ~obj~ is ~null~ then the typewide queue for T is searched. ~itr~ is the iterator;
  // it will be updated with a value that can be supplied to <get_next> to get the next
  // callback object.
  //
  // If the queue is empty then ~null~ is returned.
  //
  // The iterator class <uvm_callback_iter> may be used as an alternative, simplified,
  // iterator interface.

  static CB get_first (ref size_t itr, T obj) {
    get();
    uvm_queue!(uvm_callback) q = m_get_q(obj);
    foreach(c; q) {
      CB cb = cast(CB) c;
      if(cb !is null  && cb.callback_mode()) {
	return cb;
      }
    }
    return null;
  }

  // Function: get_last
  //
  // Returns the last enabled callback of type CB which resides in the queue for ~obj~.
  // If ~obj~ is ~null~ then the typewide queue for T is searched. ~itr~ is the iterator;
  // it will be updated with a value that can be supplied to <get_prev> to get the previous
  // callback object.
  //
  // If the queue is empty then ~null~ is returned.
  //
  // The iterator class <uvm_callback_iter> may be used as an alternative, simplified,
  // iterator interface.

  static CB get_last (ref size_t itr, T obj) {
    get();
    uvm_queue!(uvm_callback) q = m_get_q(obj);
    foreach_reverse(c; q) {
      CB cb = cast(CB) c;
      if (cb !is null && cb.callback_mode()) {
	return cb;
      }
    }
    return null;
  }

  // Function: get_next
  //
  // Returns the next enabled callback of type CB which resides in the queue for ~obj~,
  // using ~itr~ as the starting point. If ~obj~ is ~null~ then the typewide queue for T
  // is searched. ~itr~ is the iterator; it will be updated with a value that can be
  // supplied to <get_next> to get the next callback object.
  //
  // If no more callbacks exist in the queue, then ~null~ is returned. <get_next> will
  // continue to return ~null~ in this case until <get_first> or <get_last> has been used to reset
  // the iterator.
  //
  // The iterator class <uvm_callback_iter> may be used as an alternative, simplified,
  // iterator interface.

  static CB get_next (ref size_t itr, T obj) {
    get();
    uvm_queue!(uvm_callback) q = m_get_q(obj);
    for(itr = itr+1; itr<q.size(); ++itr) {
      CB cb = cast(CB) q.get(itr);
      if (cb !is null && cb.callback_mode()) {
	return cb;
      }
    }
    return null;
  }


  // Function: get_prev
  //
  // Returns the previous enabled callback of type CB which resides in the queue for ~obj~,
  // using ~itr~ as the starting point. If ~obj~ is ~null~ then the typewide queue for T
  // is searched. ~itr~ is the iterator; it will be updated with a value that can be
  // supplied to <get_prev> to get the previous callback object.
  //
  // If no more callbacks exist in the queue, then ~null~ is returned. <get_prev> will
  // continue to return ~null~ in this case until <get_first> or <get_last> has been used to reset
  // the iterator.
  //
  // The iterator class <uvm_callback_iter> may be used as an alternative, simplified,
  // iterator interface.

  static CB get_prev (ref size_t itr, T obj) {
    get();
    uvm_queue!(uvm_callback) q = m_get_q(obj);
    for(itr = itr-1; itr>= 0; --itr) {
      CB cb = cast(CB) q.get(itr);
      if(cb !is null && cb.callback_mode()) {
	return cb;
      }
    }
    return null;
  }


  //-------------
  // Group: Debug
  //-------------

  // Function: display
  //
  // This function displays callback information for ~obj~. If ~obj~ is
  // ~null~, then it displays callback information for all objects
  // of type ~T~, including typewide callbacks.

  static void display(T obj=null) {
    // For documentation purposes, need a function wrapper here.
    get();
    super_type.display(obj);
  }
}


//------------------------------------------------------------------------------
//
// Class- uvm_derived_callbacks !(T,ST,CB)
//
//------------------------------------------------------------------------------
// This type is not really expected to be used directly by the user, instead they are
// expected to use the macro `uvm_set_super_type. The sole purpose of this type is to
// allow for setting up of the derived_type/super_type mapping.
//------------------------------------------------------------------------------

class uvm_derived_callbacks (T=uvm_object, ST=uvm_object, CB=uvm_callback):
  uvm_callbacks!(T, CB)
{
  alias this_type = uvm_derived_callbacks!(T, ST, CB);
  alias this_user_type = uvm_callbacks!(T);
  alias this_super_type = uvm_callbacks!(ST);

  // Singleton instance is used for type checking
  // __gshared  this_type m_d_inst;

  // static this_type get() {
  //   synchronized {
  //     if(m_d_inst is null) {
  //	m_d_inst = new this_type;
  //     }
  //     return m_d_inst;
  //   }
  // }

  static bool register_super_type() {
    this_user_type u_inst = this_user_type.get();
    // this_type      inst = this_type.get();
    uvm_callbacks_base s_obj;

    synchronized(u_inst) {
      if(u_inst.m_super_type !is null) {
	if(u_inst.m_super_type is typeid(ST)) {
	  return true;
	}
	uvm_report_warning("CBTPREG", "Type " ~ qualifiedTypeName!T ~
			   " is already registered to super type " ~
			   qualifiedTypeName!ST ~
			   ". Ignoring attempt to register to super type " ~
			   qualifiedTypeName!ST, UVM_NONE);
	return true;
      }
      u_inst.m_super_type = typeid(ST);
      u_inst.BT.get().m_super_type = typeid(ST);
      s_obj = typeid_map[typeid(ST)];
      s_obj.add_derived_type(typeid(T));
      return true;
    }
  }
}

//------------------------------------------------------------------------------
//
// CLASS: uvm_callback_iter
//
//------------------------------------------------------------------------------
// The ~uvm_callback_iter~ class is an iterator class for iterating over
// callback queues of a specific callback type. The typical usage of
// the class is:
//
//| uvm_callback_iter!(mycomp,mycb) iter = new(this);
//| for(mycb cb = iter.first(); cb !is null; cb = iter.next())
//|    cb.dosomething();
//
// The callback iteration macros, <`uvm_do_callbacks> and
// <`uvm_do_callbacks_exit_on> provide a simple method for iterating
// callbacks and executing the callback methods.
//------------------------------------------------------------------------------

class uvm_callback_iter (T = uvm_object, CB = uvm_callback)
{
  private size_t _m_i;
  private T   _m_obj;
  private CB  _m_cb;

  // Function: new
  //
  // Creates a new callback iterator object. It is required that the object
  // context be provided.

  this(T obj) {
    synchronized(this) {
      _m_obj = obj;
    }
  }

  // Function: first
  //
  // Returns the first valid (enabled) callback of the callback type (or
  // a derivative) that is in the queue of the context object. If the
  // queue is empty then ~null~ is returned.

  CB first() {
    synchronized(this) {
      _m_cb = uvm_callbacks!(T, CB).get_first(_m_i, _m_obj);
      return _m_cb;
    }
  }

  // Function: last
  //
  // Returns the last valid (enabled) callback of the callback type (or
  // a derivative) that is in the queue of the context object. If the
  // queue is empty then ~null~ is returned.

  CB last() {
    synchronized(this) {
      _m_cb = uvm_callbacks!(T, CB).get_last(_m_i, _m_obj);
      return _m_cb;
    }
  }

  // Function: next
  //
  // Returns the next valid (enabled) callback of the callback type (or
  // a derivative) that is in the queue of the context object. If there
  // are no more valid callbacks in the queue, then ~null~ is returned.

  CB next() {
    synchronized(this) {
      _m_cb = uvm_callbacks!(T, CB).get_next(_m_i, _m_obj);
      return _m_cb;
    }
  }

  // Function: prev
  //
  // Returns the previous valid (enabled) callback of the callback type (or
  // a derivative) that is in the queue of the context object. If there
  // are no more valid callbacks in the queue, then ~null~ is returned.

  CB prev() {
    synchronized(this) {
      _m_cb = uvm_callbacks!(T, CB).get_prev(_m_i, _m_obj);
      return _m_cb;
    }
  }

  // Function: get_cb
  //
  // Returns the last callback accessed via a first() or next()
  // call.

  CB get_cb() {
    synchronized(this) {
      return _m_cb;
    }
  }

  /****
       function void trace(uvm_object obj = null);
       if (_m_cb !is null && T.cbs.get_debug_flags() & UVM_CALLBACK_TRACE) {
       uvm_report_object reporter = null;
       string who = "Executing ";
       void'($cast(reporter, obj));
       if (reporter is null) void'($cast(reporter, _m_obj));
       if (reporter is null) reporter = uvm_top;
       if (obj !is null) who = {obj.get_full_name(), " is executing "};
       else if (_m_obj !is null) who = {_m_obj.get_full_name(), " is executing "};
       reporter.uvm_report_info("CLLBK_TRC", {who, "callback ", _m_cb.get_name()}, UVM_LOW);
       }
       }
  ****/
}

class uvm_callback: uvm_object
{

  protected bool _m_enabled = true;

  // Function: new
  //
  // Creates a new uvm_callback object, giving it an optional ~name~.

  this(string name="uvm_callback") {
    synchronized(this) {
      super(name);
    }
  }


  // Function: callback_mode
  //
  // Enable/disable callbacks (modeled like rand_mode and constraint_mode).

  bool callback_mode(int on = -1) {
    synchronized(this) {
      import std.string: format;
      bool callback_mode_ = _m_enabled;
      if(on == 0) {
	_m_enabled = false;
      }
      if(on == 1) {
	_m_enabled = true;
      }
      uvm_cb_trace_noobj(this, format("Callback mode for %s is %s",
				      get_name(), _m_enabled ?
				      "ENABLED" : "DISABLED"));
      return callback_mode_;
    }
  }


  // Function: is_enabled
  //
  // Returns 1 if the callback is enabled, 0 otherwise.

  bool is_enabled() {
    return callback_mode();
  }

  enum string type_name = "uvm_callback";


  // Function: get_type_name
  //
  // Returns the type name of this callback object.

  override string get_type_name() {
    return qualifiedTypeName!(typeof(this));
  }
}

// macros
// from sv file macros/uvm_callback_defines

//-----------------------------------------------------------------------------
// Title: Callback Macros
//
// These macros are used to register and execute callbacks extending
// from ~uvm_callbacks~.
//-----------------------------------------------------------------------------

//-----------------------------------------------------------------------------
// MACRO: `uvm_register_cb
//
//| `uvm_register_cb(T,CB)
//
// Registers the given ~CB~ callback type with the given ~T~ object type. If
// a type-callback pair is not registered then a warning is issued if an
// attempt is made to use the pair (add, delete, etc.).
//
// The registration will typically occur in the component that executes the
// given type of callback. For instance:
//
//| virtual class mycb extends uvm_callback;
//|   virtual function void doit();
//| endclass
//|
//| class my_comp extends uvm_component;
//|   `uvm_register_cb(my_comp,mycb)
//|   ...
//|   task run_phase(uvm_phase phase);
//|     ...
//|     `uvm_do_callbacks(my_comp, mycb, doit())
//|   endtask
//| endclass
//-----------------------------------------------------------------------------

// `define uvm_register_cb(T,CB) \
//   static local bit m_register_cb_``CB = uvm_callbacks#(T,CB)::m_register_pair(`"T`",`"CB`");

mixin template uvm_register_cb(T, CB) if(is(CB: uvm_callback))
  {
    import uvm.base.uvm_callback;
    import std.string: format;
    // static this() {
    //   if(uvm_is_uvm_thread) {
    //	uvm_callbacks!(T, CB).m_register_pair();
    //   }
    // }
    void uvm_do_callbacks(void delegate(CB cb) dg) {
      foreach(callb; uvm_callbacks!(T, CB).get_all_enabled(this)) {
	dg(callb);
      }
    }

    void uvm_do_callbacks_reverse(void delegate(CB cb) dg) {
      foreach_reverse(callb; uvm_callbacks!(T, CB).get_all_enabled(this)) {
	dg(callb);
      }
    }

    bool uvm_do_callbacks_exit_on(bool delegate(CB cb) dg, bool val) {
      foreach(callb; uvm_callbacks!(T, CB).get_all_enabled(this)) {
	if(dg(callb) == val) {
	  uvm_cb_trace_noobj(callb,
			     format("Executed callback method 'METHOD' for" ~
				    " callback %s (CB) from %s (T) : returned" ~
				    " value VAL (other callbacks will be ignored)",
				    callb.get_name(), this.get_full_name()));
	  return val;
	}
	uvm_cb_trace_noobj(callb, format("Executed callback method 'METHOD' for" ~
					 " callback %s (CB) from %s (T) : did not" ~
					 " return value VAL`",
					 callb.get_name(), this.get_full_name()));
      }
      return !val;
    }
}

mixin template uvm_register_cb(CB) if(is(CB: uvm_callback))
  {
    mixin uvm_register_cb!(typeof(this), CB);
}

// // register callback and also the supertype
// mixin template uvm_register_cb(CB, ST) if(is(CB: uvm_callback))
//   {
//     static this() {
//       import uvm.base.uvm_root;
//       if(uvm_is_uvm_thread) {
//	uvm_callbacks!(typeof(this), CB).m_register_pair();
//	uvm_derived_callbacks!(typeof(this), ST).register_super_type();
//       }
//     }
//     void uvm_do_callbacks(void delegate(CB cb) dg) {
//       import uvm.base.uvm_callback;
//       uvm_do_obj_callbacks!(CB)(this, dg);
//     }
//     bool uvm_do_callbacks_exit_on(bool delegate(Cb cb) dg, bool val) {
//       import uvm.base.uvm_callback;
//       return uvm_do_obj_callbacks_exit_on!(CB)(this, dg, val);
//     }
// }


//-----------------------------------------------------------------------------
// MACRO: `uvm_set_super_type
//
//| `uvm_set_super_type(T,ST)
//
// Defines the super type of ~T~ to be ~ST~. This allows for derived class
// objects to inherit typewide callbacks that are registered with the base
// class.
//
// The registration will typically occur in the component that executes the
// given type of callback. For instance:
//
//| virtual class mycb extend uvm_callback;
//|   virtual function void doit();
//| endclass
//|
//| class my_comp extends uvm_component;
//|   `uvm_register_cb(my_comp,mycb)
//|   ...
//|   task run_phase(uvm_phase phase);
//|     ...
//|     `uvm_do_callbacks(my_comp, mycb, doit())
//|   endtask
//| endclass
//|
//| class my_derived_comp extends my_comp;
//|   `uvm_set_super_type(my_derived_comp,my_comp)
//|   ...
//|   task run_phase(uvm_phase phase);
//|     ...
//|     `uvm_do_callbacks(my_comp, mycb, doit())
//|   endtask
//| endclass
//-----------------------------------------------------------------------------

// `define uvm_set_super_type(T,ST) \
//   static local bit m_register_``T``ST = uvm_derived_callbacks#(T,ST)::register_super_type(`"T`",`"ST`");

// mixin template uvm_set_super_type(T,ST)
// {
//   static this() {
//     import uvm.base.uvm_root;
//     if(uvm_is_uvm_thread) {
//       uvm_derived_callbacks!(T, ST).register_super_type();
//     }
//   }
// }

// mixin template uvm_set_super_type(ST)
// {
//   static this() {
//     import uvm.base.uvm_root;
//     if(uvm_is_uvm_thread) {
//       uvm_derived_callbacks!(typeof(this), ST).register_super_type();
//     }
//   }
// }

//-----------------------------------------------------------------------------
// MACRO: `uvm_do_callbacks
//
//| `uvm_do_callbacks(T,CB,METHOD)
//
// Calls the given ~METHOD~ of all callbacks of type ~CB~ registered with
// the calling object (i.e. ~this~ object), which is or is based on type ~T~.
//
// This macro executes all of the callbacks associated with the calling
// object (i.e. ~this~ object). The macro takes three arguments:
//
// - CB is the class type of the callback objects to execute. The class
//   type must have a function signature that matches the METHOD argument.
//
// - T is the type associated with the callback. Typically, an instance
//   of type T is passed as one the arguments in the ~METHOD~ call.
//
// - METHOD is the method call to invoke, with all required arguments as
//   if they were invoked directly.
//
// For example, given the following callback class definition:
//
//| virtual class mycb extends uvm_cb;
//|   pure function void my_function (mycomp comp, int addr, int data);
//| endclass
//
// A component would invoke the macro as
//
//| task mycomp::run_phase(uvm_phase phase);
//|    int curr_addr, curr_data;
//|    ...
//|    `uvm_do_callbacks(mycb, mycomp, my_function(this, curr_addr, curr_data))
//|    ...
//| endtask
//-----------------------------------------------------------------------------

// For the Vlang UVM implementation
// This is defined as part of the mixin uvm_register_cb

// `define uvm_do_callbacks(T,CB,METHOD)	\
//   `uvm_do_obj_callbacks(T,CB,this,METHOD)



//-----------------------------------------------------------------------------
// MACRO: `uvm_do_obj_callbacks
//
//| `uvm_do_obj_callbacks(T,CB,OBJ,METHOD)
//
// Calls the given ~METHOD~ of all callbacks based on type ~CB~ registered with
// the given object, ~OBJ~, which is or is based on type ~T~.
//
// This macro is identical to <`uvm_do_callbacks> macro,
// but it has an additional ~OBJ~ argument to allow the specification of an
// external object to associate the callback with. For example, if the
// callbacks are being applied in a sequence, ~OBJ~ could be specified
// as the associated sequencer or parent sequence.
//
//|    ...
//|    `uvm_do_callbacks(mycb, mycomp, seqr, my_function(seqr, curr_addr, curr_data))
//|    ...
//-----------------------------------------------------------------------------

// `define uvm_do_obj_callbacks(T,CB,OBJ,METHOD) \
//    begin \
//      uvm_callback_iter#(T,CB) iter = new(OBJ); \
//      CB cb = iter.first(); \
//      while(cb != null) begin \
//        `uvm_cb_trace_noobj(cb,$sformatf(`"Executing callback method 'METHOD' for callback %s (CB) from %s (T)`",cb.get_name(), OBJ.get_full_name())) \
//        cb.METHOD; \
//        cb = iter.next(); \
//      end \
//    end


//-----------------------------------------------------------------------------
// MACRO: `uvm_do_callbacks_exit_on
//
//| `uvm_do_callbacks_exit_on(T,CB,METHOD,VAL)
//
// Calls the given ~METHOD~ of all callbacks of type ~CB~ registered with
// the calling object (i.e. ~this~ object), which is or is based on type ~T~,
// returning upon the first callback returning the bit value given by ~VAL~.
//
// This macro executes all of the callbacks associated with the calling
// object (i.e. ~this~ object). The macro takes three arguments:
//
// - CB is the class type of the callback objects to execute. The class
//   type must have a function signature that matches the METHOD argument.
//
// - T is the type associated with the callback. Typically, an instance
//   of type T is passed as one the arguments in the ~METHOD~ call.
//
// - METHOD is the method call to invoke, with all required arguments as
//   if they were invoked directly.
//
// - VAL, if 1, says return upon the first callback invocation that
//   returns 1. If 0, says return upon the first callback invocation that
//   returns 0.
//
// For example, given the following callback class definition:
//
//| virtual class mycb extends uvm_cb;
//|   pure function bit drop_trans (mycomp comp, my_trans trans);
//| endclass
//
// A component would invoke the macro as
//
//| task mycomp::run_phase(uvm_phase phase);
//|    my_trans trans;
//|    forever begin
//|      get_port.get(trans);
//|      if(do_callbacks(trans) == 0)
//|        uvm_report_info("DROPPED",{"trans dropped: %s",trans.convert2string()});
//|      else
//|        // execute transaction
//|    end
//| endtask
//| function bit do_callbacks(my_trans);
//|   // Returns 0 if drop happens and 1 otherwise
//|   `uvm_do_callbacks_exit_on(mycomp, mycb, extobj, drop_trans(this,trans), 1)
//| endfunction
//
// Because this macro calls ~return~, its use is restricted to implementations
// of functions that return a ~bit~ value, as in the above example.
//
//-----------------------------------------------------------------------------


// For the Vlang UVM implementation
// This is defined as part of the mixin uvm_register_cb

// `define uvm_do_callbacks_exit_on(T,CB,METHOD,VAL) \
//   `uvm_do_obj_callbacks_exit_on(T,CB,this,METHOD,VAL) \


//-----------------------------------------------------------------------------
// MACRO: `uvm_do_obj_callbacks_exit_on
//
//| `uvm_do_obj_callbacks_exit_on(T,CB,OBJ,METHOD,VAL)
//
// Calls the given ~METHOD~ of all callbacks of type ~CB~ registered with
// the given object ~OBJ~, which must be or be based on type ~T~, and returns
// upon the first callback that returns the bit value given by ~VAL~. It is
// exactly the same as the <`uvm_do_callbacks_exit_on> but has a specific
// object instance (instead of the implicit this instance) as the third
// argument.
//
//| ...
//|  // Exit if a callback returns a 1
//|  `uvm_do_callbacks_exit_on(mycomp, mycb, seqr, drop_trans(seqr,trans), 1)
//| ...
//
// Because this macro calls ~return~, its use is restricted to implementations
// of functions that return a ~bit~ value, as in the above example.
//-----------------------------------------------------------------------------

// `define uvm_do_obj_callbacks_exit_on(T,CB,OBJ,METHOD,VAL) \
//    begin \
//      uvm_callback_iter#(T,CB) iter = new(OBJ); \
//      CB cb = iter.first(); \
//      while(cb != null) begin \
//        if (cb.METHOD == VAL) begin \
//          `uvm_cb_trace_noobj(cb,$sformatf(`"Executed callback method 'METHOD' for callback %s (CB) from %s (T) : returned value VAL (other callbacks will be ignored)`",cb.get_name(), OBJ.get_full_name())) \
//          return VAL; \
//        end \
//        `uvm_cb_trace_noobj(cb,$sformatf(`"Executed callback method 'METHOD' for callback %s (CB) from %s (T) : did not return value VAL`",cb.get_name(), OBJ.get_full_name())) \
//        cb = iter.next(); \
//      end \
//      return 1-VAL; \
//    end


// The +define+UVM_CB_TRACE_ON setting will instrument the uvm library to emit
// messages with message id UVMCB_TRC and UVM_NONE verbosity
// notifing add,delete and execution of uvm callbacks. The instrumentation is off by default.

// `ifdef UVM_CB_TRACE_ON
version(UVM_CB_TRACE_ON) {
  // `defineu vm_cb_trace(OBJ,CB,OPER) \
  //   begin \
  //     string msg; \
  //     msg = (OBJ == null) ? "null" : $sformatf("%s (%s@%0d)", \
  //       OBJ.get_full_name(), OBJ.get_type_name(), OBJ.get_inst_id()); \
  //     `uvm_info("UVMCB_TRC", $sformatf("%s: callback %s (%s@%0d) : to object %s",  \
  //        OPER, CB.get_name(), CB.get_type_name(), CB.get_inst_id(), msg), UVM_NONE) \
  //   end
  void uvm_cb_trace(T, CB)(T obj, CB cb, string oper) {
    string msg = (obj is null) ? "null" :
      format("%s (%s@%0d)",
	     obj.get_full_name(), obj.get_type_name(), obj.get_inst_id());
    uvm_info("UVMCB_TRC", format("%s: callback %s (%s@%0d) : to object %s",
				 oper, cb.get_name(), cb.get_type_name(),
				 cb.get_inst_id(), msg), UVM_NONE);
  }

  // `define uvm_cb_trace_noobj(CB,OPER) \
  //   begin \
  //     if(uvm_callbacks_base::m_tracing) \
  //       `uvm_info("UVMCB_TRC", $sformatf("%s : callback %s (%s@%0d)" ,  \
  //        OPER, CB.get_name(), CB.get_type_name(), CB.get_inst_id()), UVM_NONE) \
  //   end
  void uvm_cb_trace_noobj(CB)(CB cb, string oper) {
    if(uvm_callbacks_base.m_tracing) {
      uvm_info("UVMCB_TRC",
	       format("%s : callback %s (%s@%0d)",
		      oper, cb.get_name(), cb.get_type_name(),
		      cb.get_inst_id()), UVM_NONE);
    }
  }
}
// `else
 else {
   void uvm_cb_trace(T,CB)(T obj, CB cb, string oper) {}
   void uvm_cb_trace_noobj(CB)(CB cb, string oper) {}

   // `endif
 }
