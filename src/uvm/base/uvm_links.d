//
//-----------------------------------------------------------------------------
//   Copyright 2007-2011 Mentor Graphics Corporation
//   Copyright 2007-2011 Cadence Design Systems, Inc.
//   Copyright 2010      Synopsys, Inc.
//   Copyright 2013      NVIDIA Corporation
//   Copyright 2016      Coverify Systems Technology
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


// File: UVM Links
//
// The <uvm_link_base> class, and its extensions, are provided as a mechanism
// to allow for compile-time safety when trying to establish links between
// records within a <uvm_tr_database>.
//
//

//------------------------------------------------------------------------------
//
// CLASS: uvm_link_base
//
// The ~uvm_link_base~ class presents a simple API for defining a link between
// any two objects.
//
// Using extensions of this class, a <uvm_tr_database> can determine the
// type of links being passed, without relying on "magic" string names.
//
// For example:
// |
// | virtual function void do_establish_link(uvm_link_base link);
// |   uvm_parent_child_link pc_link;
// |   uvm_cause_effect_link ce_link;
// |
// |   if ($cast(pc_link, link)) begin
// |      // Record the parent-child relationship
// |   end
// |   else if ($cast(ce_link, link)) begin
// |      // Record the cause-effect relationship
// |   end
// |   else begin
// |      // Unsupported relationship!
// |   end
// | endfunction : do_establish_link
//
abstract class uvm_link_base: uvm_object
{
  // Function: new
  // Constructor
  //
  // Parameters:
  // name - Instance name
  this(string name="unnamed-uvm_link_base") {
    super(name);
  }

  // Group:  Accessors

  // Function: set_lhs
  // Sets the left-hand-side of the link
  //
  // Triggers the <do_set_lhs> callback.
  void set_lhs(uvm_object lhs) {
    do_set_lhs(lhs);
  }

  // Function: get_lhs
  // Gets the left-hand-side of the link
  //
  // Triggers the <do_get_lhs> callback
  uvm_object get_lhs() {
    return do_get_lhs();
  }

  // Function: set_rhs
  // Sets the right-hand-side of the link
  //
  // Triggers the <do_set_rhs> callback.
  void set_rhs(uvm_object rhs) {
    do_set_rhs(rhs);
  }

  // Function: get_rhs
  // Gets the right-hand-side of the link
  //
  // Triggers the <do_get_rhs> callback
  uvm_object get_rhs() {
    return do_get_rhs();
  }

  // Function: set
  // Convenience method for setting both sides in one call.
  //
  // Triggers both the <do_set_rhs> and <do_set_lhs> callbacks.
  void set(uvm_object lhs, uvm_object rhs) {
    synchronized(this) {
      do_set_lhs(lhs);
      do_set_rhs(rhs);
    }
  }

  // Group: Implementation Callbacks

  // Function: do_set_lhs
  // Callback for setting the left-hand-side
  abstract void do_set_lhs(uvm_object lhs);

  // Function: do_get_lhs
  // Callback for retrieving the left-hand-side
  abstract uvm_object do_get_lhs();

  // Function: do_set_rhs
  // Callback for setting the right-hand-side
  abstract void do_set_rhs(uvm_object rhs);

  // Function: do_get_rhs
  // Callback for retrieving the right-hand-side
  abstract uvm_object do_get_rhs();

}

//------------------------------------------------------------------------------
//
// CLASS: uvm_parent_child_link
//
// The ~uvm_parent_child_link~ is used to represent a Parent/Child relationship
// between two objects.
//

class uvm_parent_child_link: uvm_link_base
{

  // Variable- m_lhs,m_rhs
  // Implementation details
  private uvm_object _m_lhs;
  private uvm_object _m_rhs;

  // Object utils
  mixin uvm_object_essentials;

  // Function: new
  // Constructor
  //
  // Parameters:
  // name - Instance name
  this(string name="unnamed-uvm_parent_child_link") {
    super(name);
  }

  // Function: get_link
  // Constructs a pre-filled link
  //
  // This allows for simple one-line link creations.
  // | my_db.establish_link(uvm_parent_child_link::get_link(record1, record2));
  //
  // Parameters:
  // lhs - Left hand side reference
  // rhs - Right hand side reference
  // name - Optional name for the link object
  //
  static uvm_parent_child_link get_link(uvm_object lhs,
					uvm_object rhs,
					string name="pc_link") {
    uvm_parent_child_link pc_link = new uvm_parent_child_link(name);
    pc_link.set(lhs, rhs);
    return pc_link;
  }

  // Group: Implementation Callbacks

  // Function: do_set_lhs
  // Sets the left-hand-side (Parent)
  //
  override void do_set_lhs(uvm_object lhs) {
    synchronized(this) {
      _m_lhs = lhs;
    }
  }

