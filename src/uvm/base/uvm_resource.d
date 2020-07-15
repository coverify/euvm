//----------------------------------------------------------------------
// Copyright 2014-2019 Coverify Systems Technology
// Copyright 2010-2011 Paradigm Works
// Copyright 2010-2018 Mentor Graphics Corporation
// Copyright 2015 Analog Devices, Inc.
// Copyright 2014 Semifore
// Copyright 2017 Intel Corporation
// Copyright 2010-2014 Synopsys, Inc.
// Copyright 2010-2018 Cadence Design Systems, Inc.
// Copyright 2010-2011 AMD
// Copyright 2013-2018 NVIDIA Corporation
// Copyright 2017-2018 Cisco Systems, Inc.
// Copyright 2011-2012 Cypress Semiconductor Corp.
// Copyright 2017-2018 Verific
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

module uvm.base.uvm_resource;

import uvm.base.uvm_resource_base;
import uvm.base.uvm_object: uvm_object;
import uvm.base.uvm_pool: uvm_pool;
import uvm.base.uvm_printer: uvm_printer, uvm_tree_printer;
import uvm.base.uvm_coreservice: uvm_coreservice_t;
import uvm.base.uvm_globals: uvm_report_warning, uvm_is_match, uvm_info;
import uvm.base.uvm_object_globals: uvm_radix_enum, uvm_verbosity;
import uvm.base.uvm_registry: uvm_object_registry;
import uvm.base.uvm_factory: uvm_object_wrapper;
import uvm.base.uvm_misc: uvm_object_value_str;

import uvm.dpi.uvm_regex: uvm_glob_to_re;

import uvm.base.uvm_once;

import uvm.meta.meta;
import uvm.meta.misc;

import esdl.base.core: SimTime, getRootEntity, Process;

import std.string;
import std.random: Random;
import std.algorithm: sort;
import std.conv: to;


//----------------------------------------------------------------------
// Class - get_t
//
// Instances of get_t are stored in the history list as a record of each
// get.  Failed gets are indicated with rsrc set to ~null~.  This is part
// of the audit trail facility for resources.
//----------------------------------------------------------------------
class get_t {
  string _name;
  string _rscope;
  uvm_resource_base _rsrc;
  SimTime _t;
}

//----------------------------------------------------------------------
// Class -- NODOCS --  uvm_resource_pool
//
// The global (singleton) resource database.
//
// Each resource is stored both by primary name and by type handle.  The
// resource pool contains two associative arrays, one with name as the
// key and one with the type handle as the key.  Each associative array
// contains a queue of resources.  Each resource has a regular
// expression that represents the set of scopes over which it is visible.
//
//|  +------+------------+                          +------------+------+
//|  | name | rsrc queue |                          | rsrc queue | type |
//|  +------+------------+                          +------------+------+
//|  |      |            |                          |            |      |
//|  +------+------------+                  +-+-+   +------------+------+
//|  |      |            |                  | | |<--+---*        |  T   |
//|  +------+------------+   +-+-+          +-+-+   +------------+------+
//|  |  A   |        *---+-->| | |           |      |            |      |
//|  +------+------------+   +-+-+           |      +------------+------+
//|  |      |            |      |            |      |            |      |
//|  +------+------------+      +-------+  +-+      +------------+------+
//|  |      |            |              |  |        |            |      |
//|  +------+------------+              |  |        +------------+------+
//|  |      |            |              V  V        |            |      |
//|  +------+------------+            +------+      +------------+------+
//|  |      |            |            | rsrc |      |            |      |
//|  +------+------------+            +------+      +------------+------+
//
// The above diagrams illustrates how a resource whose name is A and
// type is T is stored in the pool.  The pool contains an entry in the
// type map for type T and an entry in the name map for name A.  The
// queues in each of the arrays each contain an entry for the resource A
// whose type is T.  The name map can contain in its queue other
// resources whose name is A which may or may not have the same type as
// our resource A.  Similarly, the type map can contain in its queue
// other resources whose type is T and whose name may or may not be A.
//
// Resources are added to the pool by calling <set>; they are retrieved
// from the pool by calling <get_by_name> or <get_by_type>.  When an object
// creates a new resource and calls <set> the resource is made available to be
// retrieved by other objects outside of itself; an object gets a
// resource when it wants to access a resource not currently available
// in its scope.
//
// The scope is stored in the resource itself (not in the pool) so
// whether you get by name or by type the resource's visibility is
// the same.
//
// As an auditing capability, the pool contains a history of gets.  A
// record of each get, whether by <get_by_type> or <get_by_name>, is stored
// in the audit record.  Both successful and failed gets are recorded. At
// the end of simulation, or any time for that matter, you can dump the
// history list.  This will tell which resources were successfully
// located and which were not.  You can use this information
// to determine if there is some error in name, type, or
// scope that has caused a resource to not be located or to be incorrectly
// located (i.e. the wrong resource is located).
//
//----------------------------------------------------------------------

