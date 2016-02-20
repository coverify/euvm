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
module uvm.meta.mcd;
alias size_t MCD;
public import std.stdio;

enum MCD STDOUT = 1;
enum MCD STDERR = 2;

private struct mcdPair
{
  import std.stdio;
  File _fd;
  MCD  _mcd;
  this(File fd, MCD mcd)
  {
    _fd = fd;
    _mcd = mcd;
  }
}

// Extra v prefix is to avoid clash with std.c.stdio which gets
// publically imported along with std.stdio
alias MCDFile.open     vfopen;
alias MCDFile.close    vfclose;
alias MCDFile.flush    vflush;
// alias MCDFile.write    vwrite;
alias MCDFile.writef   vwritef;
alias MCDFile.writeln  vwriteln;
alias MCDFile.writefln vwritefln;
alias MCDFile.writefln vfdisplay;
// alias writefln         vdisplay;
alias writef           vwrite;

void vdisplay(T...)(T args) {
  static if(args.length == 0) {
    writeln();
  }
  else {
    writefln(args);
  }
}

class MCDFile
{
  import std.stdio;
  __gshared File[MCD] files;
  static this()
  {
    synchronized(typeid(MCDFile)) {
      files[STDOUT] = stdout; //  ~= mcdPair(stdout, STDOUT);
      files[STDERR] = stderr; // files ~= mcdPair(stderr, STDERR);
    }
  }

  static MCD open(string name, string mode="w")
  {
    synchronized(typeid(MCDFile)) {
      import std.exception;
      File fd = void;
      bool opened = true;
      MCD mcd = (cast (MCD) 1) << files.length;

      enforce (files.length < 8*MCD.sizeof, "Can not open any more MCD files");
      try
	{
	  fd = File(name, mode);
	}
      catch (Exception e)
	{
	  stderr.writefln("Error: %s", e.msg);
	  opened = false;
	}
      if(opened)
	{
	  files[mcd] = fd; //  ~= mcdPair(fd, mcd);
	  return mcd;
	}
      else
	{
	  return 0L;
	}
    }
  }

  static void close(MCD mcd)
  {
    synchronized(typeid(MCDFile)) {
      foreach(_mcd, _fd; files)
	{
	  if(_mcd & mcd)
	    {
	      if(_mcd == 1 || _mcd == 2)
		{
		  stderr.writeln("Error: can not close stdout or stderr!");
		}
	      else
		{
		  if(_fd.isOpen()) _fd.close();
		}
	    }
	}
    }
  }

  static void flush(MCD mcd)
  {
    synchronized(typeid(MCDFile)) {
      foreach(_mcd, _fd; files)
	{
	  if((_mcd & mcd) && _fd.isOpen) _fd.flush();
	}
    }
  }

  static void write(S...)(MCD mcd, S args)
  {
    synchronized(typeid(MCDFile)) {
      foreach(_mcd, _fd; files)
	{
	  if((_mcd & mcd) && _fd.isOpen) _fd.write(args);
	}
    }
  }
  
  static void writeln(S...)(MCD mcd, S args)
  {
    synchronized(typeid(MCDFile)) {
      foreach(_mcd, _fd; files)
	{
	  if((_mcd & mcd) && _fd.isOpen) _fd.writeln(args);
	}
    }
  }

  static void writef(S...)(MCD mcd, S args)
  {
    synchronized(typeid(MCDFile)) {
      foreach(_mcd, _fd; files)
	{
	  if((_mcd & mcd) && _fd.isOpen) _fd.writef(args);
	}
    }
  }

  static void writefln(S...)(MCD mcd, S args)
  {
    synchronized(typeid(MCDFile)) {
      foreach(_mcd, _fd; files)
	{
	  if((_mcd & mcd) && _fd.isOpen) _fd.writefln(args);
	}
    }
  }

}