  // Function: do_get_lhs
  // Retrieves the left-hand-side (Parent)
  //
  override uvm_object do_get_lhs() {
    synchronized(this) {
      return _m_lhs;
    }
  }

  // Function: do_set_rhs
  // Sets the right-hand-side (Child)
  //
  override void do_set_rhs(uvm_object rhs) {
    synchronized(this) {
      _m_rhs = rhs;
    }
  }

   // Function: do_get_rhs
   // Retrieves the right-hand-side (Child)
   //
  override uvm_object do_get_rhs() {
    synchronized(this) {
      return _m_rhs;
    }
  }
}

//------------------------------------------------------------------------------
//
// CLASS: uvm_cause_effect_link
//
// The ~uvm_cause_effect_link~ is used to represent a Cause/Effect relationship
// between two objects.
//

class uvm_cause_effect_link: uvm_link_base
{

  // Variable- m_lhs,m_rhs
  // Implementation details
  private uvm_object _m_lhs;
  private uvm_object _m_rhs;

  // Object utils
  mixin uvm_object_essentials;

  // Function: new
  // Constructor
  //
  // Parameters:
  // name - Instance name
  this(string name="unnamed-uvm_cause_effect_link") {
    super(name);
  }

  // Function: get_link
  // Constructs a pre-filled link
  //
  // This allows for simple one-line link creations.
  // | my_db.establish_link(uvm_cause_effect_link::get_link(record1, record2));
  //
  // Parameters:
  // lhs - Left hand side reference
  // rhs - Right hand side reference
  // name - Optional name for the link object
  //
  static uvm_cause_effect_link get_link(uvm_object lhs,
					uvm_object rhs,
					string name="ce_link") {
    auto ce_link = new uvm_cause_effect_link(name);
    ce_link.set(lhs, rhs);
    return ce_link;
  }

  // Group: Implementation Callbacks

  // Function: do_set_lhs
  // Sets the left-hand-side (Cause)
  //
  override void do_set_lhs(uvm_object lhs) {
    synchronized(this) {
      _m_lhs = lhs;
    }
  }

  // Function: do_get_lhs
  // Retrieves the left-hand-side (Cause)
  //
  override uvm_object do_get_lhs() {
    synchronized(this) {
      return _m_lhs;
    }
  }

  // Function: do_set_rhs
  // Sets the right-hand-side (Effect)
  //
  override void do_set_rhs(uvm_object rhs) {
    synchronized(this) {
      _m_rhs = rhs;
    }
  }

  // Function: do_get_rhs
  // Retrieves the right-hand-side (Effect)
  //
  override uvm_object do_get_rhs() {
    synchronized(this) {
      return _m_rhs;
    }
  }
}

//------------------------------------------------------------------------------
//
// CLASS: uvm_related_link
//
// The ~uvm_related_link~ is used to represent a generic "is related" link
// between two objects.
//

class uvm_related_link: uvm_link_base
{

  // Variable- m_lhs,m_rhs
  // Implementation details
  private uvm_object _m_lhs;
  private uvm_object _m_rhs;

  // Object utils
  mixin uvm_object_essentials;

  // Function: new
  // Constructor
  //
  // Parameters:
  // name - Instance name
  this(string name="unnamed-uvm_related_link") {
    super(name);
  }

  // Function: get_link
  // Constructs a pre-filled link
  //
  // This allows for simple one-line link creations.
  // | my_db.establish_link(uvm_related_link::get_link(record1, record2));
  //
  // Parameters:
  // lhs - Left hand side reference
  // rhs - Right hand side reference
  // name - Optional name for the link object
  //
  static uvm_related_link get_link(uvm_object lhs,
				   uvm_object rhs,
				   string name="ce_link") {
    auto ce_link = new uvm_related_link(name);
    ce_link.set(lhs, rhs);
    return ce_link;
  }

  // Group: Implementation Callbacks

  // Function: do_set_lhs
  // Sets the left-hand-side
  //
  override void do_set_lhs(uvm_object lhs) {
    synchronized(this) {
      _m_lhs = lhs;
    }
  }

  // Function: do_get_lhs
  // Retrieves the left-hand-side
  //
  override uvm_object do_get_lhs() {
    synchronized(this) {
      return _m_lhs;
    }
  }

  // Function: do_set_rhs
  // Sets the right-hand-side
  //
  override void do_set_rhs(uvm_object rhs) {
    synchronized(this) {
      _m_rhs = rhs;
    }
  }

  // Function: do_get_rhs
  // Retrieves the right-hand-side
  //
  override uvm_object do_get_rhs() {
    synchronized(this) {
      return _m_rhs;
    }
  }
}
