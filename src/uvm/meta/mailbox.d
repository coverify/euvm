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

private import esdl.base.core;
import std.traits;
import std.stdio;

// Fifo

// non-blocking interface
interface mailbox_in_nb_if(T)
{
  alias Port!(mailbox_in_nb_if!T) port_t;
  public bool nbRead(ref T);
  public bool nbPeek(ref T);
  public Event writeEvent();
  public void registerPort(BasePort port);
}

// Blocking interface
interface mailbox_in_if(T)
{
  alias PortObj!(mailbox_in_if!T) port_t;
  public void read(ref T);
  public T read();
  public void peek(ref T);
  public T peek();
  public void registerPort(BasePort port);
}

interface FifoInIF(T): mailbox_in_if!T, mailbox_in_nb_if!T
{
  size_t numFilled();
}

// non-blocking interface
interface mailbox_out_nb_if(T)
{
  alias Port!(mailbox_out_nb_if!T) port_t;
  public bool nbWrite(ref T);
  public Event readEvent();
  public void registerPort(BasePort port);
}
// Blocking interface
interface mailbox_out_if(T)
{
  alias Port!(mailbox_out_if!T) port_t;
  public void write(T t);
  public void registerPort(BasePort port);
}

interface FifoOutIF(T): mailbox_out_if!T, mailbox_out_nb_if!T
{
  size_t numFree();
}

class mailbox(T): Channel, FifoInIF!T, FifoOutIF!T
{
  alias Port!(mailbox_in_nb_if!T) port_inb_t;
  alias Port!(mailbox_in_if!T) port_ib_t;
  alias Port!(mailbox_out_nb_if!T) port_onb_t;
  alias Port!(mailbox_out_if!T) port_ob_t;

 protected:
  T [] _buffer;

  size_t _free;
  size_t _readIndex;
  size_t _writeIndex;

  size_t _bound;
  // For book-keeping whether ports have been attached to the Fifo
  bool _readerp = false;
  bool _writerp = false;

  size_t _numReadable = 0;
  size_t _numRead = 0;
  size_t _numWritten = 0;

  Event _readEvent;
  Event _writeEvent;

  private void GrowBuffer() {
    synchronized(this) {
      size_t S = _buffer.length;
      _buffer.length *= 2;
      _free += S;
      import std.exception;
      import std.string;
      // enforce(_readIndex is _writeIndex+1 ||
      // 	(_readIndex is 0 && _writeIndex is _buffer.length-1),
      // 	format("_readIndex, %d, _writeIndex %d", _readIndex, _writeIndex));
      for(size_t i = 0; i !is _writeIndex; ++i) {
	_buffer[S+i] = _buffer[i];
      }
      _writeIndex += S;
    }
  }

 public:
  this(size_t bound=0) {
    _readEvent.init("_readEvent", this);
    _writeEvent.init("_writeEvent", this);
    this._bound=bound;
    if(_bound is 0) {
      _buffer.length = 4;
    }
    else {
      _buffer.length=_bound;
    }
    
    _free = _buffer.length;
  }

  // void registerPort(IF)(PortObj!IF p)

  void registerPort(BasePort p) {
    if(cast(PortObj!(mailbox_in_nb_if!T)) p ||
       cast(PortObj!(mailbox_in_if!T)) p) {
      if(_readerp is true) {
	assert(false, "Only one input port can be connected to Fifo");
      }
      else _readerp = true;
    }
    else if(cast(PortObj!(mailbox_out_nb_if!T)) p ||
	    cast(PortObj!(mailbox_out_if!T)) p) {
      if(_writerp is true) {
	assert(false, "Only one input port can be connected to Fifo");
      }
      else _writerp = true;
    }
    else assert(false, "Incompatible port");
  }

  void registerPort(Port!(mailbox_in_nb_if!T) p) {
    if(_readerp is true)
      assert(false, "Only one input port can be connected to Fifo");
    else
      _readerp = true;
  }

  void registerPort(port_ib_t p) {
    if(_readerp is true)
      assert(false, "Only one input port can be connected to Fifo");
    else
      _readerp = true;
  }

  void registerPort(port_onb_t p) {
    if(_writerp is true)
      assert(false, "Only one output port can be connected to Fifo");
    else
      _writerp = true;
  }

  void registerPort(port_ob_t p) {
    if(_writerp is true)
      assert(false, "Only one output port can be connected to Fifo");
    else
      _writerp = true;
  }

  size_t numFilled() {
    synchronized(this) {
      return _numReadable - _numRead;
    }
  }

  size_t numFree() {
    synchronized(this)
      return _buffer.length - _numReadable - _numWritten;
  }

  alias numFilled num;

  Event writeEvent() {
    return _writeEvent;
  }

  Event readEvent() {
    return _readEvent;
  }

  // void _esdl__elaborate()
  // {
  //   alias typeof(this) T;
  //   alias typeof(_readEvent) L;

  //   _esdl__elab!0(this, _readEvent , "_readEvent", null);
  //   _esdl__elab!0(this, _writeEvent, "_writeEvent", null);
  // }

