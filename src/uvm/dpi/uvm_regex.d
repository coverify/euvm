//----------------------------------------------------------------------
// Copyright 2012-2018 Coverify Systems Technology
// Copyright 2010-2018 Cadence Design Systems, Inc.
// Copyright 2010-2012 Mentor Graphics Corporation
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

module uvm.dpi.uvm_regex;

enum char uvm_re_bracket_char = '/';

enum string empty_regex = "/^$/";

bool uvm_re_match(in string re, in string str) {
  import std.regex;
  Regex!char rx;
  if (re.length > 1 && re[0] is uvm_re_bracket_char &&
      re[$-1] is uvm_re_bracket_char) {
    rx = regex(re[1..$-1]);
  }
  else {
    rx = regex(re);
  }
  if(match(str, rx)) {
    return true;
  }
  else {
    return false;
  }
}

//--------------------------------------------------------------------
// uvm_glob_to_re
//
// Convert a glob expression to a normal regular expression.
//--------------------------------------------------------------------

string uvm_glob_to_re(string glob) {
  string retval;
  // safety check.  Glob should never be null since this is called
  // from DPI.  But we'll check anyway.
  if(glob is null) return null;

  // SV puts this condition since there we use DPI and we have a hard
  // limit to the string size

  // if (len > 2040) {
  //   vpi_printf((PLI_BYTE8*)  "UVM_ERROR: uvm_glob_to_re : glob expression greater than max 2040: |%s|\n",glob);
  //   return glob;
  // }

  // If either of the following cases appear then return an empty string
  //
  //  1.  The glob string is empty (it has zero characters)
  //  2.  The glob string has a single character that is the
  //      uvm_re_bracket_char  (i.e. "/")
  if(glob.length == 0 || (glob.length == 1 && glob[0] == uvm_re_bracket_char)) {
    return empty_regex;  // return an empty string
  }

  // If bracketed with the /glob/, then it's already a regex
  if(glob[0] is uvm_re_bracket_char && glob[$-1] is uvm_re_bracket_char) {
    // take out the uvm_re_bracket_char and return
    return glob;
  }
  else {
    // Convert the glob to a true regular expression (Posix syntax)

    retval ~= uvm_re_bracket_char;

    // ^ goes at the beginning...
    if (glob[0] !is '^') retval ~= '^';

    foreach(p; glob) {
      // Replace the glob metacharacters with corresponding regular
      // expression metacharacters.
      switch(p) {
      case '?':
	retval ~= '.';      break;
      case '*', '+':
	retval ~= "." ~ p;  break;
      case '.', '[', ']', '(', ')':
	retval ~= "\\" ~ p; break;
      default:
	retval ~= p;        break;
      }
    }
  }

  // Let's check to see if the regular expression is bounded by ^ at
  // the beginning and $ at the end.  If not, add those characters in
  // the appropriate position.

  if (retval[$-1] !is '$') {
    retval ~= '$';
  }

  retval ~= uvm_re_bracket_char;

  return retval;
}