// @uvm-ieee 1800.2-2017 auto C.2.4.1
class uvm_resource_pool
{
  import esdl.data.queue;
  import std.string: format;

  struct rsrc_info_t
  { 
    string _rscope;
    uint _precedence;
  }
  // table to set/get scope and precedence for resources

  static class uvm_once: uvm_once_base
  {
    @uvm_immutable_sync
    private uvm_pool!(uvm_resource_base, rsrc_info_t) _ri_tab;

    @uvm_immutable_sync
    uvm_tree_printer _rsrc_printer;

    @uvm_immutable_sync
    uvm_tree_printer _dump_printer;

    this() {
      synchronized (this) {
	_rsrc_printer = new uvm_tree_printer();
	_dump_printer = new uvm_tree_printer();
	_dump_printer.set_type_name_enabled(true);
	_ri_tab =
	  new uvm_pool!(uvm_resource_base, rsrc_info_t)("ri_tab");
      }
    }
  }

  mixin (uvm_once_sync_string);

  private uvm_resource_types.rsrc_q_t[string]     _rtab;
  private uvm_resource_types.rsrc_q_t[uvm_resource_base]   _ttab;


  private get_t[] _get_record;  // history of gets

  // @uvm-ieee 1800.2-2017 auto C.2.4.2.1
  this() { }


  // Function -- NODOCS -- get
  //
  // Returns the singleton handle to the resource pool

  // @uvm-ieee 1800.2-2017 auto C.2.4.2.2
  static uvm_resource_pool get() {
    uvm_coreservice_t cs = uvm_coreservice_t.get();
    uvm_resource_pool t_rp = cs.get_resource_pool();
    return t_rp;
  }


  // Function -- NODOCS -- spell_check
  //
  // Invokes the spell checker for a string s.  The universe of
  // correctly spelled strings -- i.e. the dictionary -- is the name
  // map.

  final bool spell_check(string s) {
    import uvm.base.uvm_spell_chkr;
    synchronized (this) {
      return uvm_spell_chkr!(uvm_resource_types.rsrc_q_t).check(_rtab, s);
    }
  }

  //-----------
  // Group -- NODOCS -- Set
  //-----------

  // Function -- NODOCS --  set
  //
  // Add a new resource to the resource pool.  The resource is inserted
  // into both the name map and type map so it can be located by
  // either.
  //
  // An object creates a resources and ~sets~ it into the resource pool.
  // Later, other objects that want to access the resource must ~get~ it
  // from the pool
  //
  // Overrides can be specified using this interface.  Either a name
  // override, a type override or both can be specified.  If an
  // override is specified then the resource is entered at the front of
  // the queue instead of at the back.  It is not recommended that users
  // specify the override parameter directly, rather they use the
  // <set_override>, <set_name_override>, or <set_type_override>
  // functions.
  //

  // @uvm-ieee 1800.2-2017 auto C.2.4.3.1
  void set_scope(uvm_resource_base rsrc, string rscope) {

    // If resource handle is ~null~ then there is nothing to do.
    if (rsrc is null) {
      uvm_report_warning("NULLRASRC", "attempting to set scope of a null resource");
      return;
    }

    synchronized (this) {
      // Insert into the name map.  Resources with empty names are
      // anonymous resources and are not entered into the name map
      uvm_resource_types.rsrc_q_t rq;
      string name = rsrc.get_name();
      if ((name != "") && name in _rtab) {
	rq = _rtab[name];
	for (size_t i = 0; i < rq.size(); i++) {
	  uvm_resource_base r = rq.get(i);
	  if (r is rsrc) {
	    _ri_tab[rsrc]._rscope = uvm_glob_to_re(rscope);
	    return;
	  }
	}
      }

      if (rq is null) {
	rq = new uvm_resource_types.rsrc_q_t(name);
      }

      // Insert the resource into the queue associated with its name.
      // Insert it with low priority (in the back of queue) .
      rq.push_back(rsrc);

      _rtab[name] = rq;

      // Insert into the type map
      uvm_resource_base type_handle = rsrc.get_type_handle();
      if (type_handle in _ttab)
	rq = _ttab[type_handle];
      else 
	rq = new uvm_resource_types.rsrc_q_t();

      // Insert the resource into the queue associated with its type.  
      // Insert it with low priority (in the back of queue) .
      rq.push_back(rsrc);
      _ttab[type_handle] = rq;

      // Set the scope of resource. 
      _ri_tab[rsrc]._rscope = uvm_glob_to_re(rscope);
      _ri_tab[rsrc]._precedence = get_default_precedence();
    }
  }

  // Function -- NODOCS --  set_override
  //
  // The resource provided as an argument will be entered into the pool
  // and will override both by name and type.
  // Default value to 'scope' argument is violating 1800.2-2017 LRM, but it
  // is added to make the routine backward compatible

  // @uvm-ieee 1800.2-2017 auto C.2.4.3.2
  final void set_override(uvm_resource_base rsrc,
			  string rscope = "") {
     string s = rscope;
     set_scope(rsrc, s);
     set_priority(rsrc, uvm_resource_types.priority_e.PRI_HIGH);
  }


