(*
 * encode/axioms.ml --- axioms for TLA+ symbols
 *
 *
 * Copyright (C) 2008-2010  INRIA and Microsoft Corporation
 *)

open Ext
open Property
open Expr.T
open Type.T

module B = Builtin


(* {3 Helpers} *)

let annot h ty = assign h Props.type_prop ty
let targs a tys = assign a Props.targs_prop tys

let app ?tys op es =
  let op = Option.fold targs op tys in
  match es with
  | [] -> Apply (op, []) (* previously just op.core, but loss of properties *)
  | _ -> Apply (op, es)

let appb ?tys b es =
  app ?tys (Internal b %% []) es

let una ?tys b e1    = appb ?tys b [ e1 ]
let ifx ?tys b e1 e2 = appb ?tys b [ e1 ; e2 ]

let quant q xs ?tys ?pats e =
  let xs =
    match tys with
    | None ->
        List.map (fun x -> (x %% [], Constant, No_domain)) xs
    | Some tys ->
        List.map2 (fun x ty -> (annot (x %% []) ty, Constant, No_domain)) xs tys
  in
  let e =
    match pats with
    | None -> e
    | Some pats ->
        assign e pattern_prop pats
  in
  Quant (q, xs, e)

let all xs ?tys ?pats e = quant Forall xs ?tys ?pats e
let exi xs ?tys ?pats e = quant Exists xs ?tys ?pats e

let dupl a n = List.init n (fun _ -> a)

let gen x n = List.init n (fun i -> x ^ string_of_int (i + 1))
(** [gen "x" n] = [ "x1" ; .. ; "xn" ] *)

let ixi ?(shift=0) n = List.init n (fun i -> Ix (shift + n - i) %% [])
(** [ixi n]          = [ Ix n ; .. ; Ix 2 ; Ix 1 ]
    [ixi ~shift:s n] = [ Ix (s+n) ; .. ; Ix (s+2) ; Ix (s+1) ]
*)

let fresh ?tsig ?(n=0) x =
  let shp =
    if n = 0 then Shape_expr
    else Shape_op n
  in
  let h =
    Option.fold begin fun h (tys, ty) ->
      let targ =
        if List.length tys = 0 then TRg ty
        else TOp (tys, ty)
      in
      assign h Props.targ_prop targ
    end (x %% []) tsig
  in
  Fresh (h, shp, Constant, Unbounded)


(* {3 Logic} *)

let choose ty =
  Sequent {
    context = [
      fresh ?tsig:(Option.map (fun ty -> [ ty ], TAtom TBool) ty)
      ~n:1 "P" %% []
    ] |> Deque.of_list ;
    active =
      all [ "x" ] ?tys:(Option.map (fun ty -> [ ty ]) ty) ~pats:[ [
        app (Ix 2 %% []) [ Ix 1 %% [] ] %% []
      ] ] (
        ifx B.Implies (
          app (Ix 2 %% []) [ Ix 1 %% [] ] %% []
        ) (
          app (Ix 2 %% []) [
            Choose (Option.fold annot ("y" %% []) ty, None,
            app (Ix 3 %% []) [ Ix 1 %% [] ] %% []) %% []
          ] %% []
        ) %% []
      ) %% []
  } %% []


(* {3 Sets} *)

let subseteq ty =
  all [ "x" ; "y" ]
  ?tys:(Option.map (fun ty -> [ TSet ty ; TSet ty ]) ty) ~pats:[ [
    ifx ?tys:(Option.map (fun ty -> [ ty ]) ty)
    B.Subseteq (Ix 2 %% []) (Ix 1 %% []) %% []
  ] ] (
    ifx B.Equiv (
      ifx ?tys:(Option.map (fun ty -> [ ty ]) ty)
      B.Subseteq (Ix 2 %% []) (Ix 1 %% []) %% []
    ) (
      all [ "z" ]
      ?tys:(Option.map (fun ty -> [ ty ]) ty) (
        ifx B.Implies (
          ifx ?tys:(Option.map (fun ty -> [ ty ]) ty)
          B.Mem (Ix 1 %% []) (Ix 3 %% []) %% []
        ) (
          ifx ?tys:(Option.map (fun ty -> [ ty ]) ty)
          B.Mem (Ix 1 %% []) (Ix 2 %% []) %% []
        ) %% []
      ) %% []
    ) %% []
  ) %% []

