module Hacl.Spec.P256.Definitions

open Lib.IntTypes
open FStar.Math.Lemmas
open FStar.Math.Lib

open FStar.HyperStack
open FStar.HyperStack.All
open Lib.Sequence
open Lib.Buffer

open Hacl.Spec.Curve25519.Field64.Definition

inline_for_extraction noextract
let felem4 = uint64 * uint64 * uint64 * uint64
inline_for_extraction noextract
let felem8 = uint64 * uint64  * uint64  * uint64 * uint64 * uint64 * uint64 * uint64
inline_for_extraction noextract
let felem8_32 = uint32 * uint32 * uint32 * uint32 * uint32 * uint32 * uint32 * uint32
inline_for_extraction noextract
let felem9 = uint64 * uint64  * uint64  * uint64 * uint64 * uint64 * uint64 * uint64 * uint64

noextract
let point_nat = nat * nat * nat

noextract
let point_seq = Lib.Sequence.lseq uint64 12 

noextract
let felem_seq = lseq uint64 4

inline_for_extraction
let felem = lbuffer uint64 (size 4)
inline_for_extraction
let longelem = lbuffer uint64 (size 8)

noextract
let felem_seq_as_nat (a: felem_seq) : Tot nat  = 
  let open FStar.Mul in 
  let a0 = Lib.Sequence.index a 0 in 
  let a1 =  Lib.Sequence.index a 1 in 
  let a2 =  Lib.Sequence.index  a 2 in 
  let a3 =  Lib.Sequence.index a 3 in 
  uint_v a0 + uint_v a1 * pow2 64 + uint_v a2 * pow2 64 * pow2 64 + uint_v a3 * pow2 64 * pow2 64 * pow2 64


open FStar.Mul

noextract
let prime:pos =
  assert_norm (pow2 256 - pow2 224 + pow2 192 + pow2 96 -1 > 0);
  pow2 256 - pow2 224 + pow2 192 + pow2 96 -1

noextract
let felem_seq_prime = a: felem_seq {felem_seq_as_nat a < prime}
noextract
let point_prime =  p: point_seq{let x = Lib.Sequence.sub p 0 4 in let y = Lib.Sequence.sub p 4 4 in let z = Lib.Sequence.sub p 8 4 in 
  felem_seq_as_nat x < prime /\ felem_seq_as_nat y < prime /\ felem_seq_as_nat z < prime} 


inline_for_extraction
type point = lbuffer uint64 (size 12)


(* Montgomery multiplication parameters *)
inline_for_extraction
let s = 64ul
inline_for_extraction
let long = lbuffer uint64 (size 9)

(*noextract
val as_nat4: f:felem4 -> Tot nat
let as_nat4 f =
  let (s0, s1, s2, s3) = f in
  v s0 + v s1 * pow2 64 + v s2 * pow2 64 * pow2 64 +
  v s3 * pow2 64 * pow2 64 * pow2 64

*)

val border_felem4: f: felem4 -> Lemma (as_nat4 f < pow2 256)
let border_felem4 f = admit()

(*noextract
val wide_as_nat4: f:felem8 -> Tot nat
let wide_as_nat4 f =
  let (s0, s1, s2, s3, s4, s5, s6, s7) = f in
  v s0 + v s1 * pow2 64 + v s2 * pow2 64 * pow2 64 +
  v s3 * pow2 64 * pow2 64 * pow2 64 +
  v s4 * pow2 64 * pow2 64 * pow2 64 * pow2 64 +
  v s5 * pow2 64 * pow2 64 * pow2 64 * pow2 64 * pow2 64 +
  v s6 * pow2 64 * pow2 64 * pow2 64 * pow2 64 * pow2 64 * pow2 64 +
  v s7 * pow2 64 * pow2 64 * pow2 64 * pow2 64 * pow2 64 * pow2 64 * pow2 64
*)
noextract
val as_nat9: f: felem9 -> Tot nat 
let as_nat9 f = 
  let (s0, s1, s2, s3, s4, s5, s6, s7, s8) = f in
  v s0 + v s1 * pow2 64 + v s2 * pow2 64 * pow2 64 +
  v s3 * pow2 64 * pow2 64 * pow2 64 +
  v s4 * pow2 64 * pow2 64 * pow2 64 * pow2 64 +
  v s5 * pow2 64 * pow2 64 * pow2 64 * pow2 64 * pow2 64 +
  v s6 * pow2 64 * pow2 64 * pow2 64 * pow2 64 * pow2 64 * pow2 64 +
  v s7 * pow2 64 * pow2 64 * pow2 64 * pow2 64 * pow2 64 * pow2 64 * pow2 64 +
  v s8 * pow2 64 * pow2 64 * pow2 64 * pow2 64 * pow2 64 * pow2 64 * pow2 64 * pow2 64 


noextract
let long_as_nat (h:mem) (e:long) : GTot nat =
  let open Lib.Sequence in 
  let s = as_seq h e in
  let s0 = s.[0] in
  let s1 = s.[1] in
  let s2 = s.[2] in
  let s3 = s.[3] in
  let s4 = s.[4] in
  let s5 = s.[5] in
  let s6 = s.[6] in
  let s7 = s.[7] in
  let s8 = s.[8] in 
  as_nat9 (s0, s1, s2, s3, s4, s5, s6, s7, s8)