//----------------------------------------------------------------------
// Copyright 2016-2021 Coverify Systems Technology
// Copyright 2011-2018 Cadence Design Systems, Inc.
// Copyright 2014 Intel Corporation
// Copyright 2011-2014 Mentor Graphics Corporation
// Copyright 2014-2020 NVIDIA Corporation
// Copyright 2014 Semifore
// Copyright 2010-2018 Synopsys, Inc.
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

// CLASS -- NODOCS -- uvm_tlm_time
// Canonical time type that can be used in different timescales
//
// This time type is used to represent time values in a canonical
// form that can bridge initiators and targets located in different
// timescales and time precisions.
//
// For a detailed explanation of the purpose for this class,
// see <Why is this necessary>.
//
module uvm.tlm2.uvm_tlm_time;

import esdl.data.time;
import uvm.base.uvm_globals;
import uvm.base.uvm_scope;
import uvm.meta.misc;

// @uvm-ieee 1800.2-2020 auto 5.6.1
class uvm_time
{
  static class uvm_scope: uvm_scope_base
  {
    // @uvm_private_sync
    double _m_resolution = 1.0e-12; // ps by default
  }
  // mixin (uvm_scope_sync_string);
  // uvm_scope uvm_scope
  static uvm_scope _uvm_scope_inst() {return uvm_scope.get_instance!uvm_scope;}
  // uvm_scope_private _m_resolution double uvm_scope
  static private double m_resolution() {synchronized (_uvm_scope_inst) return _uvm_scope_inst._m_resolution;}
  static private void m_resolution(double val) {synchronized (_uvm_scope_inst) _uvm_scope_inst._m_resolution = val;}

  private real _m_res;
  // local time _m_time;
  private long _m_time;  // Number of 'm_res' time units,
  private string _m_name;

  // Function -- NODOCS -- set_time_resolution
  // Set the default canonical time resolution.
  //
  // Must be a power of 10.
  // When co-simulating with SystemC, it is recommended
  // that default canonical time resolution be set to the
  // SystemC time resolution.
  //
  // By default, the default resolution is 1.0e-12 (ps)
  //

  // Note that the time resolution defined here is to match the time
  // resolution of any co-simulating systemC kernel. Since there could
  // be only a single instance of SystemC Kernel, the time resolution
  // here would really be a shared static
  static void set_time_resolution(real res) {
    // Actually, it does not *really* need to be a power of 10.
    m_resolution = res;
  }

  // Function -- NODOCS -- new
  // Create a new canonical time value.
  //
  // The new value is initialized to 0.
  // If a resolution is not specified,
  // the default resolution,
  // as specified by <set_time_resolution()>,
  // is used.
  // @uvm-ieee 1800.2-2020 auto 5.6.2.1
  this(string name = "uvm_tlm_time", real res = 0) {
    synchronized (this) {
      _m_name = name;
      _m_res = (res == 0) ? m_resolution : res;
      reset();
    }
  }


  // Function -- NODOCS -- get_name
  // Return the name of this instance
  //
  // @uvm-ieee 1800.2-2020 auto 5.6.2.3
  string get_name() {
    // _m_name is effectively immutable since it is set only in the
    // constructor
    return _m_name;
  }


  // Function -- NODOCS -- reset
  // Reset the value to 0
  // @uvm-ieee 1800.2-2020 auto 5.6.2.4
  void reset() {
    synchronized (this) {
      _m_time = 0;
    }
  }


  // Scale a timescaled value to 'm_res' units,
  // the the specified scale
  private real to_m_res(real t, Time scaled, real secs) {
    // ToDo: Check resolution
    synchronized (this) {
      return t / scaled.to!real * (secs/_m_res);
    }
  }


  // Function -- NODOCS -- get_realtime
  // Return the current canonical time value,
  // scaled for the caller's timescale
  //
  // ~scaled~ must be a time literal value that corresponds
  // to the number of seconds specified in ~secs~ (1ns by default).
  // It must be a time literal value that is greater or equal
  // to the current timescale.
  //
  //| #(delay.get_realtime(1ns));
  //| #(delay.get_realtime(1fs, 1.0e-15));
  //
  // @uvm-ieee 1800.2-2020 auto 5.6.2.5
  real get_realtime(Time scaled, real secs = 1.0e-9) {
    synchronized (this) {
      return _m_time * scaled.to!real * _m_res/secs;
    }
  }


  // Function -- NODOCS -- incr
  // Increment the time value by the specified number of scaled time unit
  //
  // ~t~ is a time value expressed in the scale and precision
  // of the caller.
  // ~scaled~ must be a time literal value that corresponds
  // to the number of seconds specified in ~secs~ (1ns by default).
  // It must be a time literal value that is greater or equal
  // to the current timescale.
  //
  //| delay.incr(1.5ns, 1ns);
  //| delay.incr(1.5ns, 1ps, 1.0e-12);
  //
  // @uvm-ieee 1800.2-2020 auto 5.6.2.6
  void incr(real t, Time scaled, real secs = 1.0e-9) {
    synchronized (this) {
      if (t < 0.0) {
	uvm_error("UVM/TLM/TIMENEG", "Cannot increment uvm_tlm_time " ~
		  "variable " ~ _m_name ~ " by a negative value");
	return;
      }
      if (scaled.isZero()) {
	uvm_fatal("UVM/TLM/BADSCALE",
		  "uvm_tlm_time::incr() called with a scaled time" ~
		  " literal that is smaller than the current timescale");
      }

      _m_time += cast (ulong) to_m_res(t, scaled, secs);
    }
  }