let setenum n ty =
  if n = 0 then
    all [ "x" ]
    ?tys:(Option.map (fun ty -> [ ty ]) ty) ~pats:[ [
      ifx ?tys:(Option.map (fun ty -> [ ty ]) ty)
      B.Mem (
        Ix 1 %% []
      ) (
        app ?tys:(Option.map (fun ty -> [ ty ]) ty) (
          SetEnum [] %% []
        ) [] %% []
      ) %% []
    ] ] (
      una B.Neg (
        ifx ?tys:(Option.map (fun ty -> [ ty ]) ty)
        B.Mem (
          Ix 1 %% []
        ) (
          app ?tys:(Option.map (fun ty -> [ ty ]) ty) (
            SetEnum [] %% []
          ) [] %% []
        ) %% []
      ) %% []
    ) %% []
  else
    all (gen "a" n @ [ "x" ])
    ?tys:(Option.map (fun ty -> dupl ty (n + 1)) ty) ~pats:[ [
      ifx ?tys:(Option.map (fun ty -> [ ty ]) ty)
      B.Mem (
        Ix 1 %% []
      ) (
        app ?tys:(Option.map (fun ty -> [ ty ]) ty) (
          SetEnum (ixi ~shift:1 n) %% []
        ) [] %% []
      ) %% []
    ] ] (
      ifx B.Equiv (
        ifx ?tys:(Option.map (fun ty -> [ ty ]) ty)
        B.Mem (
          Ix 1 %% []
        ) (
          app ?tys:(Option.map (fun ty -> [ ty ]) ty) (
            SetEnum (ixi ~shift:1 n) %% []
          ) [] %% []
        ) %% []
      ) (
        if n = 1 then
          ifx ?tys:(Option.map (fun ty -> [ ty ]) ty)
          B.Eq (Ix 1 %% []) (Ix 2 %% []) %% []
        else
          List (Or, List.map begin fun e ->
            ifx ?tys:(Option.map (fun ty -> [ ty ]) ty)
            B.Eq (Ix 1 %% []) e %% []
          end (ixi ~shift:1 n)) %% []
      ) %% []
    ) %% []

let union ty =
  all [ "a" ; "x" ]
  ?tys:(Option.map (fun ty -> [ TSet (TSet ty) ; ty ]) ty) ~pats:[ [
    ifx ?tys:(Option.map (fun ty -> [ ty ]) ty)
    B.Mem (
      Ix 1 %% []
    ) (
      una ?tys:(Option.map (fun ty -> [ ty ]) ty)
      B.UNION (
        Ix 2 %% []
      ) %% []
    ) %% []
  ] ] (
    ifx B.Equiv (
      ifx ?tys:(Option.map (fun ty -> [ ty ]) ty)
      B.Mem (
        Ix 1 %% []
      ) (
        una ?tys:(Option.map (fun ty -> [ ty ]) ty)
        B.UNION (
          Ix 2 %% []
        ) %% []
      ) %% []
    ) (
      exi [ "y" ]
      ?tys:(Option.map (fun ty -> [ TSet ty ]) ty) (
        ifx B.Conj (
          ifx ?tys:(Option.map (fun ty -> [ TSet ty ]) ty)
          B.Mem (
            Ix 1 %% []
          ) (
            Ix 3 %% []
          ) %% []
        ) (
          ifx ?tys:(Option.map (fun ty -> [ ty ]) ty)
          B.Mem (
            Ix 2 %% []
          ) (
            Ix 1 %% []
          ) %% []
        ) %% []
      ) %% []
    ) %% []
  ) %% []

