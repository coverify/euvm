//
//-----------------------------------------------------------------------------
// Copyright 2016-2019 Coverify Systems Technology
// Copyright 2007-2009 Mentor Graphics Corporation
// Copyright 2014 Intel Corporation
// Copyright 2007-2018 Cadence Design Systems, Inc.
// Copyright 2013-2018 NVIDIA Corporation
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
//-----------------------------------------------------------------------------

module uvm.base.uvm_links;

import uvm.base.uvm_object: uvm_object;
import uvm.base.uvm_object_defines;


// File -- NODOCS -- UVM Links
//
// The <uvm_link_base> class, and its extensions, are provided as a mechanism
// to allow for compile-time safety when trying to establish links between
// records within a <uvm_tr_database>.
//
//


// @uvm-ieee 1800.2-2017 auto 7.3.1.1
abstract class uvm_link_base: uvm_object
{

  // @uvm-ieee 1800.2-2017 auto 7.3.1.2
  this(string name="unnamed-uvm_link_base") {
    super(name);
  }

  // Group -- NODOCS --  Accessors


  // @uvm-ieee 1800.2-2017 auto 7.3.1.3.2
  void set_lhs(uvm_object lhs) {
    do_set_lhs(lhs);
  }


  // @uvm-ieee 1800.2-2017 auto 7.3.1.3.1
  uvm_object get_lhs() {
    return do_get_lhs();
  }


  // @uvm-ieee 1800.2-2017 auto 7.3.1.3.4
  void set_rhs(uvm_object rhs) {
    do_set_rhs(rhs);
  }


  // @uvm-ieee 1800.2-2017 auto 7.3.1.3.3
  uvm_object get_rhs() {
    return do_get_rhs();
  }


  // @uvm-ieee 1800.2-2017 auto 7.3.1.3.5
  void set(uvm_object lhs, uvm_object rhs) {
    synchronized (this) {
      do_set_lhs(lhs);
      do_set_rhs(rhs);
    }
  }

  // Group -- NODOCS -- Implementation Callbacks


  // @uvm-ieee 1800.2-2017 auto 7.3.1.4.2
  abstract void do_set_lhs(uvm_object lhs);


  // @uvm-ieee 1800.2-2017 auto 7.3.1.4.1
  abstract uvm_object do_get_lhs();


  // @uvm-ieee 1800.2-2017 auto 7.3.1.4.4
  abstract void do_set_rhs(uvm_object rhs);


  // @uvm-ieee 1800.2-2017 auto 7.3.1.4.3
  abstract uvm_object do_get_rhs();

}

//------------------------------------------------------------------------------
//
// CLASS -- NODOCS -- uvm_parent_child_link
//
// The ~uvm_parent_child_link~ is used to represent a Parent/Child relationship
// between two objects.
//

// @uvm-ieee 1800.2-2017 auto 7.3.2.1
class uvm_parent_child_link: uvm_link_base
{

  // Variable- m_lhs,m_rhs
  // Implementation details
  private uvm_object _m_lhs;
  private uvm_object _m_rhs;

  // Object utils
  mixin uvm_object_essentials;


  // @uvm-ieee 1800.2-2017 auto 7.3.2.2.1
  this(string name="unnamed-uvm_parent_child_link") {
    super(name);
  }


  // @uvm-ieee 1800.2-2017 auto 7.3.2.2.2
  static uvm_parent_child_link get_link(uvm_object lhs,
					uvm_object rhs,
					string name="pc_link") {
    uvm_parent_child_link get_link_ = new uvm_parent_child_link(name);
    get_link_.set(lhs, rhs);
    return get_link_;
  }

  // Group -- NODOCS -- Implementation Callbacks

  // Function -- NODOCS -- do_set_lhs
  // Sets the left-hand-side (Parent)
  //
  override void do_set_lhs(uvm_object lhs) {
    synchronized (this) {
      _m_lhs = lhs;
    }
  }

  // Function -- NODOCS -- do_get_lhs
  // Retrieves the left-hand-side (Parent)
  //
  override uvm_object do_get_lhs() {
    synchronized (this) {
      return _m_lhs;
    }
  }

  // Function -- NODOCS -- do_set_rhs
  // Sets the right-hand-side (Child)
  //
  override void do_set_rhs(uvm_object rhs) {
    synchronized (this) {
      _m_rhs = rhs;
    }
  }

