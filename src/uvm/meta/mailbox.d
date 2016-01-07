// This file lists D routines required for coding UVM
//
//------------------------------------------------------------------------------
// Copyright 2012-2014 Coverify Systems Technology
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
module uvm.meta.mailbox;

private import esdl.base.core: Event, EntityIntf;
private import core.sync.semaphore: Semaphore;

// Mimics the SystemVerilog mailbox behaviour
abstract class MailboxBase(T)
{
  
  private T[] _buffer;

  private size_t _free;
  private size_t _readIndex;
  private size_t _writeIndex;

  // _bound is effectively immutable -- set only in the constructor
  private size_t _bound;
  private size_t bound() {
    return _bound;
  }

  abstract void readWait();
  abstract void writeWait();
  abstract void readNotify();
  abstract void writeNotify();
  
  private void GrowBuffer() {
    synchronized(this) {
      size_t size = _buffer.length;
      _buffer.length = 2 * size;
      _free += size;
      for(size_t i = 0; i != _writeIndex; ++i) {
	_buffer[size+i] = _buffer[i];
      }
      _writeIndex += size;
    }
  }

  this(size_t bound = 0) {
    synchronized(this) {
      _bound = bound;
      if(bound is 0) {
	// no bound, start with 4
	_buffer.length = 4;
      }
      else {
	_buffer.length = bound;
      }
      _free = _buffer.length;
    }
  }


  size_t numFilled() {
    synchronized(this) {
      return _buffer.length - _free; // _numReadable - _numRead;
    }
  }

  alias num = numFilled;

  // static if(N != 0) {
  size_t numFree() {
    synchronized(this) {
      return _free; // _buffer.length - _numReadable - _numWritten;
    }
  }
  // }

  private void readBuffer(ref T val) {
    synchronized(this) {
      if(numFilled is 0) {
	// this should never happen
	assert(false, "readBuffer called when numFilled is 0");
      }
      val = _buffer[_readIndex];
      _free += 1;
      _readIndex =(1 + _readIndex) % _buffer.length;
    }
  }

  private void peekBuffer(ref T val) {
    synchronized(this) {
      if(numFilled is 0) {
	// this should never happen
	assert(false, "peekBuffer called when numFilled is 0");
      }
      val = _buffer[_readIndex];
    }
  }

  private void writeBuffer(T val) {
    synchronized(this) {
      if(numFree is 0) {
	// this should never happen
	assert(false, "writeBuffer called when numFree is 0");
      }
      _buffer[_writeIndex] = val;
      _free -= 1;
      _writeIndex =(1 + _writeIndex) % _buffer.length;
    }
  }

  void get(ref T val) {
    while(true) {
      if(numFilled is 0) {
	writeWait();
      }
      synchronized(this) {
	if(numFilled !is 0) {
	  readBuffer(val);
	  readNotify();
	  break;
	}
      }
    }
  }

  void peek(ref T val) {
    while(true) {
      if(numFilled is 0) {
	writeWait();
      }
      synchronized(this) {
	if(numFilled !is 0) {
	  peekBuffer(val);
	  break;
	}
      }
    }
  }

  void put(T val) {
    while(true) {
      if(bound is 0) {
	synchronized(this) {
	  if(numFree is 0) {
	    GrowBuffer();
	  }
	}
      }
      else {
	if(numFree is 0) {
	  readWait();
	}
      }
      synchronized(this) {
	if(numFree !is 0) {
	  writeBuffer(val);
	  writeNotify();
	  break;
	}
      }
    }
  }

  bool try_get(ref T val) {
    synchronized(this) {
      if(numFilled is 0) return false;
      readBuffer(val);
      readNotify();
      return true;
    }
  }

  bool try_peek(ref T val) {
    synchronized(this) {
      if(numFilled is 0) return false;
      peekBuffer(val);
      return true;
    }
  }

  bool try_put(T val) {
    synchronized(this) {
      if(bound is 0) {
	if(numFree is 0) {
	  GrowBuffer();
	}
      }
      else {
	if(numFree is 0) {
	  return false;
	}
      }
      writeBuffer(val);
      writeNotify();
      return true;
    }
  }

}

class Mailbox(T): MailboxBase!T
{
  private Event _readEvent;
  private Event _writeEvent;

  this(size_t bound = 0) {
    synchronized(this) {
      super(bound);
      _readEvent.init("readEvent", EntityIntf.getContextEntity());
      _writeEvent.init("writeEvent", EntityIntf.getContextEntity());
    }
  }
  
  override void readWait() {_readEvent.wait();}
  override void writeWait() {_writeEvent.wait();}
  override void readNotify() {_readEvent.notify();}
  override void writeNotify() {_writeEvent.notify();}
}

class MailOutbox(T): MailboxBase!T
{
  private Event _readEvent;
  private Semaphore _writeEvent;

  this(size_t bound = 0) {
    synchronized(this) {
      super(bound);
      _readEvent.init("readEvent", EntityIntf.getContextEntity());
      _writeEvent = new Semaphore;
    }
  }
  
  override void readWait() {_readEvent.wait();}
  override void writeWait() {_writeEvent.wait();}
  override void readNotify() {_readEvent.notify();}
  override void writeNotify() {_writeEvent.notify();}
}

class MailInbox(T): MailboxBase!T
{
  private Semaphore _readEvent;
  private Event _writeEvent;

  this(size_t bound = 0) {
    synchronized(this) {
      super(bound);
      _writeEvent.init("writeEvent", EntityIntf.getContextEntity());
      _readEvent = new Semaphore;
    }
  }
  
  override void readWait() {_readEvent.wait();}
  override void writeWait() {_writeEvent.wait();}
  override void readNotify() {_readEvent.notify();}
  override void writeNotify() {_writeEvent.notify();}
}