let subset ty =
  all [ "a" ; "x" ]
  ?tys:(Option.map (fun ty -> [ TSet ty ; TSet ty ]) ty) ~pats:[ [
    ifx ?tys:(Option.map (fun ty -> [ ty ]) ty)
    B.Mem (
      Ix 1 %% []
    ) (
      una ?tys:(Option.map (fun ty -> [ ty ]) ty)
      B.SUBSET (
        Ix 2 %% []
      ) %% []
    ) %% []
  ] ] (
    ifx B.Equiv (
      ifx ?tys:(Option.map (fun ty -> [ ty ]) ty)
      B.Mem (
        Ix 1 %% []
      ) (
        una ?tys:(Option.map (fun ty -> [ ty ]) ty)
        B.SUBSET (
          Ix 2 %% []
        ) %% []
      ) %% []
    ) (
      all [ "y" ]
      ?tys:(Option.map (fun ty -> [ ty ]) ty) (
        ifx B.Implies (
          ifx ?tys:(Option.map (fun ty -> [ ty ]) ty)
          B.Mem (
            Ix 1 %% []
          ) (
            Ix 2 %% []
          ) %% []
        ) (
          ifx ?tys:(Option.map (fun ty -> [ ty ]) ty)
          B.Mem (
            Ix 1 %% []
          ) (
            Ix 3 %% []
          ) %% []
        ) %% []
      ) %% []
    ) %% []
  ) %% []

let cup ty =
  all [ "a" ; "b" ; "x" ]
  ?tys:(Option.map (fun ty -> [ TSet ty ; TSet ty ; ty ]) ty) ~pats:[ [
    ifx ?tys:(Option.map (fun ty -> [ ty ]) ty)
    B.Mem (
      Ix 1 %% []
    ) (
      ifx ?tys:(Option.map (fun ty -> [ ty ]) ty)
      B.Cup (
        Ix 3 %% []
      ) (
        Ix 2 %% []
      ) %% []
    ) %% []
  ] ] (
    ifx B.Equiv (
      ifx ?tys:(Option.map (fun ty -> [ ty ]) ty)
      B.Mem (
        Ix 1 %% []
      ) (
        ifx ?tys:(Option.map (fun ty -> [ ty ]) ty)
        B.Cup (
          Ix 3 %% []
        ) (
          Ix 2 %% []
        ) %% []
      ) %% []
    ) (
      ifx B.Disj (
        ifx ?tys:(Option.map (fun ty -> [ ty ]) ty)
        B.Mem (
          Ix 1 %% []
        ) (
          Ix 3 %% []
        ) %% []
      ) (
        ifx ?tys:(Option.map (fun ty -> [ ty ]) ty)
        B.Mem (
          Ix 1 %% []
        ) (
          Ix 2 %% []
        ) %% []
      ) %% []
    ) %% []
  ) %% []

let cap ty =
  all [ "a" ; "b" ; "x" ]
  ?tys:(Option.map (fun ty -> [ TSet ty ; TSet ty ; ty ]) ty) ~pats:[ [
    ifx ?tys:(Option.map (fun ty -> [ ty ]) ty)
    B.Mem (
      Ix 1 %% []
    ) (
      ifx ?tys:(Option.map (fun ty -> [ ty ]) ty)
      B.Cap (
        Ix 3 %% []
      ) (
        Ix 2 %% []
      ) %% []
    ) %% []
  ] ] (
    ifx B.Equiv (
      ifx ?tys:(Option.map (fun ty -> [ ty ]) ty)
      B.Mem (
        Ix 1 %% []
      ) (
        ifx ?tys:(Option.map (fun ty -> [ ty ]) ty)
        B.Cap (
          Ix 3 %% []
        ) (
          Ix 2 %% []
        ) %% []
      ) %% []
    ) (
      ifx B.Conj (
        ifx ?tys:(Option.map (fun ty -> [ ty ]) ty)
        B.Mem (
          Ix 1 %% []
        ) (
          Ix 3 %% []
        ) %% []
      ) (
        ifx ?tys:(Option.map (fun ty -> [ ty ]) ty)
        B.Mem (
          Ix 1 %% []
        ) (
          Ix 2 %% []
        ) %% []
      ) %% []
    ) %% []
  ) %% []