  // Function -- NODOCS --  set_name_override
  //
  // The resource provided as an argument will entered into the pool
  // using normal precedence in the type map and will override the name.
  // Default value to 'scope' argument is violating 1800.2-2017 LRM, but it
  // is added to make the routine backward compatible

  // @uvm-ieee 1800.2-2017 auto C.2.4.3.3
  final void set_name_override(uvm_resource_base rsrc,
			       string rscope = "") {
    string s = rscope;
    set_scope(rsrc, s);
    set_priority_name(rsrc, uvm_resource_types.priority_e.PRI_HIGH);
  }


  // Function -- NODOCS --  set_type_override
  //
  // The resource provided as an argument will be entered into the pool
  // using normal precedence in the name map and will override the type.
  // Default value to 'scope' argument is violating 1800.2-2017 LRM, but it
  // is added to make the routine backward compatible


  // @uvm-ieee 1800.2-2017 auto C.2.4.3.4
  final void set_type_override(uvm_resource_base rsrc,
			       string rscope = "") {
    string s = rscope;
    set_scope(rsrc, s);
    set_priority_type(rsrc, uvm_resource_types.priority_e.PRI_HIGH);
  }


  // @uvm-ieee 1800.2-2017 auto C.2.4.3.5
  bool get_scope(uvm_resource_base rsrc,
		 out string rscope) {

    // If resource handle is ~null~ then there is nothing to do.
    if (rsrc is null) 
      return false;

    synchronized (this) {
      // Search the resouce in the name map.  Resources with empty names are
      // anonymous resources and are not entered into the name map
      string name = rsrc.get_name();
      if ((name != "") && name in _rtab) {
	uvm_resource_types.rsrc_q_t rq = _rtab[name];
	for (size_t i = 0; i < rq.length; i++) {
	  uvm_resource_base r = rq.get(i);
	  if (r is rsrc) {
	    // Resource is in pool, set the scope 
	    rscope = _ri_tab[rsrc]._rscope;
	    return true;
	  }
	}
      }

      // Resource is not in pool
      rscope = "";
      return false;

    }
  }

  // Function -- NODOCS -- delete
  // 
  // If rsrc exists within the pool, then it is removed from all internal maps. If the rsrc is null, or does not exist
  // within the pool, then the request is silently ignored.

 
  // @uvm-ieee 1800.2-2017 auto C.2.4.3.6
  void remove (uvm_resource_base rsrc) {
    synchronized (this) {
      if (rsrc !is null) {
	string name = rsrc.get_name();
	if (name != "") {
	  if (name in _rtab)
	    _rtab.remove(name);
	}
      
	uvm_resource_base type_handle = rsrc.get_type_handle();
	if (type_handle in _ttab) {
	  auto q_size = _ttab[type_handle].length;
          
	  if (q_size == 1)
	    _ttab.remove(type_handle);
	  else {
	    for (size_t i=0; i < q_size; i++) {
	      if (_ttab[type_handle].get(i) is rsrc) {
		_ttab[type_handle].remove(i);
		break;
	      }
	    }            
	  }   
	}
	if (rsrc in _ri_tab)
	  _ri_tab.remove(rsrc);
      }
    }
  }

  // function - push_get_record
  //
  // Insert a new record into the get history list.

  final void push_get_record(string name, string rscope,
			     uvm_resource_base rsrc) {
    synchronized (this) {
      // if auditing is turned off then there is no reason
      // to save a get record
      if (!uvm_resource_options.is_auditing()) {
	return;
      }

      get_t impt = new get_t();

      synchronized (impt) {
	impt._name   = name;
	impt._rscope = rscope;
	impt._rsrc   = rsrc;
	impt._t      = getRootEntity().getSimTime();

	_get_record ~= impt;
      }
    }
  }

  // function - dump_get_records
  //
  // Format and print the get history list.

  final void dump_get_records() {
    import uvm.base.uvm_globals;
    import uvm.base.uvm_object_globals;
    synchronized (this) {
      bool success;
      string qs;

      qs ~= "--- resource get records ---\n";
      foreach (i, record; _get_record) {
	// record is effectively immutable
	success = (record._rsrc !is null);
	qs ~= format("get: name=%s  scope=%s  %s @ %s\n",
		     record._name, record._rscope,
		     (success ? "success" : "fail"),
		     record._t);
      }
      uvm_info("UVM/RESOURCE/GETRECORD", qs, uvm_verbosity.UVM_NONE);
    }
  }

  //--------------
  // Group -- NODOCS -- Lookup
  //--------------
  //
  // This group of functions is for finding resources in the resource database.
  //
  // <lookup_name> and <lookup_type> locate the set of resources that
  // matches the name or type (respectively) and is visible in the
  // current scope.  These functions return a queue of resources.
  //
  // <get_highest_precedence> traverse a queue of resources and
  // returns the one with the highest precedence -- i.e. the one whose
  // precedence member has the highest value.
  //
  // <get_by_name> and <get_by_type> use <lookup_name> and <lookup_type>
  // (respectively) and <get_highest_precedence> to find the resource with
  // the highest priority that matches the other search criteria.


