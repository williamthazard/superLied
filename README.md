# superLied

WIP Lied script for SuperCollider. <br>
<br>
The grid of buttons works this way:<br>
<b>Row 1</b>: recall lines you've typed from history<br>
<b>Row 2</b>: trigger synth patterns<br>
<b>Row 3</b>: apply the active line (either the most-recently-entered one or the one you've recalled with row 1) to the pattern immediately above<br>
<b>Row 4</b>: aprs. Trigger sample playback and playback speed manipulation. Samples will be cut up and have their playback speed manipulated in ways determined by the active line<br>
<b>Row 5</b>: apply the active line (either the most-recently-entered one or the one you've recalled with row 1) to the sample cutter/speed slot immediately above<br>
<b>Row 6</b>: mirrors row 3 (more samplers)<br>
<b>Row 7</b>: mirrors row 4 (sends lines to samplers in row 6)<br>
<b>Row 8</b>: trigger sample playback. These samples play in their entirety and are unaffected by the active line (works nicely for drums)
<br><br>
The knobs correspond roughly to the synths and samplers on the grid. 128 knobs, 128 buttons. Play around with them. See what happens.
<b>note: in order for superlied.scd to work properly, you'll need to add the 3 .sc files in the "classes" folder to your extensions folder (if you don't know where your extensions folder is, SuperCollider's IDE will show you! Just hit file > open user support directory)</b>