let setminus ty =
  all [ "a" ; "b" ; "x" ]
  ?tys:(Option.map (fun ty -> [ TSet ty ; TSet ty ; ty ]) ty) ~pats:[ [
    ifx ?tys:(Option.map (fun ty -> [ ty ]) ty)
    B.Mem (
      Ix 1 %% []
    ) (
      ifx ?tys:(Option.map (fun ty -> [ ty ]) ty)
      B.Setminus (
        Ix 3 %% []
      ) (
        Ix 2 %% []
      ) %% []
    ) %% []
  ] ] (
    ifx B.Equiv (
      ifx ?tys:(Option.map (fun ty -> [ ty ]) ty)
      B.Mem (
        Ix 1 %% []
      ) (
        ifx ?tys:(Option.map (fun ty -> [ ty ]) ty)
        B.Setminus (
          Ix 3 %% []
        ) (
          Ix 2 %% []
        ) %% []
      ) %% []
    ) (
      ifx B.Conj (
        ifx ?tys:(Option.map (fun ty -> [ ty ]) ty)
        B.Mem (
          Ix 1 %% []
        ) (
          Ix 3 %% []
        ) %% []
      ) (
        una ?tys:(Option.map (fun ty -> [ ty ]) ty)
        B.Neg (
          ifx ?tys:(Option.map (fun ty -> [ ty ]) ty)
          B.Mem (
            Ix 1 %% []
          ) (
            Ix 2 %% []
          ) %% []
        ) %% []
      ) %% []
    ) %% []
  ) %% []


let setst ty =
  Sequent {
    context = [
      fresh ?tsig:(Option.map (fun ty -> [ ty ], TAtom TBool) ty)
      ~n:1 "P" %% []
    ] |> Deque.of_list ;
    active =
      all [ "a" ; "x" ]
      ?tys:(Option.map (fun ty -> [ TSet ty ; ty ]) ty) ~pats:[ [
        ifx ?tys:(Option.map (fun ty -> [ ty ]) ty)
        B.Mem (
          Ix 1 %% []
        ) (
          app ?tys:(Option.map (fun ty -> [ ty ]) ty) (
            SetSt (
              Option.fold annot ("y" %% []) ty,
              Ix 2 %% [],
              app (Ix 4 %% []) [ Ix 1 %% [] ] %% []
            ) %% []
          ) [] %% []
        ) %% []
      ] ] (
        ifx B.Equiv (
          ifx ?tys:(Option.map (fun ty -> [ ty ]) ty)
          B.Mem (
            Ix 1 %% []
          ) (
            app ?tys:(Option.map (fun ty -> [ ty ]) ty) (
              SetSt (
                Option.fold annot ("y" %% []) ty,
                Ix 2 %% [],
                app (Ix 4 %% []) [ Ix 1 %% [] ] %% []
              ) %% []
            ) [] %% []
          ) %% []
        ) (
          ifx B.Conj (
            ifx ?tys:(Option.map (fun ty -> [ ty ]) ty)
            B.Mem (
              Ix 1 %% []
            ) (
              Ix 2 %% []
            ) %% []
          ) (
            app (Ix 3 %% []) [ Ix 1 %% [] ] %% []
          ) %% []
        ) %% []
      ) %% []
  } %% []

