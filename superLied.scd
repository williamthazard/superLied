(
//server
Server.default = Server.local;
o = Server.default.options;
o.memSize_(2.pow(20));

//tempo
~tempo = 128; //put tempo here (in bpm)
~t = 60/~tempo; //converting tempo into seconds

//words, words, words
~b = " ".ascii%32;
~note = Array.fill(128, {0});
~noted = Array.fill(128, {0});
~player = Array.fill(128, {0});
~a = Array.fill(128, {0});

//initialize grid
~gridClass = 'MonomeGrid'.asClass;
~gridInit = false;
~step = Array.fill(128, {0});
Task({
	var delta;
	loop {
		delta = 0.5;
		if(
			~gridClass.notNil //check to see if monomeSC extension is present
		)
		{
			~gridDevices = ~gridClass.getConnectedDevices;
			if(
				~gridDevices.size > 0 //check to see if a physical grid device is present
			)
			{
				if(
					~gridInit == false
				)
				{
					var draw;
					~m = ~gridClass.new(0);
					~m.connect; //if there is a grid, connect to it
					~togs = Array.fill(4,{ arg k; 2*k+1});
					~push = Array.fill(4, {arg k; 2*k});
					for(0,4,{
						arg y;
						for(0,16,{
							arg x;
							~m.led(x,(2*y),4)
						})
					});
					~m.key({ arg x,y,z;
						var pos = x + (y*16);
						if(
							(z == 1) && (~togs.matchItem(y)),
							{
								if(
									~step[pos] == 1,
									{
										~step[pos] = 0;
										~a[pos].stop;
										AppClock.sched(0,{~comp[1].children[pos].value_(0)})
									},
									{
										~step[pos] = 1;
										~a[pos].play(quant:(~t*4));
										AppClock.sched(0,{~comp[1].children[pos].value_(1)})
									}
								);
								draw.value(x,y);
							}
						);
						if(
							~push.matchItem(y),
							{
								if(
									z == 1,
									{
										~m.led(x,y,z*15);
										if(
											pos > 15,
											{
												~note[pos].source = PatternProxy(Pseq(~b.rotate(pos), inf));
												~noted[pos] = ~note[pos].asStream
											},
											{
												~b = ~historyproxy[pos].ascii%32;
												AppClock.sched(0,{~entry_view.object = ~historyproxy[pos]});
												AppClock.sched(0.5,{~entry_view.object = ''})
											}
										);
									},
									{~m.led(x,y,4)}
								);
							}
						);
					});
					draw = {
						arg x, y;
						~m.led(x,y,~step[y*16+x] * 15);
					};
					~gridInit = true;
				}
			}
		};
		delta.yield;
}},
AppClock
).start;

//default values for knob-controlled parameters
~idim = Array.fill(128, {0.2});
~dimi = Array.fill(128, {0.5});

//wait
s.waitForBoot({

//initialize midi
	~mftInit = false;
	~mftParamsPassed = false;
	Task({
		var delta;
		loop {
			delta = 0.5;
			MIDIClient.list;
			if(
				MIDIClient.destinations.asString.contains("Midi Fighter Twister"),
				{
					if(
						~mftInit == false,
						{
							MIDIClient.init;
							MIDIIn.connectAll;
							MIDIdef.cc(\miid, {
								arg val, num, chan, src;
								//[chan, num, val].postln;
								if(
									chan == 0,
									for(0,63,{
										arg i;
										if(
											num == i,
											{
												Pdefn(
													i,
													Pseq([val.linlin(0,127,0,1)],inf)
												);
												AppClock.sched(0,{~comp[0].children[i].value_(val.linlin(0,127,0,1))});
												~idim[i] = val.linlin(0,127,0,1)
											}
										)
									})
								);
								if(
									chan == 4,
									for(0,63,{
										arg i;
										if(
											num == i,
											{
												Pdefn(
													i+64,
													Pseq([val.linlin(0,127,0,1)],inf)
												);
												AppClock.sched(0,{~comp[0].children[i+64].value_(val.linlin(0,127,0,1))});
												~dimi[i] = val.linlin(0,127,0,1)
											}
										)
									})
								);
							}, chan: [0,4]);
							~mft=MIDIOut(1);
							for(0,63,
								{
									arg i;
									~mft.control(0,i,~idim[i].linlin(0,1,0,127));
									~mft.control(4,i,~dimi[i].linlin(0,1,0,127));
								}
							);
							~mftInit = true;
						}
					)
				}
			);
			delta.yield;
	}},
	AppClock
	).start;

//gui
	//text entry interface & background XY scope
	Window.closeAll;
	w = Window("superLied",Window.availableBounds)
	.background_(Color.black)
	.fullScreen
	.onClose_({~topScope.stop; ~topScope.kill; ~bf.free; ~fb.free})
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
	.xZoom_(2)
	.yZoom_(2)
	.waveColors_([Color.grey,Color.white])
	.background_(Color.black)
	.start;

	~history_line_views = Array.fill(~num_history_lines,{
		StaticText(w, (w.view.bounds.width/2-20)@~line_height)
		.stringColor_(Color.new(1,1,1,0.5))
		.background_(Color.clear).font=~tnof
	});

	~bodyView = HLayout(~history_line_views,~topScope);

	~entry_view = TextField(w, w.view.bounds.width@~line_height)
	.background_(Color.new(1,1,1,0.5))
	.font=~tnof;

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
	Array.fill(64,{ arg i;
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
		)
	}
	);

	Array.fill(64,{ arg i;
		Knob(
			~comp[0],
			(k.bounds.width/16.9)@(k.bounds.width/16.9)
		).color_(
			[
				Color.new(1,1,1,0.25),
				Color.new(1,1,1,0.25),
				Color.new(0,0,0,0.25),
				Color.new(0,0,0,0.25)
			]
		)
	}
	);

	128.do{
		arg i;
		if(
			MIDIClient.destinations.asString.contains("Midi Fighter Twister"),
			{
				~comp[0].children[i].visible_(false)
			},
			{
				~comp[0].children[i].visible_(true)
			}
		)
	};

	Task({
		var delta;
		loop {
			delta = 0.5;
			MIDIClient.list;
			~listA = MIDIClient.destinations;
			delta.yield;
			MIDIClient.list;
			~listB = MIDIClient.destinations;
			(~listA != ~listB).if(
				128.do{
					arg i;
					if(
						MIDIClient.destinations.asString.contains("Midi Fighter Twister"),
						{
							AppClock.sched(0,{~comp[0].children[i].visible_(false)});
							if(
								~mftInit == true,
									if(
										~mftParamsPassed == false,
											if(
												i<64,
												{
													~mft.control(0,i,~idim[i].linlin(0,1,0,127))
												},
												{
													~mft.control(4,i-64,~dimi[i-64].linlin(0,1,0,127))
												}
											);
											~mftParamsPassed = true
									)
							)
						},
						{
							AppClock.sched(0,{~comp[0].children[i].visible_(true)});
							~mftParamsPassed = false
						}
					)
				};
				delta.yield;
			)
	}},
	AppClock
	).start;

	for(0,127,{
		arg i;
		~comp[0].children[i].action_(
			{
				arg obj;
				Pdefn(
					i,
					Pseq([obj.value],inf)
				);
				if(
					i<64,
					{
						~idim[i] = ~comp[0].children[i].value
					},
					{
						~dimi[i-64] = ~comp[0].children[i].value
					}
				)
			}
		);
		if(
			i<64,
			{
				~comp[0].children[i].value_(~idim[i])
			},
			{
				~comp[0].children[i].value_(~dimi[i-64])
			}
		)
	});

	//buttons
	4.do{(
		Array.fill(16,{
			Button(
				~comp[1],
				(k.bounds.width/16.9)@(k.bounds.width/16.9)
			).states_(
				[
					[
						" ",
						Color.new(1,1,1,0.5),
						Color.new(1,1,1,0.5)
					]
				]
			)
		});

		Array.fill(16,{
			Button(
				~comp[1],
				(k.bounds.width/16.9)@(k.bounds.width/16.9)
			).states_(
				[
					[
						" ",
						Color.new(1,1,1,0.25),
						Color.new(1,1,1,0.25)
					],
					[
						" ",
						Color.new(1,1,1,0.75),
						Color.new(1,1,1,0.75)
					]
				]
			).mouseDownAction_(
				{
					arg view;
					if(
						view.value == 3,
						{
							view.value = 1
						}
					)
				}
			)
		});
	)};

	if(
		~gridClass.notNil
	)
	{
		var gridDevices = ~gridClass.getConnectedDevices;
		128.do{
			arg i;
			if(
				~gridDevices.size > 0
			)
			{
				~comp[1].children[i].visible_(false)
			}
			{
				~comp[1].children[i].visible_(true)
			}
		}
	};

	if(
		~gridClass.notNil
	)
	{
	~gridClass.setAddCallback(
		{
			arg x,y;
			128.do{
				arg i;
				AppClock.sched(0,{~comp[1].children[i].visible_(false)})
			};
		}
	);
	~gridClass.setRemoveCallback(
		{
			128.do{
				arg i;
				AppClock.sched(0,{~comp[1].children[i].visible_(true)})
			}
		}
	);
	};

	16.do{
		arg i;
		~comp[1].children[i].mouseDownAction_(
			{
				~b = ~historyproxy[i].ascii%32;
				AppClock.sched(0,{~entry_view.object = ~historyproxy[i]});
				AppClock.sched(0.5,{~entry_view.object = ""})
			}
		)
	};

	16.do{
		arg i;
		~comp[1].children[i+16].mouseDownAction_(
			{
				arg view;
				if(
					view.value == 3,
					{
						view.value = 1
					}
				);
				if(
					view.value == 0,
					{
						~a[i+16].play(quant:(~t*4));
						~m.led(i,1,15)
					},
					{
						~a[i+16].stop;
						~m.led(i,1,0)
					}
				)
			}
		)
	};

	16.do{
		arg i;
		~comp[1].children[i+32].mouseDownAction_(
			{
				~note[i+32].source = PatternProxy(Pseq(~b.rotate(i+32), inf));
				~noted[i+32] = ~note[i+32].asStream
			}
		)
	};

	16.do{
		arg i;
		~comp[1].children[i+48].mouseDownAction_(
			{
				arg view;
				if(
					view.value == 3,
					{
						view.value = 1
					}
				);
				if(
					view.value == 0,
					{
						~a[i+48].play(quant:(~t*4));
						if(
							~gridClass.notNil
						)
						{
						~m.led(i,3,15)
						}
					},
					{
						~a[i+48].stop;
						if(
							~gridClass.notNil
						)
						{
						~m.led(i,3,0)
						}
					}
				)
			}
		)
	};

	16.do{
		arg i;
		~comp[1].children[i+64].mouseDownAction_(
			{
				~note[i+64].source = PatternProxy(Pseq(~b.rotate(i+64), inf));
				~noted[i+64] = ~note[i+64].asStream
			}
		)
	};

	16.do{
		arg i;
		~comp[1].children[i+80].mouseDownAction_(
			{
				arg view;
				if(
					view.value == 3,
					{
						view.value = 1
					}
				);
				if(
					view.value == 0,
					{
						~a[i+80].play(quant:(~t*4));
						if(
							~gridClass.notNil
						)
						{
						~m.led(i,5,15)
						}
					},
					{
						~a[i+80].stop;
						if(
							~gridClass.notNil
						)
						{
						~m.led(i,5,0)
						}
					}
				)
			}
		)
	};

	16.do{
		arg i;
		~comp[1].children[i+96].mouseDownAction_(
			{
				~note[i+96].source = PatternProxy(Pseq(~b.rotate(i+96), inf));
				~noted[i+96] = ~note[i+96].asStream
			}
		)
	};

	16.do{
		arg i;
		~comp[1].children[i+112].mouseDownAction_(
			{
				arg view;
				if(
					view.value == 3,
					{
						view.value = 1
					}
				);
				if(
					view.value == 0,
					{
						~a[i+112].play(quant:(~t*4));
						if(
							~gridClass.notNil
						)
						{
						~m.led(i,7,15)
						}
					},
					{
						~a[i+112].stop;
						if(
							~gridClass.notNil
						)
						{
						~m.led(i,7,0)
						}
					}
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
			cutoff2=1200,
			bus=~fb.index;
			var sig;
			sig = RLPF.ar(HPF.ar(PlayBuf.ar(1, buf, BufRateScale.ir(buf) * rate, doneAction:2),cutoff),cutoff2,0.25);
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
				arg out=0,
				bufnum=0,
				rate=1,
				start=0,
				end=1,
				t_trig=0,
				loops=1,
				amp=0.2,
				pan=0,
				rateSlew=0.1,
				panSlew=1,
				bus=~fb.index;
				var snd,
				snd2,
				pos,
				pos2,
				frames,
				duration,
				env,
				sig,
				startA,
				endA,
				startB,
				endB,
				crossfade,
				aOrB;
				aOrB=ToggleFF.kr(t_trig);
				startA=Latch.kr(start,aOrB);
				endA=Latch.kr(end,aOrB);
				startB=Latch.kr(start,1-aOrB);
				endB=Latch.kr(end,1-aOrB);
				crossfade=Lag.ar(K2A.ar(aOrB),0.1);
				rate=Lag.kr(rate,rateSlew)*BufRateScale.kr(bufnum);
				frames=BufFrames.kr(bufnum);
				duration=frames*(end-start)/rate.abs/s.sampleRate*loops;
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
			6.do({arg i=0;
				~player.put(48+i, Synth(\PlayBufPlayer, [\bufnum, d[\n][i]]));
			});
		}).play;
	);

//synths

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
			var modfreq=(modnum/modeno)*freq;
			var env=Env.perc(
				attackTime: atk,
				releaseTime: rel,
				level: amp).kr(doneAction: 2);
			var sig=Pan2.ar((SinOsc.ar(freq + (index*modfreq*SinOsc.ar(modfreq)), phase, amp)*env),pan);
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
			var modfreq=(modnum/modeno)*freq;
			var env=Env.perc(
				attackTime: atk,
				releaseTime: rel,
				level: amp).kr(doneAction: 2);
			var sig=Pan2.ar((LFTri.ar(freq + (index*modfreq*SinOsc.ar(modfreq)), phase, amp)*env), pan);
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
			var env=Env.perc(
				attackTime: 0.01,
				releaseTime: index.abs*2,
				level: amp).kr(doneAction: 2);
			var sig=Pan2.ar((Ringz.ar(Impulse.ar(0), freq, index, amp)*env),pan);
			Out.ar(
				bus,
				sig
			)
		}).add;
	);

	(
		SynthDef(\slideSaw, {
			arg out,
			freq=440,
			gate=1,
			plfofreq=6,
			mw=0,
			ffreq=2000,
			rq=0.3,
			freqlag=0.05,
			amp=0.5,
			pan=0,
			bus=~fb.index;
			var sig, plfo, fcurve;
			plfo=SinOsc.kr(plfofreq, mul:mw, add:1);
			freq=Lag.kr(freq, freqlag) * plfo;
			fcurve=EnvGen.kr(Env.adsr(0, 0.3, 0.1, 20), gate);
			fcurve=(fcurve - 1).madd(0.7, 1) * ffreq;
			sig=Mix.ar([Pulse.ar(freq, 0.9), Saw.ar(freq*1.007)]);
			sig=RLPF.ar(sig, fcurve, rq)
			* EnvGen.kr(Env.adsr(0.2, 0.2, 0.3, 0.3), gate, doneAction: 2)
			* amp;
			sig=Pan2.ar(sig, pan);
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
					\gtranspose, -12,
					\atk, Pwhite(2,3, inf),
					\rel, Pwhite(5,10, inf),
					\amp, Pdefn(0, Pseq([~idim[0]], inf)),
					\pan, Pwhite(-0.8,0.8, inf),
					\index, Pdefn(64, Pseq([~dimi[0].linlin(0,1,-24,24)], inf)),
					\modnum, Pseq([1, 2, 4, 1], inf),
					\modeno, Pseq([1, 2, 1], inf),
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
					\dur, Pseq([1/8], inf),
					\stretch, (~t*4),
					\note, ~note[33],
					\gtranspose, -12,
					\atk, Pseq([0.005, 0.007, 0.01], inf),
					\rel, Pseq([0.3, 0.48, 1], inf),
					\amp, Pdefn(1, Pseq([~idim[1]], inf)),
					\pan, Pseq([-0.8, 0.8], inf),
					\index, Pdefn(65, Pseq([~dimi[1].linlin(0,1,-24,24)], inf)),
					\modnum, Pseq([1, 2, 4], inf),
					\modeno, Pseq([1, 2], inf),
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
					\amp, Pdefn(2, Pseq([~idim[2]], inf)),
					\pan, Pseq([0.8, -0.8], inf),
					\index, Pdefn(66, Pseq([~dimi[2].linlin(0,1,-24,24)], inf)),
					\modnum, Pseq([2, 4, 1], inf),
					\modeno, Pseq([2, 1, 4, 1], inf),
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
					\gtranspose, -12,
					\atk, Pseq([0.005, 0.007, 0.01], inf),
					\rel, Pseq([0.5, 1.5, 0.7, 1], inf),
					\amp, Pdefn(3, Pseq([~idim[3]], inf)),
					\pan, Pseq([-0.8, 0.8], inf),
					\index, Pdefn(67, Pseq([~dimi[3].linlin(0,1,0,24)], inf)),
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
					\gtranspose, -12,
					\amp, Pdefn(4, Pseq([~idim[4]], inf)),
					\pan, Pseq([-0.8, 0.8], inf),
					\index, Pdefn(68, Pseq([~dimi[4].linlin(0,1,-24,24)], inf)),
					\modnum, Pseq([2, 4, 1], inf),
					\modeno, Pseq([2, 1, 4, 1], inf),
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
					\instrument, \trisin,
					\dur, Pseq([1/3], inf),
					\stretch, (~t*4),
					\note, ~note[37],
					\gtranspose, -12,
					\amp, Pdefn(5, Pseq([~idim[5]], inf)),
					\pan, Pseq([-0.8, 0.8], inf),
					\index, Pdefn(69, Pseq([~dimi[5].linlin(0,1,-24,24)], inf)),
					\modnum, Pseq([2, 4, 1], inf),
					\modeno, Pseq([2, 1, 4, 1], inf),
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
					\instrument, \trisin,
					\dur, Pseq([1/4], inf),
					\stretch, (~t*4),
					\note, ~note[38],
					\gtranspose, -12,
					\amp, Pdefn(6, Pseq([~idim[6]], inf)),
					\pan, Pseq([-0.8, 0.8], inf),
					\index, Pdefn(70, Pseq([~dimi[6].linlin(0,1,-24,24)], inf)),
					\modnum, Pseq([2, 4, 1, 2, 1], inf),
					\modeno, Pseq([2, 1, 4, 1], inf),
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
					\dur, Pseq([1/8], inf),
					\stretch, (~t*4),
					\note, ~note[39],
					\gtranspose, -12,
					\amp, Pdefn(7, Pseq([~idim[7]], inf)),
					\legato, 1,
					\freqlag, Pseq([0.1,0.3], inf),
					\ffreq, Pdefn(71, Pseq([~dimi[7].linlin(0,1,100,4000)], inf)),
					\bus, ~fb.index
				);
			).quant_(~t*4)
		)
	);

	(
		~note.put(40,
			PatternProxy(Pseq(~b.rotate(8), inf)));
		~a.put(24,
			Pdef(
				\sinepat3,
				Pbind(
					\instrument, \sinsin,
					\dur, Pseq([Pseq([1/8],6), 1/4, Pseq([1/16],16)], inf),
					\stretch, (~t*4),
					\note, ~note[40],
					\gtranspose, -12,
					\atk, Pseq([0.005, 0.007, 0.01], inf),
					\rel, Pseq([0.3, 0.48, 1], inf),
					\amp, Pdefn(8, Pseq([~idim[8]], inf)),
					\pan, Pseq([-0.8, 0.8], inf),
					\index, Pdefn(72, Pseq([~dimi[8].linlin(0,1,-24,24)], inf)),
					\modnum, Pseq([1, 2, 4], inf),
					\modeno, Pseq([1, 2, 1, 4], inf),
					\bus, ~fb.index
				);
			).quant_(~t*4)
		)
	);

	(
		~note.put(41,
			PatternProxy(Pseq(~b.rotate(9), inf)));
		~a.put(25,
			Pdef(
				\anotherdrone,
				Pbind(
					\instrument, \trisin,
					\dur, Pwhite(0.05,0.5, inf),
					\stretch, (~t*4),
					\note, ~note[41],
					\gtranspose, -12,
					\atk, Pwhite(2,3, inf),
					\rel, Pwhite(5,10, inf),
					\amp, Pdefn(9, Pseq([~idim[9]], inf)),
					\pan, Pwhite(-0.8,0.8, inf),
					\index, Pdefn(73, Pseq([~dimi[9].linlin(0,1,-24,24)], inf)),
					\modnum, Pseq([1, 2], inf),
					\modeno, Pseq([1, 2, 1, 4], inf),
					\bus, ~fb.index
				);
			).quant_(~t*4)
		)
	);

	(
		~note.put(42,
			PatternProxy(Pseq(~b.rotate(10), inf)));
		~a.put(26,
			Pdef(
				\sinepat4,
				Pbind(
					\instrument, \sinsin,
					\dur, Pseq([1/(~note[42]+1)*2],inf),
					\stretch, (~t*4),
					\note, ~note[42],
					\gtranspose, -12,
					\atk, Pseq([0.02, 0.07, 0.03, 0.05], inf),
					\rel, Pseq([1,3,2],inf),
					\amp, Pdefn(\10, Pseq([~idim[10]], inf)),
					\pan, Pseq([-0.8, 0.8], inf),
					\index, Pdefn(\26, Pseq([~dimi[10].linlin(0,1,-24,24)], inf)),
					\modnum, Pseq([1, 2], inf),
					\modeno, Pseq([1, 4, 2], inf),
					\bus, ~fb.index
				);
			).quant_(~t*4)
		)
	);

	(
		~note.put(43,
			PatternProxy(Pseq(~b.rotate(11), inf)));
		~a.put(27,
			Pdef(
				\sinepat5,
				Pbind(
					\instrument, \sinsin,
					\dur, Pseq([1/(~note[43]+1)*4],inf),
					\stretch, (~t*4),
					\note, ~note[43],
					\gtranspose, -12,
					\atk, Pseq([0.005, 0.007, 0.01], inf),
					\rel, Pseq([0.3, 0.48, 1], inf),
					\amp, Pdefn(\11, Pseq([~idim[11]], inf)),
					\pan, Pseq([-0.8, 0.8], inf),
					\index, Pdefn(\27, Pseq([~dimi[11].linlin(0,1,-24,24)], inf)),
					\modnum, Pseq([1, 2, 4], inf),
					\modeno, Pseq([2, 1, 4, 1], inf),
					\bus, ~fb.index
				);
			).quant_(~t*4)
		)
	);

	(
		~note.put(44,
			PatternProxy(Pseq(~b.rotate(12), inf)));
		~a.put(28,
			Pdef(
				\sinepat6,
				Pbind(
					\instrument, \trisin,
					\dur, Pseq([1/(~note[44]+1)*4],inf),
					\stretch, (~t*4),
					\note, ~note[44],
					\gtranspose, -12,
					\atk, Pseq([0.005, 0.007, 0.01], inf),
					\rel, Pseq([0.3, 0.48, 1], inf),
					\amp, Pdefn(\12, Pseq([~idim[12]], inf)),
					\pan, Pseq([-0.8, 0.8], inf),
					\index, Pdefn(\28, Pseq([~dimi[12].linlin(0,1,-24,24)], inf)),
					\modnum, Pseq([1, 2, 4], inf),
					\modeno, Pseq([2, 1, 2, 4], inf),
					\bus, ~fb.index
				);
			).quant_(~t*4)
		)
	);

	(
		~note.put(45,
			PatternProxy(Pseq(~b.rotate(13), inf)));
		~a.put(29,
			Pdef(
				\phrase2,
				Pbind(
					\instrument, \ringer,
					\dur, Pseq([1/(~note[45]+1)],inf),
					\stretch, (~t*4),
					\note, ~note[45],
					\gtranspose, -12,
					\atk, Pseq([0.005, 0.007, 0.01], inf),
					\rel, Pseq([0.007, 0.001, 0.05, 0.01], inf),
					\amp, Pdefn(\13, Pseq([~idim[13]], inf)),
					\pan, Pseq([-0.8, 0.8], inf),
					\index, Pdefn(\29, Pseq([~dimi[13].linlin(0,1,-24,24)], inf)),
					\bus, ~fb.index
				);
			).quant_(~t*4)
		)
	);

	(
		~note.put(46,
			PatternProxy(Pseq(~b.rotate(14), inf)));
		~a.put(30,
			Pdef(
				\trey2,
				Pbind(
					\instrument, \trisin,
					\dur, Pseq([1/(~note[46]+1)],inf),
					\stretch, (~t*4),
					\note, ~note[46],
					\gtranspose, -12,
					\amp, Pdefn(\14, Pseq([~idim[14]], inf)),
					\pan, Pseq([-0.8, 0.8], inf),
					\index, Pdefn(\30, Pseq([~dimi[14].linlin(0,1,-24,24)], inf)),
					\coef, Pseq([0.5],inf),
					\bus, ~fb.index
				);
			).quant_(~t*4)
		)
	);

	(
		~note.put(47,
			PatternProxy(Pseq(~b.rotate(15), inf)));
		~a.put(31,
			Pdef(
				\slider2,
				PmonoArtic(
					\slideSaw,
					\dur, Pseq([(1/(~note[47]+1))*8],inf),
					\stretch, (~t*4),
					\note, ~note[47],
					\gtranspose, -19,
					\amp, Pdefn(\15, Pseq([~idim[15]], inf)),
					\legato, 1,
					\freqlag, Pseq([0.1],inf),
					\ffreq, Pdefn(\31, Pseq([~dimi[15].linlin(0,1,100,4000)], inf)),
					\bus, ~fb.index
				);
			).quant_(~t*4)
		)
	);

	//bank 2
	//sample 1
	(
		~note.put(64,
			PatternProxy(Pseq(~b.rotate(16), inf)));
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
			PatternProxy(Pseq(~b.rotate(17), inf)));
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
			PatternProxy(Pseq(~b.rotate(18), inf)));
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

	//sample 2
	(
		~note.put(67,
			PatternProxy(Pseq(~b.rotate(19), inf)));
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
			PatternProxy(Pseq(~b.rotate(20), inf)));
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
			PatternProxy(Pseq(~b.rotate(21), inf)));
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

	//sample 3
	(
		~note.put(70,
			PatternProxy(Pseq(~b.rotate(22), inf)));
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
			PatternProxy(Pseq(~b.rotate(23), inf)));
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

	//sample 4
	(
		~note.put(72,
			PatternProxy(Pseq(~b.rotate(24), inf)));
		~noted.put(72,
			~note[72].asStream);
		~a.put(56,
			Task({
				var delta, starter, ender;
				loop {
					delta = ~t*4;
					starter = ~noted[72].next.linlin(0,32,0,1);
					ender = starter+0.01;
					~player[51].set(\t_trig,1,\start,starter,\end,ender,\loops,1,\amp,0.2,\bus,~fb.index);
					delta.yield;
				}
			})
		)
	);

	(
		~note.put(73,
			PatternProxy(Pseq(~b.rotate(25), inf)));
		~noted.put(73,
			~note[73].asStream);
		~a.put(57,
			Task({
				var delta, scaledtime;
				loop {
					delta = ~t*4;
					scaledtime = ~noted[73].next.linlin(0,32,-2,2);
					~player[51].set(\rate, scaledtime);
					delta.yield;
				}
			})
		)
	);

	(
		~note.put(74,
			PatternProxy(Pseq(~b.rotate(26), inf)));
		~noted.put(74,
			~note[74].asStream);
		~a.put(58,
			Task({
				var delta, panner;
				loop {
					delta = ~t*4;
					panner = ~noted[74].next.linlin(0,32,-1,1);
					~player[51].set(\pan, panner);
					delta.yield;
				}
			})
		)
	);

	//sample 5
	(
		~note.put(75,
			PatternProxy(Pseq(~b.rotate(27), inf)));
		~noted.put(75,
			~note[75].asStream);
		~a.put(59,
			Task({
				var delta, starter, ender;
				loop {
					delta = ~t*4;
					starter = ~noted[75].next.linlin(0,32,0,1);
					ender = starter+0.01;
					~player[52].set(\t_trig,1,\start,starter,\end,ender,\loops,1,\amp,0.2,\bus,~fb.index);
					delta.yield;
				}
			})
		)
	);

	(
		~note.put(76,
			PatternProxy(Pseq(~b.rotate(28), inf)));
		~noted.put(76,
			~note[76].asStream);
		~a.put(60,
			Task({
				var delta, scaledtime;
				loop {
					delta = ~t*4;
					scaledtime = ~noted[76].next.linlin(0,32,-2,2);
					~player[52].set(\rate, scaledtime);
					delta.yield;
				}
			})
		)
	);

	(
		~note.put(77,
			PatternProxy(Pseq(~b.rotate(29), inf)));
		~noted.put(77,
			~note[77].asStream);
		~a.put(61,
			Task({
				var delta, panner;
				loop {
					delta = ~t*4;
					panner = ~noted[77].next.linlin(0,32,-1,1);
					~player[52].set(\pan, panner);
					delta.yield;
				}
			})
		)
	);

	//sample 6
	(
		~note.put(78,
			PatternProxy(Pseq(~b.rotate(30), inf)));
		~noted.put(78,
			~note[78].asStream);
		~a.put(62,
			Task({
				var delta, starter, ender;
				loop {
					delta = ~t*4;
					starter = ~noted[78].next.linlin(0,32,0,1);
					ender = starter+0.06;
					~player[53].set(\t_trig,1,\start,starter,\end,ender,\loops,1,\amp,0.7,\bus,~fb.index);
					delta.yield;
				}
			})
		)
	);

	(
		~note.put(79,
			PatternProxy(Pseq(~b.rotate(31), inf)));
		~noted.put(79,
			~note[79].asStream);
		~a.put(63,
			Task({
				var delta, scaledtime;
				loop {
					delta = ~t*4;
					scaledtime = ~noted[79].next.linlin(0,32,-2,2);
					~player[53].set(\rate, scaledtime);
					delta.yield;
				}
			})
		)
	);

	//bank 3
	(
		~note.put(96,
			PatternProxy(Pseq(~b.rotate(32), inf)));
		~a.put(80,
			Pdef(
				\Adrone,
				Pbind(
					\instrument, \trisin,
					\dur, Pwhite(0.05,0.5, inf),
					\stretch, (~t*4),
					\note, ~note[96],
					\gtranspose, -12,
					\atk, Pwhite(2,3, inf),
					\rel, Pwhite(5,10, inf),
					\amp, Pwhite(0.01,0.1, inf),
					\pan, Pwhite(-0.8,0.8, inf),
					\index, Pdefn(\64, Pseq([~idim[64].linlin(0,1,-24,24)], inf)),
					\modnum, Pseq([1, 2], inf),
					\modeno, Pdefn(\80, Pseq([~idim[80].linlin(0,1,1,4)], inf)),
					\bus, ~fb.index
				);
			).quant_(~t*4)
		)
	);

	(
		~note.put(97,
			PatternProxy(Pseq(~b.rotate(33), inf)));
		~a.put(81,
			Pdef(
				\Asinepat,
				Pbind(
					\instrument, \sinsin,
					\dur, Pseq([1/8], inf),
					\stretch, (~t*4),
					\note, ~note[97],
					\gtranspose, -12,
					\atk, Pseq([0.005, 0.007, 0.01], inf),
					\rel, Pseq([0.3, 0.48, 1], inf),
					\amp, Pseq([0.05, 0.1, 0.1, 0.05], inf),
					\pan, Pseq([-0.8, 0.8], inf),
					\index, Pdefn(\65, Pseq([~idim[65].linlin(0,1,-24,24)], inf)),
					\modnum, Pseq([1, 2, 4], inf),
					\modeno, Pdefn(\81, Pseq([~idim[81].linlin(0,1,1,4)], inf)),
					\bus, ~fb.index
				);
			).quant_(~t*4)
		)
	);

	(
		~note.put(98,
			PatternProxy(Pseq(~b.rotate(34), inf)));
		~a.put(82,
			Pdef(
				\Asinepat2,
				Pbind(
					\instrument, \sinsin,
					\dur, Pseq([1/2], inf),
					\stretch, (~t*4),
					\note, ~note[98],
					\gtranspose, -12,
					\atk, Pseq([0.005, 0.007, 0.25], inf),
					\rel, Pseq([0.3, 1.48, 1], inf),
					\amp, Pseq([0.075, 0.1, 0.1, 0.095], inf),
					\pan, Pseq([0.8, -0.8], inf),
					\index, Pdefn(\66, Pseq([~idim[66].linlin(0,1,-24,24)], inf)),
					\modnum, Pseq([2, 4, 1], inf),
					\modeno, Pdefn(\82, Pseq([~idim[82].linlin(0,1,1,4)], inf)),
					\bus, ~fb.index
				);
			).quant_(~t*4)
		)
	);

	(
		~note.put(99,
			PatternProxy(Pseq(~b.rotate(35), inf)));
		~a.put(83,
			Pdef(
				\Aphrase,
				Pbind(
					\instrument, \ringer,
					\dur, Pseq([1/4,1/8,1/8], inf),
					\stretch, (~t*4),
					\note, ~note[99],
					\gtranspose, -12,
					\atk, Pseq([0.005, 0.007, 0.01], inf),
					\rel, Pdefn(\67, Pseq([~idim[67].linlin(0,1,0.001,3)], inf)),
					\amp, Pseq([0.1, 0.15, 0.2, 0.1], inf),
					\pan, Pseq([-0.8, 0.8], inf),
					\index, Pdefn(\83, Pseq([~idim[83].linlin(0,1,-24,24)], inf)),
					\bus, ~fb.index
				);
			).quant_(~t*4)
		)
	);

	(
		~note.put(100,
			PatternProxy(Pseq(~b.rotate(36), inf)));
		~a.put(84,
			Pdef(
				\Asixteener,
				Pbind(
					\instrument, \sinsin,
					\dur, Pseq([1/16], inf),
					\stretch, (~t*4),
					\note, ~note[100],
					\gtranspose, -12,
					\amp, Pseq([0.1, 0.2, 0.15, 0.1], inf),
					\pan, Pseq([-0.8, 0.8], inf),
					\index, Pdefn(\68, Pseq([~idim[68].linlin(0,1,-24,24)], inf)),
					\modnum, Pseq([2, 4, 1], inf),
					\modeno, Pdefn(\84, Pseq([~idim[84].linlin(0,1,1,4)], inf)),
					\bus, ~fb.index
				);
			).quant_(~t*4)
		)
	);

	(
		~note.put(101,
			PatternProxy(Pseq(~b.rotate(37), inf)));
		~a.put(85,
			Pdef(
				\Atrey,
				Pbind(
					\instrument, \trisin,
					\dur, Pseq([1/3], inf),
					\stretch, (~t*4),
					\note, ~note[101],
					\gtranspose, -12,
					\amp, Pseq([0.4, 0.6, 0.4, 0.5], inf),
					\pan, Pseq([-0.8, 0.8], inf),
					\index, Pdefn(\69, Pseq([~idim[69].linlin(0,1,-24,24)], inf)),
					\coef, Pdefn(\85, Pseq([~idim[85]], inf)),
					\bus, ~fb.index
				);
			).quant_(~t*4)
		)
	);

	(
		~note.put(102,
			PatternProxy(Pseq(~b.rotate(38), inf)));
		~a.put(86,
			Pdef(
				\Afear,
				Pbind(
					\instrument, \trisin,
					\dur, Pseq([1/4], inf),
					\stretch, (~t*4),
					\note, ~note[102],
					\gtranspose, -12,
					\amp, Pseq([0.5, 0.4, 0.6, 0.4], inf),
					\pan, Pseq([-0.8, 0.8], inf),
					\index, Pdefn(\70, Pseq([~idim[70].linlin(0,1,-24,24)], inf)),
					\coef, Pdefn(\86, Pseq([~idim[86]], inf)),
					\bus, ~fb.index
				);
			).quant_(~t*4)
		)
	);

	(
		~note.put(103,
			PatternProxy(Pseq(~b.rotate(39), inf)));
		~a.put(87,
			Pdef(
				\Aslider,
				PmonoArtic(
					\slideSaw,
					\dur, Pseq([1/8], inf),
					\stretch, (~t*4),
					\note, ~note[103],
					\gtranspose, -12,
					\legato, 1,
					\freqlag, Pdefn(\71, Pseq([~idim[71].linlin(0,1,0,0.3)], inf)),
					\ffreq, Pdefn(\87, Pseq([~idim[87].linlin(0,1,100,4000)], inf)),
					\bus, ~fb.index
				);
			).quant_(~t*4)
		)
	);

	(
		~note.put(104,
			PatternProxy(Pseq(~b.rotate(40), inf)));
		~a.put(88,
			Pdef(
				\Asinepat3,
				Pbind(
					\instrument, \sinsin,
					\dur, Pseq([Pseq([1/8],6), 1/4, Pseq([1/16],16)], inf),
					\stretch, (~t*4),
					\note, ~note[104],
					\gtranspose, -12,
					\atk, Pseq([0.005, 0.007, 0.01], inf),
					\rel, Pseq([0.3, 0.48, 1], inf),
					\amp, Pseq([0.05, 0.1, 0.1, 0.05], inf),
					\pan, Pseq([-0.8, 0.8], inf),
					\index, Pdefn(\72, Pseq([~idim[72].linlin(0,1,-24,24)], inf)),
					\modnum, Pseq([1, 2, 4], inf),
					\modeno, Pdefn(\88, Pseq([~idim[88].linlin(0,1,1,4)], inf)),
					\bus, ~fb.index
				);
			).quant_(~t*4)
		)
	);

	(
		~note.put(105,
			PatternProxy(Pseq(~b.rotate(41), inf)));
		~a.put(89,
			Pdef(
				\Aanotherdrone,
				Pbind(
					\instrument, \trisin,
					\dur, Pwhite(0.05,0.5, inf),
					\stretch, (~t*4),
					\note, ~note[105],
					\gtranspose, -12,
					\atk, Pwhite(2,3, inf),
					\rel, Pwhite(5,10, inf),
					\amp, Pwhite(0.01,0.1, inf),
					\pan, Pwhite(-0.8,0.8, inf),
					\index, Pdefn(\73, Pseq([~idim[73].linlin(0,1,-24,24)], inf)),
					\modnum, Pseq([1, 2], inf),
					\modeno, Pdefn(\89, Pseq([~idim[89].linlin(0,1,1,4)], inf)),
					\bus, ~fb.index
				);
			).quant_(~t*4)
		)
	);

	(
		~note.put(106,
			PatternProxy(Pseq(~b.rotate(42), inf)));
		~a.put(90,
			Pdef(
				\Asinepat4,
				Pbind(
					\instrument, \sinsin,
					\dur, Pseq([1/(~note[106]+1)],inf),
					\stretch, (~t*4),
					\note, ~note[106],
					\gtranspose, -12,
					\atk, Pdefn(\74, Pseq([~idim[74].linlin(0,1,0.01,10)], inf)),
					\rel, Pdefn(\90, Pseq([~idim[90].linlin(0,1,0.01,10)], inf)),
					\amp, Pseq([0.02, 0.07, 0.03, 0.05], inf),
					\pan, Pseq([-0.8, 0.8], inf),
					\bus, ~fb.index
				);
			).quant_(~t*4)
		)
	);

	(
		~note.put(107,
			PatternProxy(Pseq(~b.rotate(43), inf)));
		~a.put(91,
			Pdef(
				\Asinepat5,
				Pbind(
					\instrument, \sinsin,
					\dur, Pseq([1/(~note[107]+1)],inf),
					\stretch, (~t*4),
					\note, ~note[107],
					\gtranspose, -12,
					\atk, Pseq([0.005, 0.007, 0.01], inf),
					\rel, Pseq([0.3, 0.48, 1], inf),
					\amp, Pseq([0.05, 0.1, 0.1, 0.05], inf),
					\pan, Pseq([-0.8, 0.8], inf),
					\index, Pdefn(\75, Pseq([~idim[75].linlin(0,1,-24,24)], inf)),
					\modnum, Pseq([1, 2, 4], inf),
					\modeno, Pdefn(\91, Pseq([~idim[91].linlin(0,1,1,4)], inf)),
					\bus, ~fb.index
				);
			).quant_(~t*4)
		)
	);

	(
		~note.put(108,
			PatternProxy(Pseq(~b.rotate(44), inf)));
		~a.put(92,
			Pdef(
				\Asinepat6,
				Pbind(
					\instrument, \trisin,
					\dur, Pseq([1/(~note[108]+1)],inf),
					\stretch, (~t*4),
					\note, ~note[108],
					\gtranspose, -12,
					\atk, Pseq([0.005, 0.007, 0.01], inf),
					\rel, Pseq([0.3, 0.48, 1], inf),
					\amp, Pseq([0.05, 0.1, 0.1, 0.05], inf),
					\pan, Pseq([-0.8, 0.8], inf),
					\index, Pdefn(\76, Pseq([~idim[76].linlin(0,1,-24,24)], inf)),
					\modnum, Pseq([1, 2, 4], inf),
					\modeno, Pdefn(\92, Pseq([~idim[92].linlin(0,1,1,4)], inf)),
					\bus, ~fb.index
				);
			).quant_(~t*4)
		)
	);

	(
		~note.put(109,
			PatternProxy(Pseq(~b.rotate(45), inf)));
		~a.put(93,
			Pdef(
				\Aphrase2,
				Pbind(
					\instrument, \ringer,
					\dur, Pseq([1/(~note[109]+1)],inf),
					\stretch, (~t*4),
					\note, ~note[109],
					\gtranspose, -12,
					\atk, Pseq([0.005, 0.007, 0.01], inf),
					\rel, Pdefn(\93, Pseq([~idim[93].linlin(0,1,1,4)], inf)),
					\amp, Pseq([0.1, 0.15, 0.2, 0.1], inf),
					\pan, Pseq([-0.8, 0.8], inf),
					\index, Pdefn(\77, Pseq([~idim[77].linlin(0,1,-24,24)], inf)),
					\bus, ~fb.index
				);
			).quant_(~t*4)
		)
	);

	(
		~note.put(110,
			PatternProxy(Pseq(~b.rotate(46), inf)));
		~a.put(94,
			Pdef(
				\Atrey2,
				Pbind(
					\instrument, \trisin,
					\dur, Pseq([1/(~note[110]+1)],inf),
					\stretch, (~t*4),
					\note, ~note[110],
					\gtranspose, -12,
					\amp, Pseq([0.4, 0.6, 0.4, 0.5], inf),
					\pan, Pseq([-0.8, 0.8], inf),
					\index, Pdefn(\78, Pseq([~idim[78].linlin(0,1,-24,24)], inf)),
					\coef, Pdefn(\94, Pseq([~idim[94]], inf)),
					\bus, ~fb.index
				);
			).quant_(~t*4)
		)
	);

	(
		~note.put(111,
			PatternProxy(Pseq(~b.rotate(47), inf)));
		~a.put(95,
			Pdef(
				\Aslider2,
				PmonoArtic(
					\slideSaw,
					\dur, Pseq([(1/(~note[111]+1))*8],inf),
					\stretch, (~t*4),
					\note, ~note[111],
					\gtranspose, -12,
					\legato, 1,
					\freqlag, Pdefn(\79, Pseq([~idim[79].linlin(0,1,0,0.3)], inf)),
					\ffreq, Pdefn(\95, Pseq([~idim[95].linlin(0,1,100,4000)], inf)),
					\bus, ~fb.index
				);
			).quant_(~t*4)
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
					\cutoff2, Pdefn(\96, Pseq([~idim[96].linlin(0,1,0.1,10000)], inf)),
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
					\cutoff2, Pdefn(\97, Pseq([~idim[97].linlin(0,1,0.1,10000)], inf)),
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
					\cutoff2, Pdefn(\98, Pseq([~idim[98].linlin(0,1,0.1,10000)], inf)),
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
					\cutoff2, Pdefn(\99, Pseq([~idim[99].linlin(0,1,0.1,10000)], inf)),
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
					\cutoff2, Pdefn(\100, Pseq([~idim[100].linlin(0,1,0.1,10000)], inf)),
					\cutoff, Pdefn(\116, Pseq([~idim[116].linlin(0,1,0.1,10000)], inf)),
				);
			).quant_(~t*4)
		)
	);

	(
		~a.put(117,
			Pdef(
				\rhythm1,
				Pbind(
					\instrument, \bufPlay,
					\dur, Pseq([1/8], inf),
					\stretch, (~t*4),
					\buf, Pseq([d[\l][1], d[\m][3], d[\h][1]], inf),
					\rate, Pseq([0.5, 1, 0.25, 5, 0.75, 2, 4], inf),
					\amp, Pseq([0.095, Pexprand(0.05,0.075,7)], inf),
					\cutoff2, Pdefn(\101, Pseq([~idim[101].linlin(0,1,0.1,10000)], inf)),
					\cutoff, Pdefn(\117, Pseq([~idim[117].linlin(0,1,0.1,10000)], inf)),
					\bus, ~fb.index
				);
			)
		)
	);

	(
		~a.put(118,
			Pdef(
				\kicksnare1,
				Pbind(
					\instrument, \bufPlay,
					\dur, Pseq([1/2], inf),
					\stretch, (~t*4),
					\buf, Pseq([Prand(d[\zk], 1),Prand(d[\zs], 1)], inf),
					\rate, Pseq([1], inf),
					\bus, ~fb.index,
					\cutoff2, Pdefn(\102, Pseq([~idim[102].linlin(0,1,0.1,10000)], inf)),
					\cutoff, Pdefn(\118, Pseq([~idim[118].linlin(0,1,0.1,10000)], inf)),
				);
			).quant_(~t*4)
		)
	);

	(
		~a.put(119,
			Pdef(
				\metals1,
				Pbind(
					\instrument, \bufPlay,
					\dur, Pseq([1/16, 1/16, 7/8, 1/6, 1/6, 2/3, 1/16, 1/16, 7/8, 1/6, 1/6, 1/6, 1/6, 1/3], inf),
					\stretch, (~t*4),
					\buf, Prand(d[\zm], inf),
					\rate, Pseq([0.5, 1, 0.5, 4, 0.5, 2, 4], inf),
					\bus, ~fb.index,
					\cutoff2, Pdefn(\103, Pseq([~idim[103].linlin(0,1,0.1,10000)], inf)),
					\cutoff, Pdefn(\119, Pseq([~idim[119].linlin(0,1,0.1,10000)], inf)),
				);
			).quant_(~t*4)
		)
	);

	(
		~a.put(120,
			Pdef(
				\percs1,
				Pbind(
					\instrument, \bufPlay,
					\dur, Pseq([1/16], inf),
					\stretch, (~t*4),
					\buf, Prand(d[\zp], inf),
					\rate, Pseq([0.5, 1, 0.5, 4, 0.5, 2, 4], inf),
					\amp, Pseq([0.095, Pexprand(0.05,0.075,7)], inf),
					\bus, ~fb.index,
					\cutoff2, Pdefn(\104, Pseq([~idim[104].linlin(0,1,0.1,10000)], inf)),
					\cutoff, Pdefn(\120, Pseq([~idim[120].linlin(0,1,0.1,10000)], inf)),
				);
			).quant_(~t*4)
		)
	);

	(
		~a.put(121,
			Pdef(
				\altmetal1,
				Pbind(
					\instrument, \bufPlay,
					\dur, Pseq([1/16, 1/16, 1/16, 10/16, 1/16, 1/16, 1/16], inf),
					\stretch, (~t*4),
					\buf, Prand(d[\zp], inf),
					\rate, Pseq([0.5, 1, 0.5, 4, 0.5, 2, 4], inf),
					\bus, ~fb.index,
					\cutoff2, Pdefn(\105, Pseq([~idim[105].linlin(0,1,0.1,10000)], inf)),
					\cutoff, Pdefn(\121, Pseq([~idim[121].linlin(0,1,0.1,10000)], inf)),
				);
			).quant_(~t*4)
		)
	);

	(
		~a.put(122,
			Pdef(
				\rhythm2,
				Pbind(
					\instrument, \bufPlay,
					\dur, Pseq([1/8], inf),
					\stretch, (~t*4),
					\buf, Pseq([d[\l][1], d[\m][3], d[\h][1]], inf),
					\rate, Pseq([0.5, 1, 0.25, 5, 0.75, 2, 4], inf),
					\amp, Pseq([0.095, Pexprand(0.05,0.075,7)], inf),
					\cutoff2, Pdefn(\106, Pseq([~idim[106].linlin(0,1,0.1,10000)], inf)),
					\cutoff, Pdefn(\122, Pseq([~idim[122].linlin(0,1,0.1,10000)], inf)),
					\bus, ~fb.index
				);
			)
		)
	);

	(
		~a.put(123,
			Pdef(
				\kicksnare2,
				Pbind(
					\instrument, \bufPlay,
					\dur, Pseq([1/2], inf),
					\stretch, (~t*4),
					\buf, Pseq([Prand(d[\zk], 1),Prand(d[\zs], 1)], inf),
					\rate, Pseq([1], inf),
					\bus, ~fb.index,
					\cutoff2, Pdefn(\107, Pseq([~idim[107].linlin(0,1,0.1,10000)], inf)),
					\cutoff, Pdefn(\123, Pseq([~idim[123].linlin(0,1,0.1,10000)], inf)),
				);
			).quant_(~t*4)
		)
	);

	(
		~a.put(124,
			Pdef(
				\metals2,
				Pbind(
					\instrument, \bufPlay,
					\dur, Pseq([1/16, 1/16, 7/8, 1/6, 1/6, 2/3, 1/16, 1/16, 7/8, 1/6, 1/6, 1/6, 1/6, 1/3], inf),
					\stretch, (~t*4),
					\buf, Prand(d[\zm], inf),
					\rate, Pseq([0.5, 1, 0.5, 4, 0.5, 2, 4], inf),
					\bus, ~fb.index,
					\cutoff2, Pdefn(\108, Pseq([~idim[108].linlin(0,1,0.1,10000)], inf)),
					\cutoff, Pdefn(\124, Pseq([~idim[124].linlin(0,1,0.1,10000)], inf)),
				);
			).quant_(~t*4)
		)
	);

	(
		~a.put(125,
			Pdef(
				\percs2,
				Pbind(
					\instrument, \bufPlay,
					\dur, Pseq([1/16], inf),
					\stretch, (~t*4),
					\buf, Prand(d[\zp], inf),
					\rate, Pseq([0.5, 1, 0.5, 4, 0.5, 2, 4], inf),
					\amp, Pseq([0.095, Pexprand(0.05,0.075,7)], inf),
					\bus, ~fb.index,
					\cutoff2, Pdefn(\109, Pseq([~idim[109].linlin(0,1,0.1,10000)], inf)),
					\cutoff, Pdefn(\125, Pseq([~idim[125].linlin(0,1,0.1,10000)], inf)),
				);
			).quant_(~t*4)
		)
	);

	(
		~a.put(126,
			Pdef(
				\altmetal2,
				Pbind(
					\instrument, \bufPlay,
					\dur, Pseq([1/16, 1/16, 1/16, 10/16, 1/16, 1/16, 1/16], inf),
					\stretch, (~t*4),
					\buf, Prand(d[\zp], inf),
					\rate, Pseq([0.5, 1, 0.5, 4, 0.5, 2, 4], inf),
					\bus, ~fb.index,
					\cutoff2, Pdefn(\110, Pseq([~idim[110].linlin(0,1,0.1,10000)], inf)),
					\cutoff, Pdefn(\126, Pseq([~idim[126].linlin(0,1,0.1,10000)], inf)),
				);
			).quant_(~t*4)
		)
	);

	(
		~a.put(127,
			Pdef(
				\altmetal3,
				Pbind(
					\instrument, \bufPlay,
					\dur, Pseq([1/16, 1/16, 1/16, 10/16, 1/16, 1/16, 1/16], inf),
					\stretch, (~t*4),
					\buf, Prand(d[\zp], inf),
					\rate, Pseq([0.5, 1, 0.5, 4, 0.5, 2, 4], inf),
					\bus, ~fb.index,
					\cutoff2, Pdefn(\111, Pseq([~idim[111].linlin(0,1,0.1,10000)], inf)),
					\cutoff, Pdefn(\127, Pseq([~idim[127].linlin(0,1,0.1,10000)], inf)),
				);
			).quant_(~t*4)
		)
	);
});
)
