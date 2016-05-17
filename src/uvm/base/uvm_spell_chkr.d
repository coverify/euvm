//
//------------------------------------------------------------------------------
//   Copyright 2011 Mentor Graphics Corporation
//   Copyright 2011 Cadence Design Systems, Inc.
//   Copyright 2011 Synopsys, Inc.
//   Copyright 2012-2014 Coverify Systems Technology
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

//----------------------------------------------------------------------
// class uvm_spell_chkr
//----------------------------------------------------------------------

module uvm.base.uvm_spell_chkr;

import uvm.base.uvm_globals;	// uvm_info
import std.string: format;
import uvm.base.uvm_object_globals: UVM_NONE;



// A stateless template class. Need no synchronization.
class uvm_spell_chkr(T=int)
{
  private enum uint max = uint.max;

  // typedef T tab_t[string];
  alias tab_t = T[string];

  //--------------------------------------------------------------------
  // check
  //
  // primary interface to the spell checker.  The function takes two
  // arguments, a table of strings and a string to check.  The table is
  // organized as an associative array of type T.  E.g.
  //
  //    T strtab[string]
  //
  // It doesn't matter what T is since we are only concerned with the
  // string keys. However, we need T in order to make argument types
  // match.
  //
  // First, we do the simple thing and see if the string already is in
  // the string table by calling the ~exists()~ method.  If it does exist
  // then there is a match and we're done.  If the string doesn't exist
  // in the table then we invoke the spell checker algorithm to see if
  // our string is a misspelled variation on a string that does exist in
  // the table.
  //
  // The main loop traverses the string table computing the levenshtein
  // distance between each string and the string we are checking.  The
  // strings in the table with the minimum distance are considered
  // possible alternatives.  There may be more than one string in the
  // table with a minimum distance. So all the alternatives are stored
  // in a queue.
  //
  // Note: This is not a particularly efficient algorithm.  It requires
  // computing the levenshtein distance for every string in the string
  // table.  If that list were very large the run time could be long.
  // For the resources application in UVM probably the size of the
  // string table is not excessive and run times will be fast enough.
  // If, on average, that proves to be an invalid assumption then we'll
  // have to find ways to optimize this algorithm.
  //--------------------------------------------------------------------
  //
  // note: strtab should not be modified inside check()

  // SV version declares strtab argument as a ref
  // not required for dlang since assoc arrays are anyways passed by
  // ref in dlang
  static bool check ( /* const ref */ tab_t strtab, in string s) {

    // SV version uses a queue, but a dynamic array would be fine too
    // string min_key[$];
    string[] min_key;
    if(s in strtab)  return true;
    uint min = max;

    foreach(key, val; strtab) {
      int distance = levenshtein_distance(key, s);

      // A distance < 0 means either key, s, or both are empty.  This
      // should never happen here but we check for that condition just
      // in case.
      if(distance < 0) continue;
      if(distance < min) {
	// set a new minimum.  Clean out the queue since previous
	// alternatives are now invalidated.
	min = distance;
	min_key.length = 0;
	min_key ~= key;
	continue;
      }
      if(distance is min) {
	min_key ~= key;
      }
    }


    // if (min is max) then the string table is empty
    if(min == max) {
      uvm_info("UVM/CONFIGDB/SPELLCHK",
	       format("%s not located, no alternatives to suggest", s),
	       UVM_NONE);
    }
    else {
      // dump all the alternatives with the minimum distance
      string q;
	    
      foreach(key; min_key) {
	q ~= key;
	q ~= "|";
      }
      if(q.length) {
	q = q[0..$-1];
      }
	   		
      uvm_info("UVM/CONFIGDB/SPELLCHK",
	       format("%s not located, did you mean %s", s, q), UVM_NONE);
    }
    return 0;
  }


  //--------------------------------------------------------------------
  // levenshtein_distance
  //
  // Compute levenshtein distance between s and t
  // The Levenshtein distance is defined as The smallest number of
  // insertions, deletions, and substitutions required to change one
  // string into another.  There is a tremendous amount of information
  // available on Levenshtein distance on the internet.  Two good
  // sources are wikipedia and nist.gov.  A nice, simple explanation of
  // the algorithm is at
  // http://www.codeproject.com/KB/recipes/Levenshtein.aspx.  Use google
  // to find others.
  //
  // This implementation of the Levenshtein
  // distance computation algorithm is a SystemVerilog adaptation of the
  // C implementatiion located at http://www.merriampark.com/ldc.htm.
  //--------------------------------------------------------------------
  static private int levenshtein_distance(string s, string t) {
    //Step 1
    int n = cast(int) s.length + 1;
    int m = cast(int) t.length + 1;

    //a negative return value means that one or both strings are empty.
    if(n is 1 || m is 1) return -1;

    int[] d = new int[m*n];

    //Step 2
    for(int k = 0; k < n; ++k) {
      d[k] = k;
    }

    for(int k = 0; k < m; ++k) {
      d[k*n] = k;
    }

    //Steps 3 and 4
    for(size_t i = 1; i < n; ++i) {
      for(size_t j = 1; j < m; ++j) {

	//Step 5
	int cost = !(s[i-1] is t[j-1]);

	//Step 6
	import std.algorithm: min;
	d[j*n+i] = min(d[(j-1)*n+i]+1, d[j*n+i-1]+1, d[(j-1)*n+i-1]+cost);
      }
    }

    int distance = d[n*m-1];
    return distance;

  } // endfunction

  //--------------------------------------------------------------------
  // Gets the minimum of three values
  //--------------------------------------------------------------------

  // not required -- vlang uses std.algorithm.min
  // static local function int minimum(int a, int b, int c);

  //   int min = a;

  //   if(b < min)
  //     min = b;
  //   if(c < min)
  //     min = c;

  //   return min;

  // endfunction

} // endclass