   // Function -- NODOCS -- do_get_rhs
   // Retrieves the right-hand-side (Child)
   //
  override uvm_object do_get_rhs() {
    synchronized (this) {
      return _m_rhs;
    }
  }
}

//------------------------------------------------------------------------------
//
// CLASS -- NODOCS -- uvm_cause_effect_link
//
// The ~uvm_cause_effect_link~ is used to represent a Cause/Effect relationship
// between two objects.
//

// @uvm-ieee 1800.2-2017 auto 7.3.3.1
class uvm_cause_effect_link: uvm_link_base
{

  // Variable- m_lhs,m_rhs
  // Implementation details
  private uvm_object _m_lhs;
  private uvm_object _m_rhs;

  // Object utils
  mixin uvm_object_essentials;


  // @uvm-ieee 1800.2-2017 auto 7.3.3.2.1
  this(string name="unnamed-uvm_cause_effect_link") {
    super(name);
  }


  // @uvm-ieee 1800.2-2017 auto 7.3.3.2.2
  static uvm_cause_effect_link get_link(uvm_object lhs,
					uvm_object rhs,
					string name="ce_link") {
    auto get_link_ = new uvm_cause_effect_link(name);
    get_link_.set(lhs, rhs);
    return get_link_;
  }

  // Group -- NODOCS -- Implementation Callbacks

  // Function -- NODOCS -- do_set_lhs
  // Sets the left-hand-side (Cause)
  //
  override void do_set_lhs(uvm_object lhs) {
    synchronized (this) {
      _m_lhs = lhs;
    }
  }

  // Function -- NODOCS -- do_get_lhs
  // Retrieves the left-hand-side (Cause)
  //
  override uvm_object do_get_lhs() {
    synchronized (this) {
      return _m_lhs;
    }
  }

  // Function -- NODOCS -- do_set_rhs
  // Sets the right-hand-side (Effect)
  //
  override void do_set_rhs(uvm_object rhs) {
    synchronized (this) {
      _m_rhs = rhs;
    }
  }

  // Function -- NODOCS -- do_get_rhs
  // Retrieves the right-hand-side (Effect)
  //
  override uvm_object do_get_rhs() {
    synchronized (this) {
      return _m_rhs;
    }
  }
}

//------------------------------------------------------------------------------
//
// CLASS -- NODOCS -- uvm_related_link
//
// The ~uvm_related_link~ is used to represent a generic "is related" link
// between two objects.
//

// @uvm-ieee 1800.2-2017 auto 7.3.4.1
class uvm_related_link: uvm_link_base
{

  // Variable- m_lhs,m_rhs
  // Implementation details
  private uvm_object _m_lhs;
  private uvm_object _m_rhs;

  // Object utils
  mixin uvm_object_essentials;


  // @uvm-ieee 1800.2-2017 auto 7.3.4.2.1
  this(string name="unnamed-uvm_related_link") {
    super(name);
  }


  // @uvm-ieee 1800.2-2017 auto 7.3.4.2.2
  static uvm_related_link get_link(uvm_object lhs,
				   uvm_object rhs,
				   string name="ce_link") {
    auto get_link_ = new uvm_related_link(name);
    get_link_.set(lhs, rhs);
    return get_link_;
  }

  // Group -- NODOCS -- Implementation Callbacks

  // Function -- NODOCS -- do_set_lhs
  // Sets the left-hand-side
  //
  override void do_set_lhs(uvm_object lhs) {
    synchronized (this) {
      _m_lhs = lhs;
    }
  }

  // Function -- NODOCS -- do_get_lhs
  // Retrieves the left-hand-side
  //
  override uvm_object do_get_lhs() {
    synchronized (this) {
      return _m_lhs;
    }
  }

  // Function -- NODOCS -- do_set_rhs
  // Sets the right-hand-side
  //
  override void do_set_rhs(uvm_object rhs) {
    synchronized (this) {
      _m_rhs = rhs;
    }
  }

  // Function -- NODOCS -- do_get_rhs
  // Retrieves the right-hand-side
  //
  override uvm_object do_get_rhs() {
    synchronized (this) {
      return _m_rhs;
    }
  }
}
