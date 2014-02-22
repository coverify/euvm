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

private import esdl.base.core: Event;

// Mimics the SystemVerilog mailbox behaviour
class mailbox(T)
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

  private Event _readEvent;
  private Event _writeEvent;

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

  public this(size_t bound = 0) {
    synchronized(this) {
      _bound = bound;
      _readEvent.init("readEvent");
      _writeEvent.init("writeEvent");
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
	_writeEvent.wait();
      }
      synchronized(this) {
	if(numFilled !is 0) {
	  readBuffer(val);
	  _readEvent.notify();
	  break;
	}
      }
    }
  }

  void peek(ref T val) {
    while(true) {
      if(numFilled is 0) {
	_writeEvent.wait();
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
	  _readEvent.wait();
	}
      }
      synchronized(this) {
	if(numFree !is 0) {
	  writeBuffer(val);
	  _writeEvent.notify();
	  break;
	}
      }
    }
  }

  bool try_get(ref T val) {
    synchronized(this) {
      if(numFilled is 0) return false;
      readBuffer(val);
      _readEvent.notify();
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
      _writeEvent.notify();
      return true;
    }
  }

}