  // Function -- NODOCS --  lookup_name
  //
  // Lookup resources by ~name~.  Returns a queue of resources that
  // match the ~name~, ~scope~, and ~type_handle~.  If no resources
  // match the queue is returned empty. If ~rpterr~ is set then a
  // warning is issued if no matches are found, and the spell checker is
  // invoked on ~name~.  If ~type_handle~ is ~null~ then a type check is
  // not made and resources are returned that match only ~name~ and
  // ~scope~.

  // @uvm-ieee 1800.2-2017 auto C.2.4.4.1
  final uvm_resource_types.rsrc_q_t lookup_name(string rscope = "",
						string name = "",
						uvm_resource_base type_handle = null,
						bool rpterr = true) {
    synchronized (this) {
      uvm_resource_types.rsrc_q_t q;

      // ensure rand stability during lookup
      version (PRESERVE_RANDSTATE) {
	Process p = Process.self();
	Random s;
	if (p !is null) p.getRandState(s);
      }
      q = new  uvm_resource_types.rsrc_q_t("uvm_resource/lookup_name/q");

      version (PRESERVE_RANDSTATE) {
	if (p !is null) p.setRandState(s);
      }


      // resources with empty names are anonymous and do not exist in the name map
      if (name == "") {
	return q;
      }

      // Does an entry in the name map exist with the specified name?
      // If not, then we're done
      if (name !in _rtab) {
	if (rpterr)
	  spell_check(name);
	return q;
      }

      uvm_resource_base rsrc = null;
      uvm_resource_types.rsrc_q_t rq = _rtab[name];
      for (size_t i = 0; i < rq.size(); ++i) {
	uvm_resource_base r = rq.get(i);
	string rsrcs = r in _ri_tab ?
			      _ri_tab[r]._rscope : "";
	// does the type and scope match?
	if (((type_handle is null) || (r.get_type_handle() is type_handle)) &&
	    uvm_is_match(rsrcs, rscope))
	  q.push_back(r);
      }
      return q;
    }
  }

  // Function -- NODOCS --  get_highest_precedence
  //
  // Traverse a queue, ~q~, of resources and return the one with the highest
  // precedence.  In the case where there exists more than one resource
  // with the highest precedence value, the first one that has that
  // precedence will be the one that is returned.

  // @uvm-ieee 1800.2-2017 auto C.2.4.4.2
  // @uvm-ieee 1800.2-2017 auto C.2.4.5.8
  static uvm_resource_base get_highest_precedence(ref uvm_resource_types.rsrc_q_t q) {
    if (q.length == 0)
      return null;
    // get the first resources in the queue
    uvm_resource_base rsrc = q.get(0);
    uint prec = (rsrc in _ri_tab) ?
      _ri_tab[rsrc]._precedence : 0;

    // start searching from the second resource
    for (size_t i = 1; i < q.length; ++i) {
      uvm_resource_base r = q.get(i);
      uint c_prec = (r in _ri_tab) ?
	_ri_tab[r]._precedence : 0;
      if (c_prec > prec) {
	rsrc = r;
	prec = c_prec;
      }
    }
    return rsrc;
  }

  // Function -- NODOCS --  sort_by_precedence
  //
  // Given a list of resources, obtained for example from <lookup_scope>,
  // sort the resources in  precedence order. The highest precedence
  // resource will be first in the list and the lowest precedence will
  // be last. Resources that have the same precedence and the same name
  // will be ordered by most recently set first.

  // @uvm-ieee 1800.2-2017 auto C.2.4.4.3
  static void sort_by_precedence(ref uvm_resource_types.rsrc_q_t q) {
    uvm_resource_types.rsrc_q_t[int] all;
    foreach (r; q) {
      uint prec = (r in _ri_tab) ?
	_ri_tab[r]._precedence: 0;
      if (prec !in all)
	all[prec] = new uvm_resource_types.rsrc_q_t
	  (format("uvm_resource/sort_by" ~
		  "_precedence/all[%d]",
		  prec));
      all[prec].push_front(r); //since we will push_front in the final
    }
    q.remove();
    foreach (i; sort(all.keys)) {
      foreach (r; all[i]) {
	q.push_front(r);
      }
    }
  }


  // Function -- NODOCS --  get_by_name
  //
  // Lookup a resource by ~name~, ~scope~, and ~type_handle~.  Whether
  // the get succeeds or fails, save a record of the get attempt.  The
  // ~rpterr~ flag indicates whether to report errors or not.
  // Essentially, it serves as a verbose flag.  If set then the spell
  // checker will be invoked and warnings about multiple resources will
  // be produced.

