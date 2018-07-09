module MPFR.Round.Spec

open FStar.Mul
open FStar.UInt
open MPFR.Dyadic
open MPFR.Lib.Spec
open MPFR.Maths

#set-options "--z3refresh --z3rlimit 50 --max_fuel 1 --initial_fuel 0 --max_ifuel 1 --initial_ifuel 0"

(* ulp definition *)
let ulp_p (a:normal_fp) (p:pos) = unit_fp (a.exp - p)

let ulp (a:normal_fp) = ulp_p a a.prec
let ufp (a:normal_fp) = ulp_p a 1

val add_one_ulp: a:normal_fp ->
    Tot (r:normal_fp{r.prec = a.prec /\ eval_abs r =. eval_abs a +. ulp a})
    
let add_one_ulp a =
    if a.limb + pow2 (a.len - a.prec) < pow2 a.len then begin
        lemma_pow2_mod (a.len - a.prec) (a.len - a.prec);
        lemma_mod_distr_zero a.limb (pow2 (a.len - a.prec)) (pow2 (a.len - a.prec));
	{a with limb = a.limb + pow2 (a.len - a.prec)}
    end else begin
        lemma_pow2_multiple_le a.limb a.len (a.len - a.prec);
	//! assert(a.limb + pow2 (a.len - a.prec) <= pow2 a.len);
	lemma_pow2_mul (a.len - 1) 1;
	//! assert(pow2 a.len * pow2 0 = pow2 (a.len - 1) * pow2 1);
	lemma_pow2_mod (a.len - 1) (a.len - a.prec);
	//! assert(pow2 (a.len - 1) % pow2 (a.len - a.prec) = 0);
	{a with limb = pow2 (a.len - 1); exp = a.exp + 1}
    end

(* Increase precision *)
val incr_prec: a:normal_fp -> p:pos{p >= a.prec} ->
    Tot (r:normal_fp{r.prec = p /\ eval r =. eval a})
    
let incr_prec a p =
    if p > a.len then begin
        lemma_pow2_mul_range a.limb (p - a.len) a.len;
        {a with prec = p; limb = a.limb * pow2 (p - a.len); len = p}
    end else begin
        lemma_pow2_mod_mod a.limb (a.len - a.prec) (a.len - p);
        {a with prec = p}
    end

(* Decrease precision, actually RNDZ *)
val decr_prec: a:normal_fp -> p:pos{p < a.prec} ->
    Tot (r:normal_fp{r.prec = p /\
        eval_abs r <=. eval_abs a /\ eval_abs a <. eval_abs r +. ulp r})
	
let decr_prec a p =
    lemma_pow2_div_range a.limb (a.len - p) a.len;
    lemma_pow2_mul_range (a.limb / pow2 (a.len - p)) (a.len - p) p;
    lemma_pow2_le (a.len - p) (a.len - 1);
    lemma_multiple_mod (a.limb / pow2 (a.len - p)) (pow2 (a.len - p));
    {a with prec = p; limb = (a.limb / pow2 (a.len - p)) * pow2 (a.len - p)}

(* Split mantissa into high part and low part in order to round it
 * No need to normalize low_mant as long as it has the same value *)
val high_mant: a:normal_fp -> p:pos{p < a.prec} ->
    Tot (hm:normal_fp{hm.prec = p /\
        eval_abs hm <=. eval_abs a /\ eval_abs a <. eval_abs hm +. ulp hm})
	
let high_mant a p = decr_prec a p

val low_mant: a:normal_fp -> p:pos{p < a.prec} -> Tot (lm:valid_fp{
    eval_abs lm <. ulp (high_mant a p) /\ eval lm +. eval (high_mant a p) =. eval a})
    
let low_mant a p = 
    lemma_euclidean a.limb (pow2 (a.len - p));
    if a.limb % pow2 (a.len - p) = 0 then begin
        {a with limb = 0; flag = MPFR_ZERO}
    end else begin
        lemma_pow2_mod_mod a.limb (a.len - p) (a.len - a.prec);
        {a with limb = a.limb % pow2 (a.len - p)}
    end
    

////////////////////////////////////////////////////////////////////////////////////
//  RNDZ Definition: Round to zero                                                //
//  Given floating point number 'a' and precision 'p', got result r = RNDZ(a, p)  //
//  Splitting 'a' into two floating point numbers a = a_high + a_low              //
//  Rounding 'a' to a_high                                                        //
//  We should always have the following inequality:                               //
//                   abs r  <=  abs a  <  abs r + ulp r                           //
////////////////////////////////////////////////////////////////////////////////////

val rndz_def: a:normal_fp -> p:pos{p < a.prec} ->
    Tot (r:normal_fp{r.prec = p /\
        eval_abs r <=. eval_abs a /\ eval_abs a <. eval_abs r +. ulp r})
	
let rndz_def a p = high_mant a p


