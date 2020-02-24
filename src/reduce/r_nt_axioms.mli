(*
 * reduce/nt_axioms.mli --- axioms for notypes encoding
 *
 *
 * Copyright (C) 2008-2010  INRIA and Microsoft Corporation
 *)

open Expr.T
open Type.T

(* {3 Sorts} *)

val usort_nm : string
val stringsort_nm : string

(* {3 Special} *)

val uany_nm : string
val stringany_nm : string

val uany_decl : hyp
val stringany_decl : hyp

(* {3 Set Theory} *)

val mem_nm : string
val subseteq_nm : string
val empty_nm : string
val enum_nm : int -> string
val union_nm : string
val power_nm : string
val cup_nm : string
val cap_nm : string
val setminus_nm : string
val setst_nm : string -> ty_kind -> string
(*val setof_nm : string -> ty_kind -> string*)

val mem_decl : hyp
val subseteq_decl : hyp
val empty_decl : hyp
val enum_decl : int -> hyp
val union_decl : hyp
val power_decl : hyp
val cup_decl : hyp
val cap_decl : hyp
val setminus_decl : hyp
val setst_decl : string -> ty_kind -> hyp
(*val setof_decl : string -> ty_kind -> hyp*)

(* {3 Base Sets} *)

val boolean_nm : string
val booltou_nm : string
val string_nm : string
val stringtou_nm : string
val stringlit_nm : string -> string

val boolean_decl : hyp
val booltou_decl : hyp
val string_decl : hyp
val stringtou_decl : hyp
val stringlit_decl : string -> hyp

(* {3 Functions} *)

val arrow_nm : string
val fcn_nm : string -> ty_kind -> string
val domain_nm : string
val fcnapp_nm : string
val fcnexcept_nm : string

(* {3 Arithmetic} *)

val zset_nm : string
val nset_nm : string
val rset_nm : string
val plus_nm : string
val uminus_nm : string
val minus_nm : string
val times_nm : string
val ratio_nm : string
val quotient_nm : string
val remainder_nm : string
val exp_nm : string
val infinity_nm : string
val lteq_nm : string
val lt_nm : string
val gteq_nm : string
val gt_nm : string
val range_nm : string

(* {3 Sequences} *)