  // @uvm-ieee 1800.2-2017 auto C.2.4.4.4
  final uvm_resource_base get_by_name(string rscope,
				      string name,
				      uvm_resource_base type_handle,
				      bool rpterr = true) {
    synchronized (this) {
      uvm_resource_types.rsrc_q_t q = lookup_name(rscope, name, type_handle,
						  rpterr);
      if (q.length == 0) {
	push_get_record(name, rscope, null);
	return null;
      }
      uvm_resource_base rsrc = get_highest_precedence(q);
      push_get_record(name, rscope, rsrc);
      return rsrc;
    }
  }


  // Function -- NODOCS --  lookup_type
  //
  // Lookup resources by type. Return a queue of resources that match
  // the ~type_handle~ and ~scope~.  If no resources match then the returned
  // queue is empty.

  // @uvm-ieee 1800.2-2017 auto C.2.4.4.5
  final uvm_resource_types.rsrc_q_t lookup_type(string rscope,
						uvm_resource_base type_handle) {
    synchronized (this) {
      auto q = new uvm_resource_types.rsrc_q_t("uvm_resource/lookup_type/q");

      if (type_handle is null || type_handle !in _ttab) {
	return q;
      }

      uvm_resource_types.rsrc_q_t rq = _ttab[type_handle];
      foreach (r; rq) {
	if (r in _ri_tab &&
		  uvm_is_match(_ri_tab[r]._rscope, rscope)) {
	  q.push_back(r);
	}
      }
      return q;
    }
  }

  // Function -- NODOCS --  get_by_type
  //
  // Lookup a resource by ~type_handle~ and ~scope~.  Insert a record into
  // the get history list whether or not the get succeeded.

  // @uvm-ieee 1800.2-2017 auto C.2.4.4.6
  final uvm_resource_base get_by_type(string rscope,
				      uvm_resource_base type_handle) {
    synchronized (this) {

      uvm_resource_types.rsrc_q_t q = lookup_type(rscope, type_handle);

      if (q.length == 0) {
	push_get_record("<type>", rscope, null);
	return null;
      }

      uvm_resource_base rsrc = q.get(0);
      push_get_record("<type>", rscope, rsrc);
      return rsrc;
    }
  }

  // Function -- NODOCS --  lookup_regex_names
  //
  // This utility function answers the question, for a given ~name~,
  // ~scope~, and ~type_handle~, what are all of the resources with requested name,
  // a matching scope (where the resource scope may be a
  // regular expression), and a matching type?
  // ~name~ and ~scope~ are explicit values.

  final uvm_resource_types.rsrc_q_t lookup_regex_names(string rscope,
						       string name,
						       uvm_resource_base type_handle = null
						       ) {
    return lookup_name(rscope, name, type_handle, false);
  }

  // Function -- NODOCS --  lookup_regex
  //
  // Looks for all the resources whose name matches the regular
  // expression argument and whose scope matches the current scope.

  // @uvm-ieee 1800.2-2017 auto C.2.4.4.7
  final uvm_resource_types.rsrc_q_t lookup_regex(string re, string rscope) {
    import uvm.dpi.uvm_regex;
    synchronized (this) {

      auto result_q =
	new uvm_resource_types.rsrc_q_t("uvm_resource/lookup_regex/result_q");

      foreach (name, rq; _rtab) {
	if (! uvm_is_match(re, name))
	  continue;
	rq = _rtab[name];
	foreach (r; rq) {
	  if (r in _ri_tab &&
		    uvm_is_match(_ri_tab[r]._rscope, rscope))
	    result_q.push_back(r);
	}
      }

      return result_q;
    }
  }

  // Function -- NODOCS --  lookup_scope
  //
  // This is a utility function that answers the question: For a given
  // ~scope~, what resources are visible to it?  Locate all the resources
  // that are visible to a particular scope.  This operation could be
  // quite expensive, as it has to traverse all of the resources in the
  // database.

  // @uvm-ieee 1800.2-2017 auto C.2.4.4.8
  final uvm_resource_types.rsrc_q_t lookup_scope(string rscope) {
    synchronized (this) {
      auto q = new uvm_resource_types.rsrc_q_t("uvm_resource/lookup_scope/q");

      //iterate in reverse order for the special case of autoconfig
      //of arrays. The array name with no [] needs to be higher priority.
      //This has no effect an manual accesses.
      foreach_reverse(name; sort(_rtab.keys)) {
	foreach (r; _rtab[name]) {
	  if (r in _ri_tab &&
		    uvm_is_match(_ri_tab[r]._rscope, rscope)) {
	    q.push_back(r);
	  }
	}
      }
      return q;
    }
  }


  //--------------------
  // Group: Set Priority
  //--------------------
  //
  // Functions for altering the search priority of resources.  Resources
  // are stored in queues in the type and name maps.  When retrieving
  // resources, either by type or by name, the resource queue is search
  // from front to back.  The first one that matches the search criteria
  // is the one that is returned.  The ~set_priority~ functions let you
  // change the order in which resources are searched.  For any
  // particular resource, you can set its priority to UVM_HIGH, in which
  // case the resource is moved to the front of the queue, or to UVM_LOW in
  // which case the resource is moved to the back of the queue.