let setof n ttys =
  let tys, ty =
    match ttys with
    | None -> (List.init n (fun _ -> None), None)
    | Some (tys, ty) -> (List.map (fun ty -> Some ty) tys, Some ty)
  in
  Sequent {
    context = [
      fresh ?tsig:ttys ~n:n "F" %% []
    ] |> Deque.of_list ;
    active =
      all (gen "a" n @ [ "x" ])
      ?tys:(Option.map (fun (tys, ty) -> List.map (fun ty -> TSet ty) tys @ [ ty ]) ttys) ~pats:[ [
        ifx ?tys:(Option.map (fun ty -> [ ty ]) ty)
        B.Mem (
          Ix 1 %% []
        ) (
          app ?tys:(Option.map (fun ty -> [ ty ]) ty) (
            SetOf (
              app (Ix (2*n + 2) %% []) (ixi n) %% [],
              List.map2 begin fun e ty ->
                let h = Option.fold annot ("y" %% []) ty in
                (h, Constant, Domain e)
              end (ixi ~shift:1 n) tys
            ) %% []
          ) [] %% []
        ) %% []
      ] ] (
        ifx B.Equiv (
          ifx ?tys:(Option.map (fun ty -> [ ty ]) ty)
          B.Mem (
            Ix 1 %% []
          ) (
            app ?tys:(Option.map (fun ty -> [ ty ]) ty) (
              SetOf (
                app (Ix (2*n + 2) %% []) (ixi n) %% [],
                List.map2 begin fun e ty ->
                  let h = Option.fold annot ("y" %% []) ty in
                  (h, Constant, Domain e)
                end (ixi ~shift:1 n) tys
              ) %% []
            ) [] %% []
          ) %% []
        ) (
          exi (gen "y" n)
          ?tys:(Option.map fst ttys) (
            List (And, List.map2 begin fun e1 (e2, ty) ->
              ifx ?tys:(Option.map (fun ty -> [ ty ]) ty)
              B.Mem e1 e2 %% []
            end (ixi n) (List.combine (ixi ~shift:(n + 1) n) tys)
            @ [
              ifx ?tys:(Option.map (fun ty -> [ ty ]) ty)
              B.Eq (
                Ix (n + 1) %% []
              ) (
                app (Ix (2*n + 2) %% []) (ixi n) %% []
              ) %% []
            ]
            ) %% []
          ) %% []
        ) %% []
      ) %% []
  } %% []


(* {3 Functions} *)

let arrow tys =
  let ty1, ty2 =
    match tys with
    | None -> (None, None)
    | Some (ty1, ty2) -> (Some ty1, Some ty2)
  in
  all [ "a" ; "b" ; "f" ]
  ?tys:(Option.map (fun (ty1, ty2) -> [ TSet ty1 ; TSet ty2 ; TArrow (ty1, ty2) ]) tys)
  ~pats:[ [
    ifx ?tys:(Option.map (fun (ty1, ty2) -> [ TArrow (ty1, ty2) ]) tys)
    B.Mem (
      Ix 1 %% []
    ) (
      app ?tys:(Option.map (fun (ty1, ty2) -> [ ty1 ; ty2 ]) tys)
      (Arrow (Ix 3 %% [], Ix 2 %% []) %% []) [] %% []
    ) %% []
  ] ] (
    ifx B.Equiv (
      ifx ?tys:(Option.map (fun (ty1, ty2) -> [ TArrow (ty1, ty2) ]) tys)
      B.Mem (
        Ix 1 %% []
      ) (
        app ?tys:(Option.map (fun (ty1, ty2) -> [ ty1 ; ty2 ]) tys)
        (Arrow (Ix 3 %% [], Ix 2 %% []) %% []) [] %% []
      ) %% []
    ) (
      List (And, [
        ifx ?tys:(Option.map (fun ty -> [ TSet ty ]) ty1)
        B.Eq (
          una ?tys:(Option.map (fun ty -> [ ty ]) ty1)
          B.DOMAIN (
            Ix 1 %% []
          ) %% []
        ) (
          Ix 3 %% []
        ) %% [] ;
        all [ "x" ] ?tys:(Option.map (fun ty -> [ ty ]) ty1) (
          ifx B.Implies (
            ifx ?tys:(Option.map (fun ty -> [ ty ]) ty1)
            B.Mem (
              Ix 1 %% []
            ) (
              Ix 4 %% []
            ) %% []
          ) (
            ifx ?tys:(Option.map (fun ty -> [ ty ]) ty2)
            B.Mem (
              app ?tys:(Option.map (fun (ty1, ty2) -> [ ty1 ; ty2 ]) tys)
              (FcnApp (
                Ix 2 %% [],
                [ Ix 1 %% [] ]
              ) %% []) [] %% []
            ) (
              Ix 3 %% []
            ) %% []
          ) %% []
        ) %% []
      ]) %% []
    ) %% []
  ) %% []

