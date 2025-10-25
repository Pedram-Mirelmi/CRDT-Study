# TODO

## Options and Different Cases to Incorporate
- buffer for effects (deltas, or states, or ...)
    - also figure out if there should be difference when implementing it for different kinds of CRDTs
- network topology; abstract or not?
- CPU processing



## High level tasks
- Implementing Join-Decomposition & Big-delta Set CRDTs
    - State-based:
        - send full state every T ms regardless of everything -> this makes sense only if we assume msg drop
        - send full state every T ms only of there's been an update to that CRDT -> this makes sense if we assume no message drop
    - Naive-Delta
- fix traffic analyzer (record time in the replica itself)

     


## Bonus Tasks
- Implementing Other CRDTs
    - Map
- analyze each node computing time
    