  // function- set_priority_queue
  //
  // This function handles the mechanics of moving a resource to either
  // the front or back of the queue.

  private void set_priority_queue(uvm_resource_base rsrc,
				  uvm_resource_types.rsrc_q_t q,
				  uvm_resource_types.priority_e pri) {
    import uvm.base.uvm_globals;
    synchronized (this) {
      string name = rsrc.get_name();
      uvm_resource_base r;
      size_t i;

      foreach (j, r_; q) {
	i = j; r = r_;
	if (r is rsrc) break;
      }

      if (r !is rsrc) {
	auto msg = format("Handle for resource named %s is not in the" ~
			  " name name; cannot change its priority", name);
	uvm_report_error("NORSRC", msg);
	return;
      }

      q.remove(i);

      final switch (pri) {
      case uvm_resource_types.priority_e.PRI_HIGH: q.push_front(rsrc); break;
      case uvm_resource_types.priority_e.PRI_LOW:  q.push_back(rsrc); break;
      }
    }
  }


  // Function -- NODOCS --  set_priority_type
  //
  // Change the priority of the ~rsrc~ based on the value of ~pri~, the
  // priority enum argument.  This function changes the priority only in
  // the type map, leaving the name map untouched.

  // @uvm-ieee 1800.2-2017 auto C.2.4.5.1
  final void set_priority_type(uvm_resource_base rsrc,
			       uvm_resource_types.priority_e pri) {
    import uvm.base.uvm_globals;
    synchronized (this) {

      if (rsrc is null) {
	uvm_report_warning("NULLRASRC", "attempting to change" ~
			   " the serach priority of a null resource");
	return;
      }

      uvm_resource_base type_handle = rsrc.get_type_handle();
      if (type_handle !in _ttab) {
	string msg = format("Type handle for resrouce named %s not found in" ~
			    " type map; cannot change its search priority",
			    rsrc.get_name());
	uvm_report_error("RNFTYPE", msg);
	return;
      }

      uvm_resource_types.rsrc_q_t q = _ttab[type_handle];
      set_priority_queue(rsrc, q, pri);
    }
  }


  // Function -- NODOCS --  set_priority_name
  //
  // Change the priority of the ~rsrc~ based on the value of ~pri~, the
  // priority enum argument.  This function changes the priority only in
  // the name map, leaving the type map untouched.

  // @uvm-ieee 1800.2-2017 auto C.2.4.5.2
  final void set_priority_name(uvm_resource_base rsrc,
			       uvm_resource_types.priority_e pri) {
    import uvm.base.uvm_globals;
    synchronized (this) {
      if (rsrc is null) {
	uvm_report_warning("NULLRASRC", "attempting to change the serach" ~
			   " priority of a null resource");
	return;
      }
      string name = rsrc.get_name();
      if (name !in _rtab) {
	string msg = format("Resrouce named %s not found in name map;" ~
			    " cannot change its search priority", name);
	uvm_report_error("RNFNAME", msg);
	return;
      }
      uvm_resource_types.rsrc_q_t q = _rtab[name];
      set_priority_queue(rsrc, q, pri);
    }
  }


  // Function -- NODOCS --  set_priority
  //
  // Change the search priority of the ~rsrc~ based on the value of ~pri~,
  // the priority enum argument.  This function changes the priority in
  // both the name and type maps.

  // @uvm-ieee 1800.2-2017 auto C.2.4.5.3
  final void set_priority (uvm_resource_base rsrc,
			   uvm_resource_types.priority_e pri) {
    synchronized (this) {
      set_priority_type(rsrc, pri);
      set_priority_name(rsrc, pri);
    }
  }


  // @uvm-ieee 1800.2-2017 auto C.2.4.5.4
  static void set_default_precedence(uint precedence) {
    uvm_coreservice_t cs = uvm_coreservice_t.get();
    cs.set_resource_pool_default_precedence(precedence);
  }


  static uint  get_default_precedence() {
    uvm_coreservice_t cs = uvm_coreservice_t.get();
    return cs.get_resource_pool_default_precedence(); 
  }

  
  // @uvm-ieee 1800.2-2017 auto C.2.4.5.6
  void set_precedence(uvm_resource_base r,
		      uint p=uvm_resource_pool.get_default_precedence()) {

    synchronized (this) {
      if (r is null) {
	uvm_report_warning("NULLRASRC", "attempting to set precedence of a null resource");
	return;
      }

      string name = r.get_name();
      uvm_resource_base rsrc;
      if (name in _rtab) {
	uvm_resource_types.rsrc_q_t q = _rtab[name];

	for (size_t i = 0; i < q.length; i++) {
	  rsrc = q.get(i);
	  if (rsrc is r) break;
	}
      } 
  
      if (r != rsrc) {
	uvm_report_warning("NORSRC",
			   format("resource named %s is not placed within the pool", name));
	return;
      }
      _ri_tab[r]._precedence = p;
    }

  }


