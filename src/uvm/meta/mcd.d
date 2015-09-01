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
  public this(File fd, MCD mcd)
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

public void vdisplay(T...)(T args) {
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
  static mcdPair[] files;
  static this()
  {
    files ~= mcdPair(stdout, STDOUT);
    files ~= mcdPair(stderr, STDERR);
  }

  static MCD open(string name)
  {
    import std.exception;
    File fd = void;
    bool opened = true;
    MCD mcd = (cast (MCD) 1) << files.length;

    enforce (files.length < 8*MCD.sizeof, "Can not open any more MCD files");
    try
      {
	fd = File(name, "w");
      }
    catch (Exception e)
      {
	stderr.writefln("Error: %s", e.msg);
	opened = false;
      }
    if(opened)
      {
	files ~= mcdPair(fd, mcd);
	return mcd;
      }
    else
      {
	return 0L;
      }
  }

  static void close(MCD mcd)
  {
    foreach(file; files)
      {
	if(file._mcd & mcd)
	  {
	    if(file._mcd == 1 || file._mcd == 2)
	      {
		stderr.writeln("Error: can not close stdout or stderr!");
	      }
	    else
	      {
		if(file._fd.isOpen()) file._fd.close();
	      }
	  }
      }
  }

  static void flush(MCD mcd)
  {
    foreach(file; files)
      {
	if((file._mcd & mcd) && file._fd.isOpen) file._fd.flush();
      }
  }

  static void write(S...)(MCD mcd, S args)
  {
    foreach(file; files)
      {
	if((file._mcd & mcd) && file._fd.isOpen) file._fd.write(args);
      }
  }

  static void writeln(S...)(MCD mcd, S args)
  {
    foreach(file; files)
      {
	if((file._mcd & mcd) && file._fd.isOpen) file._fd.writeln(args);
      }
  }

  static void writef(S...)(MCD mcd, S args)
  {
    foreach(file; files)
      {
	if((file._mcd & mcd) && file._fd.isOpen) file._fd.writef(args);
      }
  }

  static void writefln(S...)(MCD mcd, S args)
  {
    foreach(file; files)
      {
	if((file._mcd & mcd) && file._fd.isOpen) file._fd.writefln(args);
      }
  }

}
