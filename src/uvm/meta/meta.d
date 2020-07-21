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
module uvm.meta.meta;
import std.stdio: stderr;
import std.conv: to;

import std.traits: fullyQualifiedName;

import std.traits: fullyQualifiedName;

// alias qualifiedTypeName = fullyQualifiedName;

template qualifiedTypeName(T) {
  // pragma(msg, typeid(T).stringof);
  // pragma(msg, T.stringof);
  // pragma(msg, fullyQualifiedName!T);
  // pragma(msg, typeid(T).stringof[7..$-1]);
  // typeid(T).stringof returns string of the form "&typeid(qualifiedTypeName)"
  // enum string qualifiedTypeName = typeid(T).stringof[7..$-1];
  enum string qualifiedTypeName = fullyQualifiedName!T;
}

version (X86_64) {
  extern (C) void* thread_stackBottom();
  extern (C) char** backtrace_symbols(void**, int size);

  void printStackTrace() {
    void*[10] callstack;
    void** stackTop;
    void** stackBottom = cast(void**) thread_stackBottom();

    asm {
      mov [stackTop], RBP;
    }

    auto curr = stackTop;

    size_t i;
    for (i = 0; stackTop <= curr &&
	   curr < stackBottom && i < 10;)
      {
	callstack[i++] = *(curr+1);
	curr = cast(void**) *curr;
      }

    auto ret = backtrace_symbols(callstack.ptr, cast(int) i);
    for (; i > 0; i--) {
      stderr.writeln((*ret).to!string());
      ret++;
    }
  }
}