//////////////////////////////////////////////////////////////////////////////////////
//  RNDN Definition: Rounding to the nearest                                        //
//  Given floating point number 'a' and precision 'p', got result r = RNDN(a, p)    //
//  Splitting 'a' into two floating point numbers a = a_high + a_low                //
//  Rounding 'a' to a_high or a_high + ulp depending on a_low                       //
//  We should always have the following inequality:                                 //
//  (r.mant - 0.5) * 2 ^ r.exp <= a.mant * 2 ^ a.exp <= (r.mant + 0.5) * 2 ^ r.exp  //
//  But it slightly varies according to "round to even rule"                        //
//////////////////////////////////////////////////////////////////////////////////////

(* RNDN definition *)
let is_even (a:normal_fp) = (nth #a.len a.limb (a.prec - 1) = false)

let rndn_def (a:normal_fp) (p:pos{p < a.prec}): Tot (r:normal_fp{r.prec = p}) =
    let high, low = high_mant a p, low_mant a p in
    if ((eval_abs low <. ulp_p high (p + 1)) ||
        (eval_abs low =. ulp_p high (p + 1) && is_even high))
    then rndz_def a p
    else add_one_ulp (rndz_def a p)

(* Definitions of round bit and sticky bit which are widely used to implement RNDN *)
let rb_def (a:normal_fp) (p:pos{p < a.prec}): Tot bool = nth #a.len a.limb p
let sb_def (a:normal_fp) (p:pos{p < a.prec}): Tot bool = (a.limb % pow2 (a.len - p - 1) <> 0)

val rb_value_lemma: a:normal_fp -> p:pos{p < a.prec} ->
    Lemma (a.limb % pow2 (a.len - p) = a.limb % pow2 (a.len - p - 1) + (if rb_def a p then pow2 (a.len - p - 1) else 0))

let rb_value_lemma a p =
    assert(nth #a.len a.limb p = nth (shift_right #a.len a.limb (a.len - p - 1)) (a.len - 1));
    lemma_euclidean (a.limb % pow2 (a.len - p)) (pow2 (a.len - p - 1));
    lemma_pow2_mod_div a.limb (a.len - p) (a.len - p - 1);
    lemma_pow2_mod_mod a.limb (a.len - p) (a.len - p - 1)

val rb_sb_lemma: a:normal_fp -> p:pos{p < a.prec} -> Lemma (
    let lm_fp = eval_abs (low_mant a p) in
    let hulp  = ulp_p (high_mant a p) (p + 1) in
    ((rb_def a p = false /\ sb_def a p = false) <==> (lm_fp =. zero_fp)) /\
    ((rb_def a p = false /\ sb_def a p = true ) <==> (lm_fp >. zero_fp /\ lm_fp <. hulp)) /\
    ((rb_def a p = true  /\ sb_def a p = false) <==> (lm_fp =. hulp)) /\
    ((rb_def a p = true  /\ sb_def a p = true ) <==> (lm_fp >. hulp)))
    
let rb_sb_lemma a p =
    rb_value_lemma a p;
    if sb_def a p = false then ()
    else if rb_def a p then begin
        lemma_mul_lt_right (pow2 (p + 1)) (pow2 (a.len - p - 1)) (a.limb % pow2 (a.len - p));
	lemma_pow2_mul (a.len - p - 1) (p + 1)
    end else begin
        assert(a.limb % pow2 (a.len - p) > 0);
        lemma_mul_lt_right (pow2 (p + 1)) (a.limb % pow2 (a.len - p)) (pow2 (a.len - p - 1));
	lemma_pow2_mul (a.len - p - 1) (p + 1)
    end

val is_even_lemma: a:normal_fp -> p:pos{p < a.prec} -> Lemma
    (is_even (high_mant a p) = (logand #a.len (high_mant a p).limb (pow2 (a.len - p)) = 0))
    
let is_even_lemma a p = 
    lemma_multiple_div (a.limb / pow2 (a.len - p)) (pow2 (a.len - p));
    assert(nth #a.len (shift_right #a.len a.limb (a.len - p)) (a.len - 1) =
           nth #a.len (shift_right #a.len (high_mant a p).limb (a.len - p)) (a.len - 1));
    if nth #a.len a.limb (p - 1) then 
        nth_lemma (logand #a.len (high_mant a p).limb (pow2_n #a.len (a.len - p))) (pow2_n #a.len (a.len - p))
    else 
        nth_lemma (logand #a.len (high_mant a p).limb (pow2_n #a.len (a.len - p))) (zero a.len)
	
val rndn_spec: a:normal_fp -> p:pos{p < a.prec} ->
    Tot (r:normal_fp{r = rndn_def a p})
    
let rndn_spec a p =
    let high, low = high_mant a p, low_mant a p in
    rb_sb_lemma a p;
    is_even_lemma a p;
    if rb_def a p = false || 
      (sb_def a p = false && logand #a.len (high_mant a p).limb (pow2 (a.len - p)) = 0)
    then rndz_def a p
    else add_one_ulp (rndz_def a p)