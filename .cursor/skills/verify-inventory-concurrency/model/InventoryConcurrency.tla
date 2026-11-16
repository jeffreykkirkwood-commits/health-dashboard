------------------------------ MODULE InventoryConcurrency ------------------------------
(***************************************************************************)
(* Model of health-dashboard Inventory updated workflow concurrency (#239).*)
(*                                                                         *)
(* Code map (.github/workflows/inventory-updated.yml):                     *)
(*   group  == inventory-${number}-${'pr' | run_id}                        *)
(*   cancel == (event_name == 'pull_request')                              *)
(*                                                                         *)
(* CONSTANTS SafeGrouping = TRUE  models current workflow (comment groups  *)
(*           include unique run_id; cancel only for pull_request).         *)
(*           SafeGrouping = FALSE models the pre-#239 bug: every event on  *)
(*           a PR shares one group and cancel-in-progress stays on.        *)
(***************************************************************************)
EXTENDS Naturals, FiniteSets, Sequences, TLC

CONSTANTS PRs, RunIds, SafeGrouping
ASSUME Cardinality(PRs) >= 1
ASSUME Cardinality(RunIds) >= 3
ASSUME SafeGrouping \in BOOLEAN
ASSUME \A p \in PRs: p \in Nat /\ p # 0
ASSUME \A r \in RunIds: r \in Nat

\* 0 = idle / none for kind and pr fields (avoids mixing strings with Nats).
\* kind: 1 = pull_request, 2 = issue_comment
PRKind == 1
CommentKind == 2
Idle == 0

VARIABLES
  kindOf,     \* [run -> {Idle, PRKind, CommentKind}]
  groupOf,    \* [run -> Seq(Nat)]; <<>> = idle
  prOf,       \* [run -> PRs \cup {Idle}]
  active,     \* set of run ids currently running
  cancelled,  \* set of run ids that were cancelled while active
  unused      \* run ids not yet started

vars == <<kindOf, groupOf, prOf, active, cancelled, unused>>

\* Group token: under SafeGrouping, PR runs share <<1, n>>; comment runs
\* get <<2, n, run>>. Under the broken design every run on PR n shares <<1, n>>.
GroupToken(kind, pr, run) ==
  IF ~SafeGrouping
  THEN <<1, pr>>
  ELSE IF kind = PRKind
       THEN <<1, pr>>
       ELSE <<2, pr, run>>

CancelsOthers(kind) ==
  IF SafeGrouping THEN kind = PRKind ELSE TRUE

TypeOK ==
  /\ DOMAIN kindOf = RunIds
  /\ DOMAIN groupOf = RunIds
  /\ DOMAIN prOf = RunIds
  /\ \A r \in RunIds: kindOf[r] \in {Idle, PRKind, CommentKind}
  /\ \A r \in RunIds: prOf[r] \in PRs \cup {Idle}
  /\ active \subseteq RunIds
  /\ cancelled \subseteq RunIds
  /\ unused \subseteq RunIds
  /\ active \cap unused = {}

Init ==
  /\ kindOf = [r \in RunIds |-> Idle]
  /\ groupOf = [r \in RunIds |-> <<>>]
  /\ prOf = [r \in RunIds |-> Idle]
  /\ active = {}
  /\ cancelled = {}
  /\ unused = RunIds

Start(kind, pr, run) ==
  /\ run \in unused
  /\ LET g == GroupToken(kind, pr, run)
         victims == IF CancelsOthers(kind)
                    THEN {a \in active : groupOf[a] = g}
                    ELSE {}
     IN  /\ kindOf' = [kindOf EXCEPT ![run] = kind]
         /\ groupOf' = [groupOf EXCEPT ![run] = g]
         /\ prOf' = [prOf EXCEPT ![run] = pr]
         /\ active' = (active \ victims) \cup {run}
         /\ cancelled' = cancelled \cup victims
         /\ unused' = unused \ {run}

Finish(run) ==
  /\ run \in active
  /\ active' = active \ {run}
  /\ kindOf' = [kindOf EXCEPT ![run] = Idle]
  /\ groupOf' = [groupOf EXCEPT ![run] = <<>>]
  /\ prOf' = [prOf EXCEPT ![run] = Idle]
  /\ UNCHANGED <<cancelled, unused>>

Next ==
  \/ \E kind \in {PRKind, CommentKind}, pr \in PRs, run \in unused: Start(kind, pr, run)
  \/ \E run \in active: Finish(run)

Spec == Init /\ [][Next]_vars

\* Promise: a comment run is never cancelled (the #239 deploy-blocker).
Inv_CommentNeverCancelled ==
  \A r \in cancelled: kindOf[r] # CommentKind

====