  uint get_precedence(uvm_resource_base r) {
    synchronized (this) {
      if (r is null) {
	uvm_report_warning("NULLRASRC", "attempting to get precedence of a null resource");
	return uvm_resource_pool.get_default_precedence();
      }

      string name = r.get_name();
      uvm_resource_base rsrc;
      if (name in _rtab) {
	uvm_resource_types.rsrc_q_t q = _rtab[name];

	for (size_t i = 0; i < q.length; i++) {
	  rsrc = q.get(i);
	  if (rsrc is r) break;
	}
      }
  
      if (r !is rsrc) {
	uvm_report_warning("NORSRC",
			   format("resource named %s is not placed within the pool", name));
	return uvm_resource_pool.get_default_precedence();
      }

      return _ri_tab[r]._precedence;
    }
  }


  //--------------------------------------------------------------------
  // Group -- NODOCS -- Debug
  //--------------------------------------------------------------------

  // Prints resouce queue into ~printer~, non-LRM
  void m_print_resources(uvm_printer printer,
			 uvm_resource_types.rsrc_q_t rq,
			 bool audit = false) {
    
    printer.push_element(rq.get_name(),
                         "uvm_queue#(uvm_resource_base)",
                         format("%0d",rq.length),
			 uvm_object_value_str(rq));

    for (size_t i=0; i < rq.length; ++i) {
      printer.push_element(format("[%0d]", i),
                           "uvm_resource",
                           "-",
                           "-");

      uvm_resource_base r = rq.get(i);
      string rscope;
      get_scope(r, rscope);
        
      printer.print_string("name", r.get_name());

      printer.print_generic_element("value",
                                    r.m_value_type_name(),
                                    "",
                                    r.m_value_as_string());
                                    
      printer.print_string("scope", rscope);

      printer.print_field_int("precedence", get_precedence(r),
			      32, uvm_radix_enum.UVM_UNSIGNED);

      if (audit && r.access.length) {
        printer.print_array_header("accesses",
				   r.access.length,
				   "queue");
        foreach (k, acc; r.access) {
          printer.print_string(format("[%s]", k),
                               format("reads: %0d @ %s  writes: %0d @ %s",
				      acc.read_count,
				      acc.read_time,
				      acc.write_count,
				      acc.write_time));
        }

        printer.print_array_footer(r.access.length);
      } // (audit && r.access.size())

      printer.pop_element();
    } // int i=0

    printer.pop_element();
  }
                                  
  // Function -- NODOCS -- print_resources
  //
  // Print the resources that are in a single queue, ~rq~.  This is a utility
  // function that can be used to print any collection of resources
  // stored in a queue.  The ~audit~ flag determines whether or not the
  // audit trail is printed for each resource along with the name,
  // value, and scope regular expression.

  void print_resources(uvm_resource_types.rsrc_q_t rq,
		       bool audit = false) {

    // moved to once
    // static uvm_tree_printer printer = new();

    // Basically this is full implementation of something
    // like uvm_object::print, but we're interleaving
    // scope data, so it's all manual.
    _rsrc_printer.flush();
    if (rq is null)
      _rsrc_printer.print_generic_element("",
					  "uvm_queue#(uvm_resource_base)",
					  "",
					  "<null>");
    else
      m_print_resources(_rsrc_printer, rq, audit);
    uvm_info("UVM/RESOURCE_POOL/PRINT_QUEUE",
	     _rsrc_printer.emit(),
	     uvm_verbosity.UVM_NONE);
  }


  // Function -- NODOCS -- dump
  //
  // dump the entire resource pool.  The resource pool is traversed and
  // each resource is printed.  The utility function print_resources()
  // is used to initiate the printing. If the ~audit~ bit is set then
  // the audit trail is dumped for each resource.

  void dump(bool audit = false, uvm_printer printer = null) {

    // moved to once
    // static uvm_tree_printer m_printer;

    // if (_dump_printer is null) {
    // 	_dump_printer = new uvm_tree_printer();
    // _dump_printer.set_type_name_enabled(true);
    // }
      

    if (printer is null)
      printer = _dump_printer;
    
    printer.flush();
    printer.push_element("uvm_resource_pool",
                         "",
                         format("%0d", _rtab.length),
                         "");
    
    foreach (r; _rtab) {
      m_print_resources(printer, r, audit);
    }

    printer.pop_element();
    
    uvm_info("UVM/RESOURCE/DUMP", printer.emit(), uvm_verbosity.UVM_NONE);

  }
}

//----------------------------------------------------------------------
// Class: uvm_resource #(T)
// Implementation of uvm_resource#(T) as defined in section C.2.5.1 of
// 1800.2-2017.
//----------------------------------------------------------------------

// @uvm-ieee 1800.2-2017 auto C.2.5.1
class uvm_resource(T=int): uvm_resource_base
{

  alias this_type = uvm_resource!(T);

