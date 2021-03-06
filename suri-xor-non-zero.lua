--[[
#*************************************************************
#  Copyright (c) 2003-2013, Emerging Threats
#  All rights reserved.
#  
#  Redistribution and use in source and binary forms, with or without modification, are permitted provided that the 
#  following conditions are met:
#  
#  * Redistributions of source code must retain the above copyright notice, this list of conditions and the following 
#    disclaimer.
#  * Redistributions in binary form must reproduce the above copyright notice, this list of conditions and the 
#    following disclaimer in the documentation and/or other materials provided with the distribution.
#  * Neither the name of the nor the names of its contributors may be used to endorse or promote products derived 
#    from this software without specific prior written permission.
#  
#  THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS AS IS AND ANY EXPRESS OR IMPLIED WARRANTIES, 
#  INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE 
#  DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, 
#  SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR 
#  SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, 
#  WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE 
#  USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE. 
#
#*************************************************************

This lua script can be run standalone and verbosely on a binary file with
echo "run()" | lua -i <script name> <binary file>

Chris Wakelin
--]]

function init (args)
    local needs = {}
    needs["http.response_body"] = tostring(true)
    return needs
end

function xor0(byte, key)
   local bit = require("bit")
   if byte == key or byte == 0 then
       return byte
   end
   return bit.bxor(byte,key)
end

-- return match via table
function common(a,verbose)
    local result = {}
    local bit = require("bit")

    if #a < 1024 then 
        return 0
    end

-- Check for XOR with 0 and XOR-key bytes left alone
-- PE offset is (nearly?) always divisible by 8, so key lengths 1,2,4 will always be detected
-- Can match other key lengths in some cases where the remainder on dividing into 0x3c is 0,1,2 or 4
-- and on dividing into the PE offset is 0 or 1 (or 4 when the key length is 5)
    key = {xor0(a:byte(1), string.byte('M')), xor0(a:byte(2), string.byte('Z')), xor0(a:byte(3), 0x90), 0, xor0(a:byte(5), 0x03), 0, 0, 0}

    key_lengths = {1,3,5,6,7,8}
    for n,l in pairs(key_lengths) do
      
        koffset = 0x3c % l
        pe = xor0(a:byte(0x3c+1),key[1+koffset]) + (256*xor0(a:byte(0x3c+2),key[((1+koffset) % l) + 1]))
        if verbose==1 then print("Trying PE header at " .. pe) end

        koffset = pe % l
        if ((pe < 4096) and (pe < #a-4)) then
            if xor0(a:byte(pe+1),key[1+koffset]) == string.byte('P') and
               xor0(a:byte(pe+2),key[((1+koffset) % l) + 1]) == string.byte('E') and
               a:byte(pe+3) == 0 and
               a:byte(pe+4) == 0 then
                if verbose==1 then print("Found " .. l .. "-byte XOR-but-not-zero key " .. key[1] .. "," .. key[2] .. " - PE block at " .. pe) end
                return 1
            end
        end
    end

    return 0
end

-- return match via table
function match(args)
    local t = tostring(args["http.response_body"])
    return common(t,0)
end

function run()
  local f = io.open(arg[1])
  local t = f:read("*all")
  f:close()
  common(t,1)
end