  bool readBuffer(ref T val) {
    synchronized(this) {
      if(_free is _buffer.length) return false;
      val = _buffer[_readIndex];
      _free += 1;
      _readIndex =(1 + _readIndex) % _buffer.length;
      return true;
    }
  }

  bool peekBuffer(ref T val) {
    synchronized(this) {
      if(_free is _buffer.length) return false;
      val = _buffer[_readIndex];
      return true;
    }
  }

  bool writeBuffer(T val) {
    synchronized(this) {
      if(_free is 0) return false;
      _buffer[_writeIndex] = val;
      _free -= 1;
      _writeIndex =(1 + _writeIndex) % _buffer.length;
      return true;
    }
  }

  void read(ref T val) {
    bool _done = false;
    while(!_done) {
      if(numFilled() is 0) {
	_writeEvent.wait();
      }
      synchronized(this) {
	if(numFilled() !is 0) {
	  _done = true;
	  _numRead++;
	  readBuffer(val);
	  requestUpdate();
	}
      }
    }
  }

  T read() {
    T tmp;
    this.read(tmp);
    return tmp;
  }

  void peek(ref T val) {
    bool _done = false;
    while(!_done) {
      if(numFilled() is 0) {
	_writeEvent.wait();
      }
      synchronized(this) {
	if(numFilled() !is 0) {
	  _done = true;
	  // _numPeek++;
	  peekBuffer(val);
	  // requestUpdate();
	}
      }
    }
  }

  T peek() {
    T tmp;
    this.peek(tmp);
    return tmp;
  }

  bool nbRead(ref T val) {
    synchronized(this) {
      if(numFilled() is 0) return false;
      _numRead++;
      readBuffer(val);
      requestUpdate();
      return true;
    }
  }

  bool nbPeek(ref T val) {
    synchronized(this) {
      if(numFilled() is 0) return false;
      // _numPeek++;
      peekBuffer(val);
      // requestUpdate();
      return true;
    }
  }

  void write(T val) {
    bool _done = false;
    while(!_done) {
      if(_bound is 0) {
	synchronized(this) {
	  if(numFree() is 0) {
	    GrowBuffer();
	  }
	}
      }
      else {
	if(numFree() is 0) {
	  _readEvent.wait();
	}
      }
      synchronized(this) {
	if(numFree() !is 0) {
	  _done = true;
	  _numWritten++;
	  writeBuffer(val);
	  requestUpdate();
	}
      }
    }
  }

  bool nbWrite(ref T val) {
    synchronized(this) {
      if(_bound is 0) {
	if(numFree() is 0) {
	  GrowBuffer();
	}
      }
      else {
	if(numFree() is 0) {
	  return false;
	}
      }
      _numWritten++;
      writeBuffer(val);
      requestUpdate();
      return true;
    }
  }

  alias read get;
  alias nbRead try_get;
  alias write put;
  alias nbWrite try_put;
  alias nbPeek try_peek;

  override protected void update() {
    if(_numRead > 0) {
      // writeln("Notifying Read");
      _readEvent.notify(0);
    }
    if(_numWritten > 0) {
      // writeln("Notifying Write");
      _writeEvent.notify(0);
    }
    _numRead = 0;
    _numWritten = 0;
    _numReadable = _buffer.length - _free;
  }

  static void _esdl__inst(size_t I=0, U, L)(U u, ref L l)
  {
    synchronized(u) {
      if(l is null) {
	l = new L();
      }
    }
  }

  static void _esdl__elab(size_t I, U, L)(U u, ref L l, uint[] indices=null) {
    l._esdl__inst!I(u, l);
    synchronized(l) {
      static if(is(U unused: ElabContext)) {
	u._esdl__addChildObj(l);
      }
      l._esdl__nomenclate!I(u, indices);
      l._esdl__setParent(u);
      _esdl__elabMems(l);
    }
  }
}

// @_esdl__component struct Fifo(T, size_t _bound = 0)
// {
//   // enum bool _thisIsFifo = true;
//   public mailbox!(T, _bound) _fifoObj = void;

//   @property package ref mailbox!(T, _bound) _esdl__objRef() {
//     return _fifoObj;
//   }

//   @property mailbox!(T, _bound) _esdl__obj() {
//     return _fifoObj;
//   }

//   alias _esdl__obj this;

//   // Disallow Fifo assignment
//   @disable private void opAssign(Fifo e);
//   @disable private this(this);

//   public final void init() {
//     if(_fifoObj is null) {
//       _fifoObj = new mailbox!(T, _bound);
//     }
//   }

//   void _esdl__inst(size_t I=0, U, L)(U u, ref L l) {
//     _esdl__objRef._esdl__inst!I(u, _esdl__objRef);
//   }

//   void _esdl__elab(size_t I, U, L)(U u, ref L l, uint[] indices=null) {
//     l._esdl__inst!I(u, l);
//     synchronized(l._esdl__objRef) {
//       static if(is(U unused: ElabContext)) {
// 	u._esdl__addChild(l);
//       }
//       l._esdl__objRef._esdl__nomenclate!I(u, indices);
//       l._esdl__objRef._esdl__setParent(u);
//       _esdl__elabMems(l._esdl__objRef);
//     }
//   }
// }

