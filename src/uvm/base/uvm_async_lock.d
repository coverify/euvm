//
//------------------------------------------------------------------------------
//   Copyright 2014-2019 Coverify Systems Technology
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

module uvm.base.uvm_async_lock;

import esdl.base.core: AsyncLock, AsyncEvent;

class uvm_async_lock: AsyncLock
{
  import uvm.base.uvm_component: uvm_component;
  this(uvm_component parent, int tokens=0) {
    synchronized (this) {
      super(parent.get_root_entity(), tokens);
      parent.get_root.register_async_lock(this);
    }
  }
}

class uvm_async_event
{
  import uvm.base.uvm_component: uvm_component;
  private AsyncEvent _event;
  AsyncEvent event() {
    return _event;
  }
  alias event this;

  this (string name, uvm_component parent) {
    synchronized (this) {
      _event.initialize(name, parent.get_entity);
      parent.get_root.register_async_event(this);
    }
  }

}
