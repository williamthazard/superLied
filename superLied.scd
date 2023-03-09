(
//server
Server.default = Server.local;
Server.default.options.memSize_(2.pow(20));

//tempo
~t = 60/128;

//words, words, words
~b = " ".ascii%32;
~note = Array.fill(128, {0});
~noted = Array.fill(128, {0});
~player = Array.fill(128, {0});
~a = Array.fill(128, {0});

//default values for knob-controlled parameters
~idim = Array.fill(128, {0});
~idim[0]=0.42;
~idim[1]=0.25;
~idim[2]=0.88;
~idim[3]=0.70;
~idim[4]=0.63;
~idim[5]=0.90;
~idim[6]=0.10;
~idim[7]=0.33;
~idim[112]=0.20;

//wait
s.waitForBoot({

//gui
	//text entry interface & background XY scope
Window.closeAll;
w = Window.new("superLied",Window.availableBounds)
.background_(Color.black)
.fullScreen
.onClose_({~tipScope.kill; ~topScope.stop; ~bf.free; ~fb.free})
.layout = VLayout(~bodyView,~entry_view);
~num_history_lines = 16;
~line_width = 80;
~line_height = 30;
~tnof = Font('Monaco',~line_height);

~bf = Buffer.alloc(Server.default,4096,2);
~fb = Bus.audio(Server.default,2);

~topScope = ScopeView(w,
		Rect(0,
			0,
			w.view.bounds.width,
			w.view.bounds.height))
	.bufnum_(~bf.bufnum)
	.server_(Server.default)
	.style_(2)
	.xZoom_(8)
	.yZoom_(8)
	.waveColors_([Color.grey,Color.white])
	.background_(Color.black)
	.start;

~history_line_views = Array.fill(~num_history_lines,{
		StaticText(w, (w.view.bounds.width/2-20)@~line_height).stringColor_(Color.new(1,1,1,0.5)).background_(Color.clear).font=~tnof
});

~bodyView = HLayout(~history_line_views,~topScope);

~entry_view = TextField(w, w.view.bounds.width@~line_height).background_(Color.new(1,1,1,0.5)).font=~tnof;

~history = LinkedList.new;
~num_history_lines.do({ ~history.add("") });
~historyproxy = List.new;

~entry_view.action = {
	arg view;
	~history.add(~entry_view.string);
	~history.popFirst;
	~num_history_lines.do({ arg i;
		~history_line_views[i].string = ~history[i];
	});
	~historyproxy.add(~entry_view.string);
	~b = ~entry_view.string.ascii%32;
	~entry_view.string = "";
};

	//knob & button interface
k = Window("nested", Rect(
	Window.availableBounds.width/2,
	60,
	Window.availableBounds.width/2,
	Window.availableBounds.width/2),
	border:false)
.front
.background_(Color.clear)
.alwaysOnTop_(true);

k.view.decorator_(FlowLayout(k.bounds,5@5,0@0));

~comp = Array.fill(2, {
	arg view;
	view = CompositeView(k,k.bounds.width@(k.bounds.height/2))
	.background_(Color.clear);

	view.decorator_(FlowLayout(view.bounds,5@5,0@0));
});

	//knobs
Array.fill(128,{ arg i = 0;
	Knob(
		~comp[0],
		(k.bounds.width/16.9)@(k.bounds.width/16.9)
).color_(
		[
			Color.new(1,1,1,0.5),
			Color.new(1,1,1,0.5),
			Color.new(0,0,0,0.5),
			Color.new(0,0,0,0.5)
		]
		).value_(
			~idim[i]
		);
		i = i + 1
}
);

~comp[0].children[0].action_({arg obj; Pdefn(\0, Pseq([obj.value.linlin(0,1,-24,24)],inf))});
~comp[0].children[1].action_({arg obj; Pdefn(\1, Pseq([obj.value.linlin(0,1,-24,24)],inf))});
~comp[0].children[2].action_({arg obj; Pdefn(\2, Pseq([obj.value.linlin(0,1,-24,24)],inf))});
~comp[0].children[3].action_({arg obj; Pdefn(\3, Pseq([obj.value.linlin(0,1,-24,24)],inf))});
~comp[0].children[4].action_({arg obj; Pdefn(\4, Pseq([obj.value.linlin(0,1,-24,24)],inf))});
~comp[0].children[5].action_({arg obj; Pdefn(\5, Pseq([obj.value.linlin(0,1,-24,24)],inf))});
~comp[0].children[6].action_({arg obj; Pdefn(\6, Pseq([obj.value.linlin(0,1,-24,24)],inf))});
~comp[0].children[7].action_({arg obj; Pdefn(\7, Pseq([obj.value.linlin(0,1,0,0.3)],inf))});
~comp[0].children[112].action_({arg obj; Pdefn(\112, Pseq([obj.value.linlin(0,1,0.1,10000)],inf))});
~comp[0].children[113].action_({arg obj; Pdefn(\113, Pseq([obj.value.linlin(0,1,0.1,10000)],inf))});
~comp[0].children[114].action_({arg obj; Pdefn(\114, Pseq([obj.value.linlin(0,1,0.1,10000)],inf))});
~comp[0].children[115].action_({arg obj; Pdefn(\115, Pseq([obj.value.linlin(0,1,0.1,10000)],inf))});
~comp[0].children[116].action_({arg obj; Pdefn(\116, Pseq([obj.value.linlin(0,1,0.1,10000)],inf))});

	//buttons
4.do{(
Array.fill(16,{
	Button(
		~comp[1],
		(k.bounds.width/16.9)@(k.bounds.width/16.9)
	).states_(
		[
		[ " ",
			Color.new(1,1,1,0.5),
			Color.new(1,1,1,0.5)
		]
		]
	)
}
);

Array.fill(16,{
	Button(
		~comp[1],
		(k.bounds.width/16.9)@(k.bounds.width/16.9)
	).states_(
		[
			[ " ",
				Color.new(1,1,1,0.25),
				Color.new(1,1,1,0.25)
			],
			[ " ",
				Color.new(1,1,1,0.75),
				Color.new(1,1,1,0.75)
			]
		]
	).mouseDownAction_(
		{
			arg view;
			if(view.value == 3)
			{view.value = 1}
		}
	)
}
);
)
};

16.do{
		arg i;
		~comp[1].children[i].mouseDownAction_({
			~b = ~historyproxy[i].ascii%32;
			AppClock.sched(0,{~entry_view.object = ~historyproxy[i]});
			AppClock.sched(0.5,{~entry_view.object = ""})
		}
	)
};

16.do{
		arg i;
		~comp[1].children[i+16].mouseDownAction_({
			arg view;
			if(view.value == 3)
			{view.value = 1};
			if(view.value == 0,
				{~a[i+16].play(quant:(~t*4))},
				{~a[i+16].stop}
			)
		}
	)
};

16.do{
		arg i;
		~comp[1].children[i+32].mouseDownAction_({
			~note[i+32].source = PatternProxy(Pseq(~b.rotate(i+32), inf));
			~noted[i+32] = ~note[i+32].asStream
		}
	)
};

16.do{
		arg i;
		~comp[1].children[i+48].mouseDownAction_({
			arg view;
			if(view.value == 3)
			{view.value = 1};
			if(view.value == 0,
				{~a[i+48].play(quant:(~t*4))},
				{~a[i+48].stop}
			)
		}
	)
};

16.do{
		arg i;
		~comp[1].children[i+64].mouseDownAction_({
			~note[i+64].source = PatternProxy(Pseq(~b.rotate(i+64), inf));
			~noted[i+64] = ~note[i+64].asStream
		}
	)
};

16.do{
		arg i;
		~comp[1].children[i+80].mouseDownAction_({
			arg view;
			if(view.value == 3)
			{view.value = 1};
			if(view.value == 0,
				{~a[i+80].play(quant:(~t*4))},
				{~a[i+80].stop}
			)
		}
	)
};

16.do{
		arg i;
		~comp[1].children[i+96].mouseDownAction_({
			~note[i+96].source = PatternProxy(Pseq(~b.rotate(i+96), inf));
			~noted[i+96] = ~note[i+96].asStream
		}
	)
};

16.do{
		arg i;
		~comp[1].children[i+112].mouseDownAction_({
			arg view;
			if(view.value == 3)
			{view.value = 1};
			if(view.value == 0,
				{~a[i+112].play(quant:(~t*4))},
				{~a[i+112].stop}
			)
		}
	)
};

//samples go here! Change PathName to point to your own folder(s) of samples
	//TIP: you can drag and drop a folder right into this window, and its pathname will show up where you drop it
d = Dictionary.new;
d.add(\l ->
	PathName(thisProcess.nowExecutingPath.dirname++"/samples/606/").entries.collect({
	arg sf;
	Buffer.read(s, sf.fullPath);
});
);
d.add(\m ->
	PathName(thisProcess.nowExecutingPath.dirname++"/samples/808/").entries.collect({
	arg sf;
	Buffer.read(s, sf.fullPath);
});
);
d.add(\h ->
	PathName(thisProcess.nowExecutingPath.dirname++"/samples/909/").entries.collect({
	arg sf;
	Buffer.read(s, sf.fullPath);
});
);
d.add(\zk ->
	PathName(thisProcess.nowExecutingPath.dirname++"/samples/zkikz/").entries.collect({
	arg sf;
	Buffer.read(s, sf.fullPath);
});
);
d.add(\zm ->
	PathName(thisProcess.nowExecutingPath.dirname++"/samples/zmetal/").entries.collect({
	arg sf;
	Buffer.read(s, sf.fullPath);
});
);
d.add(\zp ->
	PathName(thisProcess.nowExecutingPath.dirname++"/samples/zpercz/").entries.collect({
	arg sf;
	Buffer.read(s, sf.fullPath);
});
);
d.add(\zs ->
	PathName(thisProcess.nowExecutingPath.dirname++"/samples/zsnarez/").entries.collect({
	arg sf;
	Buffer.read(s, sf.fullPath);
});
);
d.add(\n ->
	PathName(thisProcess.nowExecutingPath.dirname++"/samples/PBP/").entries.collect({
	arg sf;
	Buffer.readChannel(s, sf.fullPath, channels: 0);
	Buffer.readChannel(s, sf.fullPath, channels: 1);
});
);

(
// listening to the bus, using ScopeOut2 to write it to the buffer
~af = SynthDef("duoscope", { arg bus, bufnum;
    var z;
    z = In.ar(bus, 2);

    ScopeOut2.ar(z, bufnum);
    Out.ar(0, z);
}).play(
    target: RootNode(Server.default),
    args: [\bus, ~fb.index, \bufnum, ~bf.bufnum],
    addAction: \addToTail // make sure it goes after what you are scoping
);
);


//samplers
(
SynthDef(\bufPlay, {
	arg buf=[0,1],
		rate=1,
		amp=1,
		cutoff=1200,
		bus=~fb.index;
	var sig;
	sig = HPF.ar(PlayBuf.ar(1, buf, BufRateScale.ir(buf) * rate, doneAction:2),cutoff);
	sig = sig * amp;
	Out.ar(
		bus,
		sig!2
	)
}).add;
);

(
Task({
SynthDef(\PlayBufPlayer, {
    arg out=0, bufnum=0, rate=1, start=0, end=1, t_trig=0,
		loops=1, amp=0.2, pan=0, rateSlew=0.1, panSlew=1, bus=~fb.index;
    var snd,snd2,pos,pos2,frames,duration,env,sig;
    var startA,endA,startB,endB,crossfade,aOrB;

    aOrB=ToggleFF.kr(t_trig);
    startA=Latch.kr(start,aOrB);
    endA=Latch.kr(end,aOrB);
    startB=Latch.kr(start,1-aOrB);
    endB=Latch.kr(end,1-aOrB);
    crossfade=Lag.ar(K2A.ar(aOrB),0.1);


	rate = Lag.kr(rate,rateSlew)*BufRateScale.kr(bufnum);
    frames = BufFrames.kr(bufnum);
    duration = frames*(end-start)/rate.abs/s.sampleRate*loops;

    env=EnvGen.ar(
        Env.new(
            levels: [0,amp,amp,0],
            times: [0,duration-0.1,0.1],
        ),
        gate:t_trig,
    );

    pos=Phasor.ar(
        trig:aOrB,
        rate:rate,
        start:(((rate>0)*startA)+((rate<0)*endA))*frames,
        end:(((rate>0)*endA)+((rate<0)*startA))*frames,
        resetPos:(((rate>0)*startA)+((rate<0)*endA))*frames,
    );

    snd=BufRd.ar(
        numChannels:1,
        bufnum:bufnum,
        phase:pos,
        interpolation:4,
    );

    pos2=Phasor.ar(
        trig:(1-aOrB),
        rate:rate,
        start:(((rate>0)*startB)+((rate<0)*endB))*frames,
        end:(((rate>0)*endB)+((rate<0)*startB))*frames,
        resetPos:(((rate>0)*startB)+((rate<0)*endB))*frames,
    );

    snd2=BufRd.ar(
        numChannels:1,
        bufnum:bufnum,
        phase:pos2,
        interpolation:4,
    );

	sig=Pan2.ar(
				(crossfade*snd)+((1-crossfade)*snd2) * env,
				pan
	);

	Out.ar(bus,sig)
}).play(s, [\out, 0]);
s.sync;
3.do({arg i=0;
	~player.put(48+i, Synth(\PlayBufPlayer, [\bufnum, d[\n][i]]));
});
}
).play;
);

//synths
(
SynthDef(\sine, {
	arg freq=330,
		atk=0.005,
		rel=0.3,
		amp=1,
		pan=0,
		bus=~fb.index;

	var sig,
		env;
		sig = SinOsc.ar(freq);
	env = EnvGen.kr(Env.new([0,1,0],[atk,rel],[1,-1]),doneAction:2);
	sig = Pan2.ar(sig, pan, amp);
	sig = sig * env;
	Out.ar(
		bus,
		sig
	)
}).add;
);

(
SynthDef(\sinsin, {
	arg freq=440,
		index=1,
		modnum=1,
		modeno=1,
		phase=0,
		atk=0,
		rel=0.4,
		amp=0.2,
		pan=0,
		bus=~fb.index;

	var modfreq = (modnum/modeno)*freq;
	var env = Env.perc(
					attackTime: atk,
					releaseTime: rel,
					level: amp).kr(doneAction: 2);
	var sig = Pan2.ar((SinOsc.ar(freq + (index*modfreq*SinOsc.ar(modfreq)), phase, amp)*env),pan);
    Out.ar(
        bus,
        sig
    )
}).add;
);

(
SynthDef(\trisin, {
	arg freq=440,
		index=1,
		modnum=1,
		modeno=1,
		phase=0,
		atk=2,
		rel=2,
		amp=0.2,
		pan=0,
		bus=~fb.index;

	var modfreq = (modnum/modeno)*freq;
	var env = Env.perc(
					attackTime: atk,
					releaseTime: rel,
					level: amp).kr(doneAction: 2);
	var sig = Pan2.ar((LFTri.ar(freq + (index*modfreq*SinOsc.ar(modfreq)), phase, amp)*env), pan);

    Out.ar(
        bus,
        sig
    )
}).add;
);

(
SynthDef(\ringer, {
	arg freq=440,
		index=3,
		amp=0.2,
		pan=0,
		bus=~fb.index;

	var env = Env.perc(
			attackTime: 0.01,
			releaseTime: index*2,
			level: amp).kr(doneAction: 2);
	var sig = Pan2.ar((Ringz.ar(Impulse.ar(0), freq, index, amp)*env),pan);

    Out.ar(
        bus,
        sig
    )
}).add;
);

(
SynthDef(\karplu, {
	arg freq=440,
		index=3,
		coef=0.5,
		amp=0.2,
		pan=0,
		bus=~fb.index;

	var env = Env.perc(
			attackTime: 0.01,
			releaseTime: index*2,
			level: amp).kr(doneAction: 2);
	var sig = Pan2.ar((Pluck.ar(WhiteNoise.ar(0.1), Impulse.kr(0), freq.reciprocal, freq.reciprocal, index, coef)*env),pan);

    Out.ar(
        bus,
        sig
    )
}).add;
);

(
SynthDef(\slideSaw, {
	arg out,
		freq = 440,
		gate = 1,
		plfofreq = 6,
		mw = 0,
		ffreq = 2000,
		rq = 0.3,
		freqlag = 0.05,
		amp = 0.5,
		pan = 0,
		bus=~fb.index;

    var sig, plfo, fcurve;
    plfo = SinOsc.kr(plfofreq, mul:mw, add:1);
    freq = Lag.kr(freq, freqlag) * plfo;
    fcurve = EnvGen.kr(Env.adsr(0, 0.3, 0.1, 20), gate);
    fcurve = (fcurve - 1).madd(0.7, 1) * ffreq;
    sig = Mix.ar([Pulse.ar(freq, 0.9), Saw.ar(freq*1.007)]);
    sig = RLPF.ar(sig, fcurve, rq)
        * EnvGen.kr(Env.adsr(0.2, 0.2, 0.3, 0.3), gate, doneAction: 2)
        * amp;
	sig = Pan2.ar(sig, pan);
    Out.ar(bus, sig ! 2)
}).add;
);

//sequences
	//bank 1
(
~note.put(32,
	PatternProxy(Pseq(~b, inf)));
~a.put(16,
	Pdef(
	\drone,
	Pbind(
		\instrument, \trisin,
		\dur, Pwhite(0.05,0.5, inf),
		\stretch, (~t*4),
		\note, ~note[32],
		\gtranspose, -19,
		\atk, Pwhite(2,3, inf),
		\rel, Pwhite(5,10, inf),
		\amp, Pwhite(0.01,0.1, inf),
		\pan, Pwhite(-0.8,0.8, inf),
		\index, Pdefn(\0, Pseq([~idim[0].linlin(0,1,-24,24)], inf)),
		\modnum, Pseq([1, 2], inf),
		\modeno, Pseq([2, 1, 4], inf),
		\bus, ~fb.index
	);
	).quant_(~t*4)
)
);

(
~note.put(33,
	PatternProxy(Pseq(~b.rotate(1), inf)));
~a.put(17,
	Pdef(
	\sinepat,
	Pbind(
		\instrument, \sinsin,
		\dur, Pseq([Pseq([1/8],6), 1/4, Pseq([1/16],16)], inf),
		\stretch, (~t*4),
		\note, ~note[33],
		\gtranspose, -7,
		\atk, Pseq([0.005, 0.007, 0.01], inf),
		\rel, Pseq([0.3, 0.48, 1], inf),
		\amp, Pseq([0.05, 0.1, 0.1, 0.05], inf),
		\pan, Pseq([-0.8, 0.8], inf),
		\index, Pdefn(\1, Pseq([~idim[1].linlin(0,1,-24,24)], inf)),
		\modnum, Pseq([1, 2, 4], inf),
		\modeno, Pseq([2, 1], inf),
		\bus, ~fb.index
	);
	).quant_(~t*4)
)
);

(
~note.put(34,
	PatternProxy(Pseq(~b.rotate(2), inf)));
~a.put(18,
	Pdef(
	\sinepat2,
	Pbind(
		\instrument, \sinsin,
		\dur, Pseq([1/2], inf),
		\stretch, (~t*4),
		\note, ~note[34],
		\gtranspose, -12,
		\atk, Pseq([0.005, 0.007, 0.25], inf),
		\rel, Pseq([0.3, 1.48, 1], inf),
		\amp, Pseq([0.075, 0.1, 0.1, 0.095], inf),
		\pan, Pseq([0.8, -0.8], inf),
		\index, Pdefn(\2, Pseq([~idim[2].linlin(0,1,-24,24)], inf)),
		\modnum, Pseq([2, 4, 1], inf),
		\modeno, Pseq([2, 1], inf),
		\bus, ~fb.index
	);
	).quant_(~t*4)
)
);

(
~note.put(35,
	PatternProxy(Pseq(~b.rotate(3), inf)));
~a.put(19,
	Pdef(
	\phrase,
	Pbind(
		\instrument, \ringer,
		\dur, Pseq([1/4,1/8,1/8], inf),
		\stretch, (~t*4),
		\note, ~note[35],
		\gtranspose, -7,
		\atk, Pseq([0.005, 0.007, 0.01], inf),
		\rel, Pseq([0.3, 0.48, 1], inf),
		\amp, Pseq([0.1, 0.15, 0.2, 0.1], inf),
		\pan, Pseq([-0.8, 0.8], inf),
		\index, Pdefn(\3, Pseq([~idim[3].linlin(0,1,-24,24)], inf)),
		\bus, ~fb.index
	);
	).quant_(~t*4)
)
);

(
~note.put(36,
	PatternProxy(Pseq(~b.rotate(4), inf)));
~a.put(20,
	Pdef(
	\sixteener,
	Pbind(
		\instrument, \sinsin,
		\dur, Pseq([1/16], inf),
		\stretch, (~t*4),
		\note, ~note[36],
		\gtranspose, -7,
		\amp, Pseq([0.1, 0.2, 0.15, 0.1], inf),
		\pan, Pseq([-0.8, 0.8], inf),
		\index, Pdefn(\4, Pseq([~idim[4].linlin(0,1,-24,24)], inf)),
		\bus, ~fb.index
	);
	).quant_(~t*4)
)
);

(
~note.put(37,
	PatternProxy(Pseq(~b.rotate(5), inf)));
~a.put(21,
	Pdef(
	\trey,
	Pbind(
		\instrument, \karplu,
		\dur, Pseq([1/3], inf),
		\stretch, (~t*4),
		\note, ~note[37],
		\gtranspose, -7,
		\amp, Pseq([0.4, 0.6, 0.4, 0.5], inf),
		\pan, Pseq([-0.8, 0.8], inf),
		\index, Pdefn(\5, Pseq([~idim[5].linlin(0,1,-24,24)], inf)),
		\bus, ~fb.index
	);
	).quant_(~t*4)
)
);

(
~note.put(38,
	PatternProxy(Pseq(~b.rotate(6), inf)));
~a.put(22,
	Pdef(
	\fear,
	Pbind(
		\instrument, \karplu,
		\dur, Pseq([1/4], inf),
		\stretch, (~t*4),
		\note, ~note[38],
		\gtranspose, -7,
		\amp, Pseq([0.5, 0.4, 0.6, 0.4], inf),
		\pan, Pseq([-0.8, 0.8], inf),
		\index, Pdefn(\6, Pseq([~idim[6].linlin(0,1,-24,24)], inf)),
		\bus, ~fb.index
	);
	).quant_(~t*4)
)
);

(
~note.put(39,
	PatternProxy(Pseq(~b.rotate(7), inf)));
~a.put(23,
	Pdef(
	\slider,
	PmonoArtic(
		\slideSaw,
		\dur, Pseq([1/4, 1/4, 1/8, 1/16, 1/16, 1/8, 1/8], inf),
		\stretch, (~t*4),
		\note, ~note[39],
		\gtranspose, -7,
		\legato, 1,
		\freqlag, Pdefn(\7, Pseq([~idim[7].linlin(0,1,0,0.3)], inf)),
		\bus, ~fb.index
	);
	).quant_(~t*4)
)
);

	//bank 2
(
~note.put(64,
	PatternProxy(Pseq(~b.rotate(8), inf)));
~noted.put(64,
	~note[64].asStream);
~a.put(48,
	Task({
    var delta, starter, ender;
    loop {
        delta = ~t*4;
		starter = ~noted[64].next.linlin(0,32,0,1);
		ender = starter+0.01;
		~player[48].set(\t_trig,1,\start,starter,\end,ender,\loops,1,\amp,0.2,\bus,~fb.index);
        delta.yield;
    }
})
)
);

(
~note.put(65,
	PatternProxy(Pseq(~b.rotate(9), inf)));
~noted.put(65,
	~note[65].asStream);
~a.put(49,
	Task({
    var delta, scaledtime;
    loop {
        delta = ~t*4;
		scaledtime = ~noted[65].next.linlin(0,32,-2,2);
		~player[48].set(\rate, scaledtime);
        delta.yield;
    }
})
)
);

(
~note.put(66,
	PatternProxy(Pseq(~b.rotate(10), inf)));
~noted.put(66,
	~note[66].asStream);
~a.put(50,
	Task({
    var delta, panner;
    loop {
        delta = ~t*4;
		panner = ~noted[66].next.linlin(0,32,-1,1);
		~player[48].set(\pan, panner);
        delta.yield;
    }
})
)
);

(
~note.put(67,
	PatternProxy(Pseq(~b.rotate(11), inf)));
~noted.put(67,
	~note[67].asStream);
~a.put(51,
	Task({
    var delta, starter, ender;
    loop {
        delta = ~t*4;
		starter = ~noted[67].next.linlin(0,32,0,1);
		ender = starter+0.01;
		~player[49].set(\t_trig,1,\start,starter,\end,ender,\loops,1,\amp,0.2,\bus,~fb.index);
        delta.yield;
    }
})
)
);

(
~note.put(68,
	PatternProxy(Pseq(~b.rotate(12), inf)));
~noted.put(68,
	~note[68].asStream);
~a.put(52,
	Task({
    var delta, scaledtime;
    loop {
        delta = ~t*4;
		scaledtime = ~noted[68].next.linlin(0,32,-2,2);
		~player[49].set(\rate, scaledtime);
        delta.yield;
    }
})
)
);

(
~note.put(69,
	PatternProxy(Pseq(~b.rotate(13), inf)));
~noted.put(69,
	~note[69].asStream);
~a.put(53,
	Task({
    var delta, panner;
    loop {
        delta = ~t*4;
		panner = ~noted[69].next.linlin(0,32,-1,1);
		~player[49].set(\pan, panner);
        delta.yield;
    }
})
)
);

(
~note.put(70,
	PatternProxy(Pseq(~b.rotate(14), inf)));
~noted.put(70,
	~note[70].asStream);
~a.put(54,
	Task({
    var delta, starter, ender;
    loop {
        delta = ~t*4;
		starter = ~noted[70].next.linlin(0,32,0,1);
		ender = starter+0.06;
		~player[50].set(\t_trig,1,\start,starter,\end,ender,\loops,1,\amp,0.7,\bus,~fb.index);
        delta.yield;
    }
})
)
);

(
~note.put(71,
	PatternProxy(Pseq(~b.rotate(15), inf)));
~noted.put(71,
	~note[71].asStream);
~a.put(55,
	Task({
    var delta, scaledtime;
    loop {
        delta = ~t*4;
		scaledtime = ~noted[71].next.linlin(0,32,-2,2);
		~player[50].set(\rate, scaledtime);
        delta.yield;
    }
})
)
);

(
~note.put(72,
	PatternProxy(Pseq(~b.rotate(16), inf)));
~noted.put(72,
	~note[72].asStream);
~a.put(56,
	Task({
    var delta, panner;
    loop {
        delta = ~t*4;
		panner = ~noted[72].next.linlin(0,32,-1,1);
		~player[50].set(\pan, panner);
        delta.yield;
    }
})
)
);

	//bank 4
(
~a.put(112,
	Pdef(
	\rhythm,
	Pbind(
		\instrument, \bufPlay,
		\dur, Pseq([1/8], inf),
		\stretch, (~t*4),
		\buf, Pseq([d[\l][1], d[\m][3], d[\h][1]], inf),
		\rate, Pseq([0.5, 1, 0.25, 5, 0.75, 2, 4], inf),
		\amp, Pseq([0.095, Pexprand(0.05,0.075,7)], inf),
		\cutoff, Pdefn(\112, Pseq([~idim[112].linlin(0,1,0.1,10000)], inf)),
		\bus, ~fb.index
	);
	)
)
);

(
~a.put(113,
	Pdef(
	\kicksnare,
	Pbind(
		\instrument, \bufPlay,
		\dur, Pseq([1/2], inf),
		\stretch, (~t*4),
		\buf, Pseq([Prand(d[\zk], 1),Prand(d[\zs], 1)], inf),
		\rate, Pseq([1], inf),
		\bus, ~fb.index,
		\cutoff, Pdefn(\113, Pseq([~idim[113].linlin(0,1,0.1,10000)], inf)),
				);
			).quant_(~t*4)
		)
	);

(
~a.put(114,
	Pdef(
	\metals,
	Pbind(
		\instrument, \bufPlay,
		\dur, Pseq([1/16, 1/16, 7/8, 1/6, 1/6, 2/3, 1/16, 1/16, 7/8, 1/6, 1/6, 1/6, 1/6, 1/3], inf),
		\stretch, (~t*4),
		\buf, Prand(d[\zm], inf),
		\rate, Pseq([0.5, 1, 0.5, 4, 0.5, 2, 4], inf),
		\bus, ~fb.index,
		\cutoff, Pdefn(\114, Pseq([~idim[114].linlin(0,1,0.1,10000)], inf)),
				);
			).quant_(~t*4)
		)
	);

(
~a.put(115,
	Pdef(
	\percs,
	Pbind(
		\instrument, \bufPlay,
		\dur, Pseq([1/16], inf),
		\stretch, (~t*4),
		\buf, Prand(d[\zp], inf),
		\rate, Pseq([0.5, 1, 0.5, 4, 0.5, 2, 4], inf),
		\amp, Pseq([0.095, Pexprand(0.05,0.075,7)], inf),
		\bus, ~fb.index,
		\cutoff, Pdefn(\115, Pseq([~idim[115].linlin(0,1,0.1,10000)], inf)),
				);
			).quant_(~t*4)
		)
	);

(
~a.put(116,
	Pdef(
	\altmetal,
	Pbind(
		\instrument, \bufPlay,
		\dur, Pseq([1/16, 1/16, 1/16, 10/16, 1/16, 1/16, 1/16], inf),
		\stretch, (~t*4),
		\buf, Prand(d[\zp], inf),
		\rate, Pseq([0.5, 1, 0.5, 4, 0.5, 2, 4], inf),
		\bus, ~fb.index,
		\cutoff, Pdefn(\116, Pseq([~idim[116].linlin(0,1,0.1,10000)], inf)),
				);
			).quant_(~t*4)
		)
	);
});
)