  // Function -- NODOCS -- decr
  // Decrement the time value by the specified number of scaled time unit
  //
  // ~t~ is a time value expressed in the scale and precision
  // of the caller.
  // ~scaled~ must be a time literal value that corresponds
  // to the number of seconds specified in ~secs~ (1ns by default).
  // It must be a time literal value that is greater or equal
  // to the current timescale.
  //
  //| delay.decr(200ps, 1ns);
  //
  // @uvm-ieee 1800.2-2020 auto 5.6.2.7
  void decr(real t, Time scaled, real secs) {
    synchronized (this) {
      if (t < 0.0) {
	uvm_error("UVM/TLM/TIMENEG", "Cannot decrement uvm_tlm_time" ~
		  " variable " ~ _m_name ~ " by a negative value");
	return;
      }
      if (scaled.isZero()) {
	uvm_fatal("UVM/TLM/BADSCALE",
		  "uvm_tlm_time::decr() called with a scaled time" ~
		  " literal that is smaller than the current timescale");
      }

      _m_time -= cast (ulong) to_m_res(t, scaled, secs);

      if (_m_time < 0.0) {
	uvm_error("UVM/TLM/TOODECR",
		  "Cannot decrement uvm_tlm_time variable " ~ _m_name ~
		  " to a negative value");
	reset();
      }
    }
  }


  // Function -- NODOCS -- get_abstime
  // Return the current canonical time value,
  // in the number of specified time unit, reguardless of the
  // current timescale of the caller.
  //
  // ~secs~ is the number of seconds in the desired time unit
  // e.g. 1e-9 for nanoseconds.
  //
  //| $write("%.3f ps\n", delay.get_abstime(1e-12));
  //
  // @uvm-ieee 1800.2-2020 auto 5.6.2.8
  real get_abstime(real secs) {
    synchronized (this) {
      return _m_time * _m_res/secs;
    }
  }


  // Function -- NODOCS -- set_abstime
  // Set the current canonical time value,
  // to the number of specified time unit, reguardless of the
  // current timescale of the caller.
  //
  // ~secs~ is the number of seconds in the time unit in the value ~t~
  // e.g. 1e-9 for nanoseconds.
  //
  //| delay.set_abstime(1.5, 1e-12));
  //
  // @uvm-ieee 1800.2-2020 auto 5.6.2.9
  void set_abstime(real t, real secs) {
    synchronized (this) {
      _m_time = cast (long) (t * secs/_m_res);
    }
  }
}

alias uvm_tlm_time = uvm_time;

// Group -- NODOCS -- Why is this necessary
//
// Integers are not sufficient, on their own,
// to represent time without any ambiguity:
// you need to know the scale of that integer value.
// That scale is information conveyed outside of that integer.
// In SystemVerilog, it is based on the timescale
// that was active when the code was compiled.
// SystemVerilog properly scales time literals, but not integer values.
// That's because it does not know the difference between an integer
// that carries an integer value and an integer that carries a time value.
// The 'time' variables are simply 64-bit integers,
// they are not scaled back and forth to the underlying precision.
//
//| `timescale 1ns/1ps
//|
//| module m();
//|
//| time t;
//|
//| initial
//| begin
//|    #1.5;
//|    $write("T=%f ns (1.5)\n", $realtime());
//|    t = 1.5;
//|    #t;
//|    $write("T=%f ns (3.0)\n", $realtime());
//|    #10ps;
//|    $write("T=%f ns (3.010)\n", $realtime());
//|    t = 10ps;
//|    #t;
//|    $write("T=%f ns (3.020)\n", $realtime());
//| end
//| endmodule
//
// yields
//
//| T=1.500000 ns (1.5)
//| T=3.500000 ns (3.0)
//| T=3.510000 ns (3.010)
//| T=3.510000 ns (3.020)
//
// Within SystemVerilog, we have to worry about
// - different time scale
// - different time precision
//
// Because each endpoint in a socket
// could be coded in different packages
// and thus be executing under different timescale directives,
// a simple integer cannot be used to exchange time information
// across a socket.
//
// For example
//
//| `timescale 1ns/1ps
//|
//| package a_pkg;
//|
//| class a;
//|    function void f(inout time t);
//|       t += 10ns;
//|    endfunction
//| endclass
//|
//| endpackage
//|
//|
//| `timescale 1ps/1ps
//|
//| program p;
//|
//| import a_pkg::*;
//|
//| time t;
//|
//| initial
//| begin
//|    a A = new;
//|    A.f(t);
//|    #t;
//|    $write("T=%0d ps (10,000)\n", $realtime());
//| end
//| endprogram
//
// yeilds
//
//| T=10 ps (10,000)
//
// Scaling is needed everytime you make a procedural call
// to code that may interpret a time value in a different timescale.
//
// Using the uvm_tlm_time type
//
//| `timescale 1ns/1ps
//|
//|    package a_pkg;
//|
//| import uvm_pkg::*;
//|
//| class a;
//|    function void f(uvm_tlm_time t);
//|       t.incr(10ns, 1ns);
//|    endfunction
//| endclass
//|
//| endpackage
//|
//|
//| `timescale 1ps/1ps
//|
//| program p;
//|
//| import uvm_pkg::*;
//| import a_pkg::*;
//|
//| uvm_tlm_time t = new;
//|
//| initial
//|    begin
//|       a A = new;
//|       A.f(t);
//|       #(t.get_realtime(1ns));
//|       $write("T=%0d ps (10,000)\n", $realtime());
//| end
//| endprogram
//
// yields
//
//| T=10000 ps (10,000)
//
// A similar procedure is required when crossing any simulator
// or language boundary,
// such as interfacing between SystemVerilog and SystemC.