  static class uvm_once: uvm_once_base
  {
    // singleton handle that represents the type of this resource
    @uvm_immutable_sync
    private this_type _my_type;
    this() {
      synchronized (this) {
	_my_type = new this_type();
      }
    }
  }

  mixin (uvm_once_sync_string);
  mixin (uvm_sync_string);
  // Can't be rand since things like rand strings are not legal.
  @uvm_protected_sync
  protected T _val;

  // Because of uvm_resource#(T)::get_type, we can't use
  // the macros.  We need to do it all manually.
  alias type_id = uvm_object_registry!(this_type);
  override uvm_object_wrapper get_object_type() {
    return type_id.get();
  }
  override uvm_object create (string name="") {
    this_type tmp;
    if (name=="") tmp = new this_type();
    else tmp = new this_type(name);
    return tmp;
  }

  // `uvm_type_name_decl($sformatf("uvm_resource#(%s)", `uvm_typename(T)))

  // @uvm-ieee 1800.2-2017 auto C.2.5.2
  this(string name="") {
    super(name);
  }

  override string m_value_type_name() {
    return T.stringof;
  }
                                    
  override string m_value_as_string() {
    synchronized (this) {
      return format("%s", val);
    }
  }
                                    

  //----------------------
  // Group: Type Interface
  //----------------------
  //
  // Resources can be identified by type using a static type handle.
  // The parent class provides the virtual function interface
  // <get_type_handle>.  Here we implement it by returning the static type
  // handle.

  // Function -- NODOCS --  get_type
  //
  // Static function that returns the static type handle.  The return
  // type is this_type, which is the type of the parameterized class.

  static this_type get_type() {
    return my_type;
  }

  // Function -- NODOCS --  get_type_handle
  //
  // Returns the static type handle of this resource in a polymorphic
  // fashion.  The return type of get_type_handle() is
  // uvm_resource_base.  This function is not static and therefore can
  // only be used by instances of a parameterized resource.

  // @uvm-ieee 1800.2-2017 auto C.2.5.3.2
  override uvm_resource_base get_type_handle() {
    return get_type();
  }

  //----------------------------
  // Group -- NODOCS -- Read/Write Interface
  //----------------------------
  //
  // <read> and <write> provide a type-safe interface for getting and
  // setting the object in the resource container.  The interface is
  // type safe because the value argument for <write> and the return
  // value of <read> are T, the type supplied in the class parameter.
  // If either of these functions is used in an incorrect type context
  // the compiler will complain.

  // Function -- NODOCS --  read
  //
  //| function T read(uvm_object accessor = null);
  //
  // This function is the implementation of the uvm_resource#(T)::read 
  // method detailed in IEEE1800.2-2017 section C.2.5.4.1
  //
  // It calls uvm_resource_base::record_read_access before returning the value.
  //
  // @uvm-accellera The details of this API are specific to the Accellera implementation, and are not being considered for contribution to 1800.2

  // @uvm-ieee 1800.2-2017 auto C.2.5.4.1
  T read(uvm_object accessor = null) {
    synchronized (this) {
      record_read_access(accessor);
      return _val;
    }
  }

  // Function -- NODOCS --  write
  //
  //| function void write(T t, uvm_object accessor = null);
  //
  // This function is the implementation of the uvm_resource#(T)::write 
  // method detailed in IEEE1800.2-2017 section C.2.5.4.2
  //
  // It calls uvm_resource_base::record_write_access before writing the value.
  //
  // @uvm-accellera The details of this API are specific to the Accellera implementation, and are not being considered for contribution to 1800.2


  // @uvm-ieee 1800.2-2017 auto C.2.5.4.2
   void write(T t, uvm_object accessor = null) {
    import uvm.base.uvm_globals;
    synchronized (this) {
      if (is_read_only()) {
	uvm_report_error("resource",
			 format("resource %s is read only -- cannot modify",
				get_name()));
	return;
      }

      // Set the modified bit and record the transaction only if the value
      // has actually changed.
      if (_val is t)
	return;

      record_write_access(accessor);

      // set the value and set the dirty bit
      _val = t;
      modified = true;
    }
  }


  // Function -- NODOCS --  get_highest_precedence
  //
  // In a queue of resources, locate the first one with the highest
  // precedence whose type is T.  This function is static so that it can
  // be called from anywhere.

  static this_type get_highest_precedence(uvm_resource_types.rsrc_q_t q) {
    uvm_resource_pool rp = uvm_resource_pool.get();

    
    if (q.length == 0)
      return null;

    uvm_resource_types.rsrc_q_t tq = new uvm_resource_types.rsrc_q_t();


    for (size_t i = 0; i < q.length; ++i) {
      this_type r = cast (this_type) q.get(i);
      if (r !is null) {
        tq.push_back(r) ;
      }
    }

    uvm_resource_base rb = rp.get_highest_precedence(tq);
    this_type rsrc = cast (this_type) rb;
    if (rsrc is null)
      return null;
 
    return rsrc;
  }

}
