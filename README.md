# superLied

WIP Lied script for SuperCollider. 

Note that you'll have to load your own samples, in lines 278-329, in order for this to run properly.

The grid of buttons works this way:
Row 1: recall lines you've types from history
Row 2: trigger synth patterns
Row 3: apply the active line (either the most-recently-entered one or the one you've recalled with row 1) to the pattern immediately above
Row 4: trigger sample playback. Samples will be cut up by the active line
Row 5: apply the active line (either the most-recently-entered one or the one you've recalled with row 1) to the sample immediately above
Row 6: currently unused
Row 7: currently unused
Row 8: trigger sample playback. These samples play in their entirety and are unaffected by the active line (so this row works nicely for drum patterns)
