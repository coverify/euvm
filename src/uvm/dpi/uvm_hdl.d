//----------------------------------------------------------------------
// Copyright 2016      Coverify Systems Technology
// Copyright 2009-2011 Mentor Graphics Corporation
// Copyright 2010-2011 Synopsys, Inc.
// Copyright 2007-2018 Cadence Design Systems, Inc.
// Copyright 2013 NVIDIA Corporation
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

module uvm.dpi.uvm_hdl;
import uvm.base.uvm_globals;
import uvm.base.uvm_object_globals;

import esdl.intf.vpi;

import std.string: format;


/* 
 * UVM HDL access C code.
 *
 */

/*
 * This C code checks to see if there is PLI handle
 * with a value set to define the maximum bit width.
 *
 * If no such variable is found, then the default 
 * width of 1024 is used.
 *
 * This function should only get called once or twice,
 * its return value is cached in the caller.
 *
 */

// @uvm-ieee 1800.2-2017 auto 19.6.1
enum uint UVM_HDL_MAX_WIDTH = 1024;

static int uvm_hdl_max_width()
{
  vpiHandle ms = vpiGetHandleByName("uvm_pkg::UVM_HDL_MAX_WIDTH", null);
  if(ms is null) {
    return UVM_HDL_MAX_WIDTH;  /* If nothing else is defined, 
				  this is the DEFAULT */
  }
  int value;
  vpiGetValue(ms, value);
  return value;
}


/*
 * Given a path, look the path name up using the PLI,
 * and set it to 'value'.
 */
bool uvm_hdl_set_vlog(T)(string path, T value, vpiFlagsTypeT flag=vpiNoDelay) {
  static int maxsize = -1;
  // s_vpi_value value_s = { vpiIntVal, { 0 } };
  // s_vpi_time  time_s = { vpiSimTime, 0, 0, 0.0 };

  //vpi_printf("uvm_hdl_set_vlog(%s,%0x)\n",path,value[0].aval);

  vpiHandle r = vpiGetHandleByName(path, null);

  if (r is null) {
    uvm_error("UVM/DPI/HDL_SET",
	      format("set: unable to locate hdl path (%s)\n Either the" ~
		     " name is incorrect, or you may not have PLI/ACC " ~
		     "visibility to that name", path));
    return false;
  }
  else {
    if (maxsize == -1) {
      maxsize = uvm_hdl_max_width();
    }

    if (flag == vpiReleaseFlag) {
      //size = vpi_get(vpiSize, r);
      //value_p = (p_vpi_vecval)(malloc(((size-1)/32+1)*8*sizeof(s_vpi_vecval)));
      //value = &value_p;
    }
    vpiPutValue(r, value, flag);
  }
  return true;
}


/*
 * Given a path, look the path name up using the PLI
 * and return its 'value'.
 */
bool uvm_hdl_get_vlog(T)(string path, ref T value) {
  static int maxsize = -1;
  // int i, size, chunks;
  // s_vpi_value value_s;

  vpiHandle r = vpiGetHandleByName(path, null);

  if (r is null) {
    uvm_error("UVM/DPI/HDL_GET",
	      format("get: unable to locate hdl path (%s)\n Either the" ~
		     " name is incorrect, or you may not have PLI/ACC " ~
		     "visibility to that name", path));
    // Exiting is too harsh. Just return instead.
    // tf_dofinish();
    return false;
  }
  else {
    if (maxsize == -1) {
      maxsize = uvm_hdl_max_width();
    }

    auto size = vpi_get(vpiSize, r);
    if (size > maxsize) {
      uvm_error("UVM/DPI/HDL_SET",
		format("uvm_reg : hdl path '%s' is %0d bits, but the" ~
		       " maximum size is %0d.  You can increase the " ~
		       "maximum via a compile-time flag: " ~
		       "+define+UVM_HDL_MAX_WIDTH=<value>",
		       path, size, maxsize));
      return false;
    }
    // chunks = (size-1)/32 + 1;

    // value_s.format = vpiVectorVal;
    // vpi_get_value(r, &value_s);
    // /*dpi and vpi are reversed*/
    // for(i=0;i<chunks; ++i)
    // {
    //   value[i].aval = value_s.value.vector[i].aval;
    //   value[i].bval = value_s.value.vector[i].bval;
    // }
    vpiGetValue(r, value);
  }
  //vpi_printf("uvm_hdl_get_vlog(%s,%0x)\n",path,value[0].aval);
  return true;
}


/*
 * Given a path, look the path name up using the PLI,
 * but don't set or get. Just check.
 *
 * Return 0 if NOT found.
 * Return 1 if found.
 */
bool uvm_hdl_check_path(string path)
{
  vpiHandle r = vpiGetHandleByName(path, null);

  if(r is null) {
    return false;
  }
  else {
    return true;
  }
}

/*
 * convert binary to integer
 */
// long int uvm_hdl_btoi(char *binVal) {
//   long int remainder, dec=0, j = 0;
//   unsigned long long int bin;
//   int i;
//   char tmp[2];
//   tmp[1] = '\0';

//   for(i= strlen(binVal) -1 ; i >= 0 ; i--) {
//     tmp[0] = binVal[i];
//     bin = atoi(tmp);
//     dec = dec+(bin*(pow(2,j)));
//     j++;
//   }
//   return(dec);
// }


// /*
//  *decimal to hex conversion
//  */
// char *uvm_hdl_dtob(long int decimalNumber) {
//    int remainder, quotient;
//   int  i=0,j, length;
//   int binN[65];
//   static char binaryNumber[65];
//   char *str = (char*) malloc(sizeof(char));

//   quotient = decimalNumber;

//   do {
//     binN[i++] = quotient%2;
//     quotient = quotient/2;
//   } while (quotient!=0);
//   length = i;

//   for (i=length-1, j = 0; i>=0; i--) {
//     binaryNumber[j++] = binN[i]?'1':'0';
//   }
//   binaryNumber[j] = '\0';
//   return(binaryNumber);
// }



/*
 * Given a path, look the path name up using the PLI
 * or the VHPI, and return its 'value'.
 */
bool uvm_hdl_read(T)(string path, ref T value)
{
  return uvm_hdl_get_vlog(path, value);
}


/*
 * Given a path, look the path name up using the PLI
 * or the VHPI, and set it to 'value'.
 */
bool uvm_hdl_deposit(T)(string path, T value)
{
  return uvm_hdl_set_vlog(path, value, vpiNoDelay);
}


/*
 * Given a path, look the path name up using the PLI
 * or the VHPI, and set it to 'value'.
 */
bool uvm_hdl_force(T)(string path, T value)
{
  return uvm_hdl_set_vlog(path, value, vpiForceFlag);
}


/*
 * Given a path, look the path name up using the PLI
 * or the VHPI, and release it.
 */
int uvm_hdl_release_and_read(T)(string path, ref T value)
{
    return uvm_hdl_set_vlog(path, value, vpiReleaseFlag);
}

/*
 * Given a path, look the path name up using the PLI
 * or the VHPI, and release it.
 */
bool uvm_hdl_release(string path) {
  s_vpi_value value;
  p_vpi_value valuep = &value;
  vpiHandle r = vpiGetHandleByName(path, null);

  if(r is null) {
    uvm_error("UVM/DPI/HDL_SET",
	      format("set: unable to locate hdl path (%s)\n Either the" ~
		     " name is incorrect, or you may not have PLI/ACC " ~
		     "visibility to that name", path));
    return false;
  }
  else {
    vpi_put_value(r, valuep, null, vpiReleaseFlag);
    return true;
  }
}

