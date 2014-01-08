Require Import List ListSet.
Require Import "basic".
Generalizable All Variables.
Set Implicit Arguments.
Inductive InDom {A B} : list (A * B) -> A -> Prop :=
  | dom_fst : `{InDom ((a,b)::rst) a}
  | dom_rst : `{InDom l a -> InDom ((a',b')::l) a}.

Inductive MapsTo {A B} : list (A * B) -> A -> B -> Prop :=
  | map_fst : `{MapsTo ((a,b)::rst) a b}
  | map_rst : `{a <> a' -> MapsTo l a b -> MapsTo ((a',b')::l) a b}.

Inductive Unmapped {A B} : list (A * B) -> A -> Prop :=
  | unil : forall a, Unmapped nil a
  | ucons : forall a a' b l, Unmapped l a' -> a <> a' -> Unmapped ((a,b)::l) a'.

Inductive Functional {A B} : list (A * B) -> Prop :=
  | empty_fn : Functional nil
  | extend_fn : `{Functional l -> Unmapped l a -> Functional ((a,b)::l)}.

Lemma MapsTo_In : forall A B (l : list (A * B)) a b (H: MapsTo l a b), In (a,b) l.
Proof.
  induction l as [|(a,b) l' IH];
  intros a' b' H; inversion H; (* finishes base case *)
  subst; [constructor|right; apply IH]; auto.
Qed.

Theorem InDom_is_mapped : forall A B (eq_dec : dec_type A) (l : list (A * B)) a, InDom l a <-> exists b, MapsTo l a b.
Proof.
  induction l as [|(a_,b_) l_ IH].
  split; [intro H; inversion H |intros [x H]; inversion H].
  intro a; destruct (eq_dec a_ a) as [Heq|Hneq].
  subst; split; [exists b_|]; constructor.
  split; intro H;
   [inversion H as [|? ? ? ? H']; subst;
    [contradict Hneq
    |rewrite IH in H'; destruct H' as [b H'']; exists b; constructor]
   |destruct H as [b H'']; inversion H''; subst; [contradict Hneq|constructor; rewrite IH; exists b]]; auto.
Qed.

Theorem InDom_In : forall A B (eq_dec : dec_type A) (l : list (A * B)) a, InDom l a <-> exists b, In (a,b) l.
Proof.
  intros; split; intro H;
  [rewrite InDom_is_mapped in H; auto; destruct H as [b H']; apply MapsTo_In in H'; exists b
  |destruct H as [b H']; induction l as [|(a_,b_) l_ IH]; inversion H'; [inject_pair|];constructor]; auto.
Qed. 

Theorem unmapped_not_mapped : forall A B
                                     (eq_dec : dec_type A)
                                     (l : list (A*B)) a,
                                (Unmapped l a <-> forall b, ~ MapsTo l a b).
Proof.
  intros A B eq_dec l a; induction l as [|(a',b') l' [IHl'0 IHl'1]];
  split;
  [intros H b bad; inversion bad
  |constructor
  |intros H b0 bad;
    inversion H as [| ? ? ? ? Hunmapped Hbad];
    inversion bad as [| ? ? ? ? ? ? Hbadmap]; subst;
    [contradict Hbad; reflexivity
    |specialize IHl'0 with Hunmapped; apply IHl'0 in Hbadmap]  
  |intros H; constructor;
  [apply IHl'1; intros bb bad; destruct (eq_dec a a'); subst;
      [pose (HC := (H b')); contradict HC; constructor
      |pose (HC := (H bb)); contradict HC; constructor; auto]
     |intro Heq; subst; apply H with (b := b'); constructor]]; auto.
Qed.

Lemma in_not_unmapped : forall A B (l : list (A * B)) a b (H:In (a,b) l), ~ Unmapped l a.
Proof.
  induction l as [|(a,b) l' IH]; intros a0 b0 H bad; inversion H; subst.
  inject_pair;
    inversion bad; auto.
  inversion bad as [|? ? ? ? bad']; apply IH with (b:= b0) in bad'; auto.
Qed.


Lemma in_functional_mapsto : forall A B (eq_dec : dec_type A) (l : list (A * B)) (F : Functional l)
                                    a b (H : In (a,b) l), MapsTo l a b.
Proof.
  induction l as [|(a,b) l' IH];
  intros F a' b' H; inversion H;[ (* finishes base case *)
    inject_pair; subst; constructor; auto
  |inversion F as [|? ? ? Hfun Hunmapped]; subst;
   destruct (eq_dec a a'); [subst; contradict Hunmapped; apply in_not_unmapped with (b:=b')
                           |constructor]]; auto.
Qed.

Remark functional_exchange : forall A B (l : list (A * B)) a b (F: Functional ((a,b)::l)) b', Functional ((a,b')::l).
Proof. intros; inversion F; constructor; auto. Qed.

Lemma MapsTo_same : forall A B (l : list (A * B)) a b b', MapsTo l a b -> MapsTo l a b' -> b = b'.
Proof.
  induction l as [|a0 l_ IH]; intros;
   inversion H;
   subst; inversion H0; subst; solve [reflexivity | bad_eq | apply IH with (a := a); auto].
Qed. 

Fixpoint extend_map {A B} (eq_dec : (dec_type A)) (a : A) (b : B) (ρ : list (A * B)) :=
  match ρ with
    | nil => (a, b)::nil
    | (a',b')::ρ' => if eq_dec a a' then
                       (a,b)::ρ'
                     else (a',b')::(extend_map eq_dec a b ρ')
  end.
Fixpoint lookup_map {A B} (eq_dec : (dec_type A)) (a : A) (ρ : list (A * B)) : option B :=
  match ρ with
    | nil => None
    | (a',b)::ρ' => if eq_dec a a' then
                       Some b
                     else (lookup_map eq_dec a ρ')
  end.

Theorem lookup_mapsto : forall A B (eq_dec : dec_type A) (l : list (A * B)) a b,
                          prod ((MapsTo l a b) -> (lookup_map eq_dec a l) = Some b)
                               ((lookup_map eq_dec a l) = Some b -> (MapsTo l a b)).
Proof.
  induction l as [|(a,b) l' IH]; [intros a b; split; intro Hvac; inversion Hvac|].
  intros a' b'; split; intro H; simpl in *;
  destruct (eq_dec a' a) as [Hleft|Hright];
  solve
   [inversion H; 
   try solve [contradict Hleft; auto
             |contradict Hright; auto
             |apply IH; auto
             |auto]
   |injection H; intros; subst; constructor
   |constructor; [|apply IH];auto].
Qed.