let domain tys =
  let ty1 = Option.map fst tys in
  Sequent {
    context = [
      fresh ?tsig:(Option.map (fun (ty1, ty2) -> ([ ty1 ], ty2)) tys)
      ~n:1 "F" %% []
    ] |> Deque.of_list ;
    active =
      all [ "a" ]
      ?tys:(Option.map (fun ty -> [ TSet ty ]) ty1) ~pats:[ [
        una ?tys:(Option.map (fun ty -> [ ty ]) ty1)
        B.DOMAIN (
          Fcn (
            [ Option.fold annot ("x" %% []) ty1, Constant, Domain (Ix 1 %% []) ],
            app (Ix 3 %% []) [ Ix 1 %% [] ] %% []
          ) %% []
        ) %% []
      ] ] (
        ifx ?tys:(Option.map (fun ty -> [ TSet ty ]) ty1)
        B.Eq (
          una ?tys:(Option.map (fun ty -> [ ty ]) ty1)
          B.DOMAIN (
            Fcn (
              [ Option.fold annot ("x" %% []) ty1, Constant, Domain (Ix 1 %% []) ],
              app (Ix 3 %% []) [ Ix 1 %% [] ] %% []
            ) %% []
          ) %% []
        ) (
          Ix 1 %% []
        ) %% []
      ) %% []
  } %% []

let fcnapp tys =
  let ty1, ty2 =
    match tys with
    | None -> (None, None)
    | Some (ty1, ty2) -> (Some ty1, Some ty2)
  in
  Sequent {
    context = [
      fresh ?tsig:(Option.map (fun (ty1, ty2) -> ([ ty1 ], ty2)) tys)
      ~n:1 "F" %% []
    ] |> Deque.of_list ;
    active =
      all [ "a" ; "x" ]
      ?tys:(Option.map (fun ty -> [ TSet ty ; ty ]) ty1) ~pats:[ [
        ifx ?tys:(Option.map (fun ty -> [ ty ]) ty1)
        B.Mem (
          Ix 1 %% []
        ) (
          Ix 2 %% []
        ) %% []
      ] ] (
        ifx B.Implies (
          ifx ?tys:(Option.map (fun ty -> [ ty ]) ty1)
          B.Mem (
            Ix 1 %% []
          ) (
            Ix 2 %% []
          ) %% []
        ) (
          ifx ?tys:(Option.map (fun ty -> [ ty ]) ty2)
          B.Eq (
            app ?tys:(Option.map (fun (ty1, ty2) -> [ ty1 ; ty2 ]) tys) (
              FcnApp (
                Fcn (
                  [ Option.fold annot ("y" %% []) ty1, Constant, Domain (Ix 2 %% []) ],
                  app (Ix 4 %% []) [ Ix 1 %% [] ] %% []
                ) %% [],
                [ Ix 1 %% [] ]
              ) %% []
            ) [] %% []
          ) (
            app (Ix 3 %% []) [ Ix 1 %% [] ] %% []
          ) %% []
        ) %% []
      ) %% []
  } %% []


(* {3 Booleans} *)

let booleans =
  Internal B.TRUE %% []


(* {3 Strings} *)

let strings =
  Internal B.TRUE %% []


(* {3 Arithmetic} *)

let ints =
  Internal B.TRUE %% []

let nats =
  Internal B.TRUE %% []

let reals =
  Internal B.TRUE %% []
