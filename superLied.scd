(
//server
Server.default = Server.local;
o = Server.default.options;
o.memSize_(2.pow(40));

//tempo
~timer = TempoClock.new(128/60);

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
					~gridInit == false //check to see if grid has been initialized
				)
				{
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
										~a[pos].play(~timer, quant: 4);
										AppClock.sched(0,{~comp[1].children[pos].value_(1)})
									}
								);
								~draw.value(x,y);
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
					~draw = {
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
						~mftInit == false, //check to see if midi fighter twister has been initialized
						{
							MIDIClient.init;
							MIDIIn.connectAll;
							MIDIdef.cc(\miid, {
								arg val, num, chan, src;
								for(0,63,{
									arg i;
									if(
										(num == i) && (chan == 0),
										{
											Pdefn(
												i,
												Pseq([val.linlin(0,127,0,1)],inf)
											);
											AppClock.sched(0,{~comp[0].children[i].value_(val.linlin(0,127,0,1))});
											~idim[i] = val.linlin(0,127,0,1)
										}
									)
								});
								for(0,63,{
									arg i;
									if(
										(num == i) && (chan == 4),
										{
											Pdefn(
												i+64,
												Pseq([val.linlin(0,127,0,1)],inf)
											);
											AppClock.sched(0,{~comp[0].children[i+64].value_(val.linlin(0,127,0,1))});
											~dimi[i] = val.linlin(0,127,0,1)
										}
									)
								});
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
	.onClose_({~topScope.stop; ~bf.free; ~fb.free})
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
					AppClock.sched(0,{~comp[1].children[i].visible_(false)});
					x = i%16;
					y = (i-x)/16;
					if(
						y%2 == 1,
						{
							~draw.value(x,y)
						},
						{
							~m.led(x,y,4)
						}
					);
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
						~a[i+16].play(~timer, quant: 4);
						~step[i+16] = 1;
					},
					{
						~a[i+16].stop;
						~step[i+16] = 0;
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
						~a[i+48].play(~timer, quant: 4);
						~step[i+48] = 1;
					},
					{
						~a[i+48].stop;
						~step[i+48] = 0;
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
						~a[i+80].play(~timer, quant: 4);
						~step[i+80] = 1;
					},
					{
						~a[i+80].stop;
						~step[i+48] = 0;
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
						~a[i+112].play(~timer, quant:4);
						~step[i+112] = 1;
					},
					{
						~a[i+112].stop;
						~step[i+112] = 0;
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
			cutoff=15000,
			bus=~fb.index;
			var sig;
			sig = RLPF.ar(PlayBuf.ar(1, buf, BufRateScale.ir(buf) * rate, doneAction:2),cutoff,0.25);
			sig = sig * amp;
			Out.ar(
				bus,
				sig!2
			)
		}).add;
	);
	s.sync;
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
			16.do({arg i;
				~player.put(48+i, Synth(\PlayBufPlayer, [\bufnum, d[\n][i]]));
			});
		}).play;
	);
	s.sync;
//synths
	~sound = Array.fill(64, {0});
	~voices = [\1, \2, \3, \4, \5, \6, \7, \8];
	~voiceManager = Array.fill(64, {PatternProxy(Pseq(~voices, inf)).asStream});
	~durs = Array.fill(64, {0});
	~modnums = Array.fill(64, {0});
	~modenos = Array.fill(64, {0});
	~attacks = Array.fill(64, {0});
	~releases = Array.fill(64, {0});
//mic
/*	SynthDef(\mic,
		{
			arg out = 0,
			bus = ~fb.index;
			var sig;
			sig = SoundIn.ar(bus);
			sig = Pan2.ar(sig);
			Out.ar(bus, sig)
		}
	).play(s, [\out, 0]);
	s.sync;*/
//modulators
	384.do({ //24 LFOs per synth voice
		arg i;
		if(
			i < 128, //LFOs 0-127 are calibrated for panning
			{
				Ndef(i.asSymbol, {
					SinOsc.kr(~timer.beatDur/rrand(2.0,16.0)).range(-1,1)
				})
			}
		);
		if(
			(i > 127) && (i < 208), //LFOs 128-207 are calibrated for filter cutoff
			{
				Ndef(i.asSymbol, {
					SinOsc.kr(~timer.beatDur/rrand(2.0,512.0)).range(500,15000)
				})
			}
		);
		if(
			(i > 207) && (i < 256), //LFOs 208-255 are calibrated for panning
			{
				Ndef(i.asSymbol, {
					SinOsc.kr(~timer.beatDur/rrand(2.0,16.0)).range(-1,1)
				})
			}
		);
		if(
			(i > 255) && (i < 336), //LFOs 256-383 are calibrated for filter resonance
			{
				Ndef(i.asSymbol, {
					SinOsc.kr(~timer.beatDur/rrand(2.0,512.0)).range(0,3)
				})
			}
		)
	});
	s.sync;
	12.do({
		arg i;
		~player[48+i].set(\pan, Ndef((208+i).asSymbol))
	});
//sequences
	//bank 1
	(
		~sound.put(0,
			TriSin.new);
		~sound[0].setParam('all',\bus,~fb.index);
		~sound[0].setParam('all',\reverb_amount,0.3); //synth 0's reverb amount is set to a constant 0.3
		~sound[0].setParam('all',\room_size,0.4); //synth 0's room size is set to a constant 0.4
		~sound[0].setParam('all',\damp,0.5); // synth 0's dampening is set to a constant 0.5
		8.do({
			arg i;
			~sound[0].setParam((i+1).asSymbol,\pan,Ndef(i.asSymbol)); //LFOs 0-7 modulate synth 0's pan position
			~sound[0].setParam((i+1).asSymbol,\cutoff,Ndef((i+128).asSymbol)); //LFOs 128-135 modulate synth 0's filter cutoff
			~sound[0].setParam((i+1).asSymbol,\resonance,Ndef((i+256).asSymbol)); //LFOs 256-263 modulate synth 0's filter resonance
		});
		~note.put(32,
			PatternProxy(Pseq(~b, inf)));
		~noted.put(32,
			~note[32].asStream);
		~modnums.put(0,
			PatternProxy(Pseq([1,2,4,1],inf)).asStream);
		~modenos.put(0,
			PatternProxy(Pseq([1,2,1,4,2],inf)).asStream);
		~a.put(16,
			Tdef(\task0, {
				var delta, voice;
				loop {
					delta = rrand(2.0,6.0);
					voice = ~voiceManager[0].next;
					~sound[0].setParam(voice,\attack,rrand(2.0,10.0));
					~sound[0].setParam(voice,\release,rrand(5,10));
					~sound[0].setParam(voice,\amp,~idim[0]);
					~sound[0].setParam(voice,\pan_slew,rrand(7,20));
					~sound[0].setParam(voice,\index,~dimi[0].linlin(0,1,-24,24));
					~sound[0].setParam(voice,\modnum,~modnums[0].next);
					~sound[0].setParam(voice,\modeno,~modenos[0].next);
					~sound[0].setParam(voice,\freq_slew,[0,0.1].choose);
					~sound[0].setParam(voice,\cutoff_env,[0,1].choose);
					~sound[0].trigger(voice,(~noted[32].next+[24,36].choose).midicps);
					delta.yield;
				}
			}).clock_(~timer).quant_(4)
		)
	);

	(
		~sound.put(1,
			SinSin.new);
		~sound[1].setParam('all',\bus,~fb.index);
		~sound[1].setParam('all',\reverb_amount,0.3);
		~sound[1].setParam('all',\room_size,0.4);
		~sound[1].setParam('all',\damp,0.5);
		8.do({
			arg i;
			~sound[1].setParam((i+1).asSymbol,\pan,Ndef(i+8.asSymbol)); //LFOs 8-15 modulate synth 1's pan position
			~sound[1].setParam((i+1).asSymbol,\cutoff,Ndef((i+136).asSymbol)); //LFOs 136-143 modulate synth 1's filter cutoff
			~sound[1].setParam((i+1).asSymbol,\resonance,Ndef((i+264).asSymbol)); //LFOs 264-271 modulate synth 1's filter resonance
		});
		~note.put(33,
			PatternProxy(Pseq(~b.rotate(1), inf)));
		~noted.put(33,
			~note[33].asStream);
		~modnums.put(1,
			PatternProxy(Pseq([1,2,1,4,2],inf)).asStream);
		~modenos.put(1,
			PatternProxy(Pseq([1,2,4,1],inf)).asStream);
		~a.put(17,
			Tdef(\task1, {
				var delta, voice;
				loop {
					delta = rrand(2.0,6.0);
					voice = ~voiceManager[1].next;
					~sound[1].setParam(voice,\attack,rrand(2.0,10.0));
					~sound[1].setParam(voice,\release,rrand(5.0,10.0));
					~sound[1].setParam(voice,\amp,~idim[1]);
					~sound[1].setParam(voice,\pan_slew,rrand(0.1,20.0));
					~sound[1].setParam(voice,\index,~dimi[1].linlin(0,1,-24,24));
					~sound[1].setParam(voice,\modnum,~modnums[1].next);
					~sound[1].setParam(voice,\modeno,~modenos[1].next);
					~sound[1].setParam(voice,\freq_slew,3);
					~sound[1].setParam(voice,\cutoff_env,[0,1].choose);
					~sound[1].trigger(voice,(~noted[33].next+[24,36].choose).midicps);
					delta.yield;
				}
			}).clock_(~timer).quant_(4)
		)
	);

	(
		~sound.put(2,
			TriSin.new);
		~sound[2].setParam('all',\bus,~fb.index);
		~sound[2].setParam('all',\reverb_amount,0.3);
		~sound[2].setParam('all',\room_size,0.4);
		~sound[2].setParam('all',\damp,0.5);
		8.do({
			arg i;
			~sound[2].setParam((i+1).asSymbol,\pan,Ndef(i+16.asSymbol)); //LFOs 16-23 modulate synth 2's pan position
			~sound[2].setParam((i+1).asSymbol,\cutoff,Ndef((i+144).asSymbol)); //LFOs 144-151 modulate synth 2's filter cutoff
			~sound[2].setParam((i+1).asSymbol,\resonance,Ndef((i+272).asSymbol)); //LFOs 272-279 modulate synth 2's filter resonance
		});
		~note.put(34,
			PatternProxy(Pseq(~b.rotate(2), inf)));
		~noted.put(34,
			~note[34].asStream);
		~modnums.put(2,
			PatternProxy(Pseq([1,2,1,4,2],inf)).asStream);
		~modenos.put(2,
			PatternProxy(Pseq([1,2,4,1],inf)).asStream);
		~a.put(18,
			Tdef(\task2, {
				var delta, voice;
				loop {
					delta = ~noted[34].next+1;
					voice = ~voiceManager[2].next;
					~sound[2].setParam(voice,\attack,1/(~noted[34].next+0.01));
					~sound[2].setParam(voice,\release,1/(~noted[34].next+0.01));
					~sound[2].setParam(voice,\amp,~idim[2]);
					~sound[2].setParam(voice,\pan_slew,rrand(0.1,20.0));
					~sound[2].setParam(voice,\index,~dimi[2].linlin(0,1,-24,24));
					~sound[2].setParam(voice,\modnum,~modnums[2].next);
					~sound[2].setParam(voice,\modeno,~modenos[2].next);
					~sound[2].setParam(voice,\freq_slew,[0,0.1].choose);
					~sound[2].setParam(voice,\cutoff_env,[0,1].choose);
					~sound[2].trigger(voice,(~noted[34].next+36).midicps);
					delta.yield;
				}
			}).clock_(~timer).quant_(4)
		)
	);

	(
		~sound.put(3,
			SinSin.new);
		~sound[3].setParam('all',\bus,~fb.index);
		~sound[3].setParam('all',\reverb_amount,0.3);
		~sound[3].setParam('all',\room_size,0.4);
		~sound[3].setParam('all',\damp,0.5);
		8.do({
			arg i;
			~sound[3].setParam((i+1).asSymbol,\pan,Ndef(i+24.asSymbol)); //LFOs 24-31 modulate synth 3's pan position
			~sound[3].setParam((i+1).asSymbol,\cutoff,Ndef((i+152).asSymbol)); //LFOs 152-159 modulate synth 3's filter cutoff
			~sound[3].setParam((i+1).asSymbol,\resonance,Ndef((i+280).asSymbol)); //LFOs 280-287 modulate synth 3's filter resonance
		});
		~note.put(35,
			PatternProxy(Pseq(~b.rotate(3), inf)));
		~noted.put(35,
			~note[35].asStream);
		~modnums.put(3,
			PatternProxy(Pseq([1,2,1,4,2],inf)).asStream);
		~modenos.put(3,
			PatternProxy(Pseq([1,2,4,1],inf)).asStream);
		~a.put(19,
			Tdef(\task3, {
				var delta, voice;
				loop {
					delta = ~noted[35].next+1;
					voice = ~voiceManager[3].next;
					~sound[3].setParam(voice,\attack,1/(~noted[35].next+0.01));
					~sound[3].setParam(voice,\release,1/(~noted[35].next+0.01));
					~sound[3].setParam(voice,\amp,~idim[3]);
					~sound[3].setParam(voice,\pan_slew,rrand(0.1,20.0));
					~sound[3].setParam(voice,\index,~dimi[3].linlin(0,1,-24,24));
					~sound[3].setParam(voice,\modnum,~modnums[3].next);
					~sound[3].setParam(voice,\modeno,~modenos[3].next);
					~sound[3].setParam(voice,\freq_slew,[0,0.1].choose);
					~sound[3].setParam(voice,\cutoff_env,[0,1].choose);
					~sound[3].trigger(voice,(~noted[35].next+36).midicps);
					delta.yield;
				}
			}).clock_(~timer).quant_(4)
		)
	);

	(
		~sound.put(4,
			TriSin.new);
		~sound[4].setParam('all',\bus,~fb.index);
		~sound[4].setParam('all',\reverb_amount,0.3);
		~sound[4].setParam('all',\room_size,0.4);
		~sound[4].setParam('all',\damp,0.5);
		8.do({
			arg i;
			~sound[4].setParam((i+1).asSymbol,\pan,Ndef(i+32.asSymbol)); //LFOs 32-39 modulate synth 4's pan position
			~sound[4].setParam((i+1).asSymbol,\cutoff,Ndef((i+160).asSymbol)); //LFOs 160-167 modulate synth 4's filter cutoff
			~sound[4].setParam((i+1).asSymbol,\resonance,Ndef((i+288).asSymbol)); //LFOs 288-295 modulate synth 4's filter resonance
		});
		~note.put(36,
			PatternProxy(Pseq(~b.rotate(4), inf)));
		~noted.put(36,
			~note[36].asStream);
		~modnums.put(4,
			PatternProxy(Pseq([1,2,1,4,2],inf)).asStream);
		~modenos.put(4,
			PatternProxy(Pseq([1,2,4,1],inf)).asStream);
		~attacks.put(4,
			PatternProxy(Pseq([0.01],inf)).asStream);
		~releases.put(4,
			PatternProxy(Pseq([2],inf)).asStream);
		~a.put(20,
			Tdef(\task4, {
				var delta, voice;
				loop {
					delta = ~noted[36].next+1;
					voice = ~voiceManager[4].next;
					~sound[4].setParam(voice,\attack,~attacks[4].next);
					~sound[4].setParam(voice,\release,~releases[4].next);
					~sound[4].setParam(voice,\amp,~idim[4]);
					~sound[4].setParam(voice,\pan_slew,rrand(0.1,20.0));
					~sound[4].setParam(voice,\index,~dimi[4].linlin(0,1,-24,24));
					~sound[4].setParam(voice,\modnum,~modnums[4].next);
					~sound[4].setParam(voice,\modeno,~modenos[4].next);
					~sound[4].setParam(voice,\freq_slew,[0,0.1].choose);
					~sound[4].setParam(voice,\cutoff_env,[0,1].choose);
					~sound[4].trigger(voice,(~noted[36].next+36).midicps);
					delta.yield;
				}
			}).clock_(~timer).quant_(4)
		)
	);

	(
		~sound.put(5,
			SinSin.new);
		~sound[5].setParam('all',\bus,~fb.index);
		~sound[5].setParam('all',\reverb_amount,0.3);
		~sound[5].setParam('all',\room_size,0.4);
		~sound[5].setParam('all',\damp,0.5);
		8.do({
			arg i;
			~sound[5].setParam((i+1).asSymbol,\pan,Ndef(i+40.asSymbol)); //LFOs 40-47 modulate synth 5's pan position
			~sound[5].setParam((i+1).asSymbol,\cutoff,Ndef((i+168).asSymbol)); //LFOs 168-175 modulate synth 5's filter cutoff
			~sound[5].setParam((i+1).asSymbol,\resonance,Ndef((i+296).asSymbol)); //LFOs 296-303 modulate synth 5's filter resonance
		});
		~note.put(37,
			PatternProxy(Pseq(~b.rotate(5), inf)));
		~noted.put(37,
			~note[37].asStream);
		~modnums.put(5,
			PatternProxy(Pseq([1,2,1,4,2],inf)).asStream);
		~modenos.put(5,
			PatternProxy(Pseq([1,2,4,1],inf)).asStream);
		~attacks.put(5,
			PatternProxy(Pseq([0.01],inf)).asStream);
		~releases.put(5,
			PatternProxy(Pseq([2],inf)).asStream);
		~a.put(21,
			Tdef(\task5, {
				var delta, voice;
				loop {
					delta = ~noted[37].next+1;
					voice = ~voiceManager[5].next;
					~sound[5].setParam(voice,\attack,~attacks[5].next);
					~sound[5].setParam(voice,\release,~releases[5].next);
					~sound[5].setParam(voice,\amp,~idim[5]);
					~sound[5].setParam(voice,\pan_slew,rrand(0.1,2));
					~sound[5].setParam(voice,\index,~dimi[5].linlin(0,1,-24,24));
					~sound[5].setParam(voice,\modnum,~modnums[5].next);
					~sound[5].setParam(voice,\modeno,~modenos[5].next);
					~sound[5].setParam(voice,\freq_slew,[0,0.1].choose);
					~sound[5].setParam(voice,\cutoff_env,[0,1].choose);
					~sound[5].trigger(voice,(~noted[37].next+36).midicps);
					delta.yield;
				}
			}).clock_(~timer).quant_(4)
		)
	);

	(
		~sound.put(6,
			Ringer.new);
		~sound[6].setParam('all',\bus,~fb.index);
		~sound[6].setParam('all',\reverb_amount,0.3);
		~sound[6].setParam('all',\room_size,0.4);
		~sound[6].setParam('all',\damp,0.5);
		8.do({
			arg i;
			~sound[6].setParam((i+1).asSymbol,\pan,Ndef(i+48.asSymbol)); //LFOs 48-55 modulate synth 6's pan position
		});
		~note.put(38,
			PatternProxy(Pseq(~b.rotate(6), inf)));
		~noted.put(38,
			~note[38].asStream);
		~a.put(22,
			Tdef(\task6, {
				var delta, voice;
				loop {
					delta = ~noted[38].next+1;
					voice = ~voiceManager[6].next;
					~sound[6].setParam(voice,\amp,~idim[6]);
					~sound[6].setParam(voice,\pan_slew,rrand(0.1,2));
					~sound[6].setParam(voice,\index,~dimi[6].linlin(0,1,0,24));
					~sound[6].setParam(voice,\freq_slew,[0,0.1].choose);
					~sound[6].trigger(voice,(~noted[38].next+48).midicps);
					delta.yield;
				}
			}).clock_(~timer).quant_(4)
		)
	);

	(
		~sound.put(7,
			Ringer.new);
		~sound[7].setParam('all',\bus,~fb.index);
		~sound[7].setParam('all',\reverb_amount,0.3);
		~sound[7].setParam('all',\room_size,0.4);
		~sound[7].setParam('all',\damp,0.5);
		8.do({
			arg i;
			~sound[7].setParam((i+1).asSymbol,\pan,Ndef(i+56.asSymbol)); //LFOs 56-63 modulate synth 7's pan position
		});
		~note.put(39,
			PatternProxy(Pseq(~b.rotate(7), inf)));
		~noted.put(39,
			~note[39].asStream);
		~a.put(23,
			Tdef(\task7, {
				var delta, voice;
				loop {
					delta = ~noted[39].next+1;
					voice = ~voiceManager[7].next;
					~sound[6].setParam(voice,\amp,~idim[7]);
					~sound[6].setParam(voice,\pan_slew,rrand(0.1,2));
					~sound[6].setParam(voice,\index,~dimi[7].linlin(0,1,0,24));
					~sound[6].setParam(voice,\freq_slew,[0,0.1].choose);
					~sound[6].trigger(voice,(~noted[39].next+48).midicps);
					delta.yield;
				}
			}).clock_(~timer).quant_(4)
		)
	);

	(
		~sound.put(8,
			TriSin.new);
		~sound[8].setParam('all',\bus,~fb.index);
		~sound[8].setParam('all',\reverb_amount,0.3);
		~sound[8].setParam('all',\room_size,0.4);
		~sound[8].setParam('all',\damp,0.5);
		8.do({
			arg i;
			~sound[8].setParam((i+1).asSymbol,\pan,Ndef(i+64.asSymbol)); //LFOs 64-71 modulate synth 4's pan position
			~sound[8].setParam((i+1).asSymbol,\cutoff,Ndef((i+176).asSymbol)); //LFOs 176-183 modulate synth 4's filter cutoff
			~sound[8].setParam((i+1).asSymbol,\resonance,Ndef((i+304).asSymbol)); //LFOs 304-311 modulate synth 4's filter resonance
		});
		~note.put(40,
			PatternProxy(Pseq(~b.rotate(8), inf)));
		~noted.put(40,
			~note[40].asStream);
		~durs.put(8,
			PatternProxy(Pseq([2],inf)).asStream);
		~modnums.put(8,
			PatternProxy(Pseq([1,2,1,4,2],inf)).asStream);
		~modenos.put(8,
			PatternProxy(Pseq([1,2,4,1],inf)).asStream);
		~attacks.put(8,
			PatternProxy(Pseq([0.01],inf)).asStream);
		~releases.put(8,
			PatternProxy(Pseq([2],inf)).asStream);
		~a.put(24,
			Tdef(\task8, {
				var delta, voice;
				loop {
					delta = ~durs[8].next;
					voice = ~voiceManager[8].next;
					~sound[8].setParam(voice,\attack,~attacks[8].next);
					~sound[8].setParam(voice,\release,~releases[8].next);
					~sound[8].setParam(voice,\amp,~idim[8]);
					~sound[8].setParam(voice,\pan_slew,rrand(0.1,20.0));
					~sound[8].setParam(voice,\index,~dimi[8].linlin(0,1,-24,24));
					~sound[8].setParam(voice,\modnum,~modnums[8].next);
					~sound[8].setParam(voice,\modeno,~modenos[8].next);
					~sound[8].setParam(voice,\freq_slew,[0,0.1].choose);
					~sound[8].setParam(voice,\cutoff_env,[0,1].choose);
					~sound[8].trigger(voice,(~noted[40].next+36).midicps);
					delta.yield;
				}
			}).clock_(~timer).quant_(4)
		)
	);

	(
		~sound.put(9,
			SinSin.new);
		~sound[9].setParam('all',\bus,~fb.index);
		~sound[9].setParam('all',\reverb_amount,0.3);
		~sound[9].setParam('all',\room_size,0.4);
		~sound[9].setParam('all',\damp,0.5);
		8.do({
			arg i;
			~sound[9].setParam((i+1).asSymbol,\pan,Ndef(i+72.asSymbol)); //LFOs 72-79 modulate synth 4's pan position
			~sound[9].setParam((i+1).asSymbol,\cutoff,Ndef((i+184).asSymbol)); //LFOs 184-191 modulate synth 4's filter cutoff
			~sound[9].setParam((i+1).asSymbol,\resonance,Ndef((i+312).asSymbol)); //LFOs 312-319 modulate synth 4's filter resonance
		});
		~note.put(41,
			PatternProxy(Pseq(~b.rotate(9), inf)));
		~noted.put(41,
			~note[41].asStream);
		~durs.put(9,
			PatternProxy(Pseq([3],inf)).asStream);
		~modnums.put(9,
			PatternProxy(Pseq([1,2,1,4,2],inf)).asStream);
		~modenos.put(9,
			PatternProxy(Pseq([1,2,4,1],inf)).asStream);
		~attacks.put(9,
			PatternProxy(Pseq([0.01],inf)).asStream);
		~releases.put(9,
			PatternProxy(Pseq([2],inf)).asStream);
		~a.put(25,
			Tdef(\task9, {
				var delta, voice;
				loop {
					delta = ~durs[9].next;
					voice = ~voiceManager[9].next;
					~sound[9].setParam(voice,\attack,~attacks[9].next);
					~sound[9].setParam(voice,\release,~releases[9].next);
					~sound[9].setParam(voice,\amp,~idim[9]);
					~sound[9].setParam(voice,\pan_slew,rrand(0.1,20.0));
					~sound[9].setParam(voice,\index,~dimi[9].linlin(0,1,-24,24));
					~sound[9].setParam(voice,\modnum,~modnums[9].next);
					~sound[9].setParam(voice,\modeno,~modenos[9].next);
					~sound[9].setParam(voice,\freq_slew,[0,0.1].choose);
					~sound[9].setParam(voice,\cutoff_env,[0,1].choose);
					~sound[9].trigger(voice,(~noted[41].next+36).midicps);
					delta.yield;
				}
			}).clock_(~timer).quant_(4)
		)
	);

	(
		~sound.put(10,
			TriSin.new);
		~sound[10].setParam('all',\bus,~fb.index);
		~sound[10].setParam('all',\reverb_amount,0.3);
		~sound[10].setParam('all',\room_size,0.4);
		~sound[10].setParam('all',\damp,0.5);
		8.do({
			arg i;
			~sound[10].setParam((i+1).asSymbol,\pan,Ndef(i+80.asSymbol)); //LFOs 80-87 modulate synth 4's pan position
			~sound[10].setParam((i+1).asSymbol,\cutoff,Ndef((i+192).asSymbol)); //LFOs 192-199 modulate synth 4's filter cutoff
			~sound[10].setParam((i+1).asSymbol,\resonance,Ndef((i+320).asSymbol)); //LFOs 320-327 modulate synth 4's filter resonance
		});
		~note.put(42,
			PatternProxy(Pseq(~b.rotate(10), inf)));
		~noted.put(42,
			~note[42].asStream);
		~durs.put(10,
			PatternProxy(Pseq([5],inf)).asStream);
		~modnums.put(10,
			PatternProxy(Pseq([1,2,1,4,2],inf)).asStream);
		~modenos.put(10,
			PatternProxy(Pseq([1,2,4,1],inf)).asStream);
		~attacks.put(10,
			PatternProxy(Pseq([0.01],inf)).asStream);
		~releases.put(10,
			PatternProxy(Pseq([2],inf)).asStream);
		~a.put(26,
			Tdef(\task10, {
				var delta, voice;
				loop {
					delta = ~durs[10].next;
					voice = ~voiceManager[10].next;
					~sound[10].setParam(voice,\attack,~attacks[10].next);
					~sound[10].setParam(voice,\release,~releases[10].next);
					~sound[10].setParam(voice,\amp,~idim[10]);
					~sound[10].setParam(voice,\pan_slew,rrand(0.1,20.0));
					~sound[10].setParam(voice,\index,~dimi[10].linlin(0,1,-24,24));
					~sound[10].setParam(voice,\modnum,~modnums[10].next);
					~sound[10].setParam(voice,\modeno,~modenos[10].next);
					~sound[10].setParam(voice,\freq_slew,[0,0.1].choose);
					~sound[10].setParam(voice,\cutoff_env,[0,1].choose);
					~sound[10].trigger(voice,(~noted[42].next+36).midicps);
					delta.yield;
				}
			}).clock_(~timer).quant_(4)
		)
	);

	(
		~sound.put(11,
			TriSin.new);
		~sound[11].setParam('all',\bus,~fb.index);
		~sound[11].setParam('all',\reverb_amount,0.3);
		~sound[11].setParam('all',\room_size,0.4);
		~sound[11].setParam('all',\damp,0.5);
		8.do({
			arg i;
			~sound[11].setParam((i+1).asSymbol,\pan,Ndef(i+88.asSymbol)); //LFOs 88-95 modulate synth 4's pan position
			~sound[11].setParam((i+1).asSymbol,\cutoff,Ndef((i+200).asSymbol)); //LFOs 200-207 modulate synth 4's filter cutoff
			~sound[11].setParam((i+1).asSymbol,\resonance,Ndef((i+328).asSymbol)); //LFOs 328-335 modulate synth 4's filter resonance
		});
		~note.put(43,
			PatternProxy(Pseq(~b.rotate(11), inf)));
		~noted.put(43,
			~note[43].asStream);
		~durs.put(11,
			PatternProxy(Pseq([4,1,1,1,1],inf)).asStream);
		~modnums.put(11,
			PatternProxy(Pseq([1,2,1,4,2],inf)).asStream);
		~modenos.put(11,
			PatternProxy(Pseq([1,2,4,1],inf)).asStream);
		~attacks.put(11,
			PatternProxy(Pseq([0.01],inf)).asStream);
		~releases.put(11,
			PatternProxy(Pseq([2],inf)).asStream);
		~a.put(27,
			Tdef(\task11, {
				var delta, voice;
				loop {
					delta = ~durs[11].next;
					voice = ~voiceManager[11].next;
					~sound[11].setParam(voice,\attack,~attacks[11].next);
					~sound[11].setParam(voice,\release,~releases[11].next);
					~sound[11].setParam(voice,\amp,~idim[11]);
					~sound[11].setParam(voice,\pan_slew,rrand(0.1,20.0));
					~sound[11].setParam(voice,\index,~dimi[11].linlin(0,1,-24,24));
					~sound[11].setParam(voice,\modnum,~modnums[11].next);
					~sound[11].setParam(voice,\modeno,~modenos[11].next);
					~sound[11].setParam(voice,\freq_slew,[0,0.1].choose);
					~sound[11].setParam(voice,\cutoff_env,[0,1].choose);
					~sound[11].trigger(voice,(~noted[43].next+36).midicps);
					delta.yield;
				}
			}).clock_(~timer).quant_(4)
		)
	);

	(
		~sound.put(12,
			Ringer.new);
		~sound[12].setParam('all',\bus,~fb.index);
		~sound[12].setParam('all',\reverb_amount,0.3);
		~sound[12].setParam('all',\room_size,0.4);
		~sound[12].setParam('all',\damp,0.5);
		8.do({
			arg i;
			~sound[12].setParam((i+1).asSymbol,\pan,Ndef(i+96.asSymbol)); //LFOs 96-103 modulate synth 7's pan position
		});
		~note.put(44,
			PatternProxy(Pseq(~b.rotate(12), inf)));
		~noted.put(44,
			~note[44].asStream);
		~durs.put(12,
			PatternProxy(Pseq([0.5],inf)).asStream);
		~a.put(28,
			Tdef(\task12, {
				var delta, voice;
				loop {
					delta = ~durs[12].next;
					voice = ~voiceManager[12].next;
					~sound[12].setParam(voice,\amp,~idim[12]);
					~sound[12].setParam(voice,\pan_slew,rrand(0.1,2));
					~sound[12].setParam(voice,\index,~dimi[12].linlin(0,1,0,24));
					~sound[12].setParam(voice,\freq_slew,[0,0.1].choose);
					~sound[12].trigger(voice,(~noted[44].next+48).midicps);
					delta.yield;
				}
			}).clock_(~timer).quant_(4)
		)
	);

	(
		~sound.put(13,
			Ringer.new);
		~sound[13].setParam('all',\bus,~fb.index);
		~sound[13].setParam('all',\reverb_amount,0.3);
		~sound[13].setParam('all',\room_size,0.4);
		~sound[13].setParam('all',\damp,0.5);
		8.do({
			arg i;
			~sound[13].setParam((i+1).asSymbol,\pan,Ndef(i+104.asSymbol)); //LFOs 104-111 modulate synth 7's pan position
		});
		~note.put(45,
			PatternProxy(Pseq(~b.rotate(13), inf)));
		~noted.put(45,
			~note[45].asStream);
		~durs.put(13,
			PatternProxy(Pseq([0.25],inf)).asStream);
		~a.put(29,
			Tdef(\task13, {
				var delta, voice;
				loop {
					delta = ~durs[13].next;
					voice = ~voiceManager[13].next;
					~sound[13].setParam(voice,\amp,~idim[13]);
					~sound[13].setParam(voice,\pan_slew,rrand(0.1,2));
					~sound[13].setParam(voice,\index,~dimi[13].linlin(0,1,0,24));
					~sound[13].setParam(voice,\freq_slew,[0,0.1].choose);
					~sound[13].trigger(voice,(~noted[45].next+48).midicps);
					delta.yield;
				}
			}).clock_(~timer).quant_(4)
		)
	);

	(
		~sound.put(14,
			Ringer.new);
		~sound[14].setParam('all',\bus,~fb.index);
		~sound[14].setParam('all',\reverb_amount,0.3);
		~sound[14].setParam('all',\room_size,0.4);
		~sound[14].setParam('all',\damp,0.5);
		8.do({
			arg i;
			~sound[14].setParam((i+1).asSymbol,\pan,Ndef(i+112.asSymbol)); //LFOs 112-119 modulate synth 7's pan position
		});
		~note.put(46,
			PatternProxy(Pseq(~b.rotate(14), inf)));
		~noted.put(46,
			~note[46].asStream);
		~durs.put(14,
			PatternProxy(Pseq([0.75],inf)).asStream);
		~a.put(30,
			Tdef(\task14, {
				var delta, voice;
				loop {
					delta = ~durs[14].next;
					voice = ~voiceManager[14].next;
					~sound[14].setParam(voice,\amp,~idim[14]);
					~sound[14].setParam(voice,\pan_slew,rrand(0.1,2));
					~sound[14].setParam(voice,\index,~dimi[14].linlin(0,1,0,24));
					~sound[14].setParam(voice,\freq_slew,[0,0.1].choose);
					~sound[14].trigger(voice,(~noted[46].next+36).midicps);
					delta.yield;
				}
			}).clock_(~timer).quant_(4)
		)
	);

	(
		~sound.put(15,
			Ringer.new);
		~sound[15].setParam('all',\bus,~fb.index);
		~sound[15].setParam('all',\reverb_amount,0.3);
		~sound[15].setParam('all',\room_size,0.4);
		~sound[15].setParam('all',\damp,0.5);
		8.do({
			arg i;
			~sound[15].setParam((i+1).asSymbol,\pan,Ndef(i+120.asSymbol)); //LFOs 120-127 modulate synth 7's pan position
		});
		~note.put(47,
			PatternProxy(Pseq(~b.rotate(15), inf)));
		~noted.put(47,
			~note[47].asStream);
		~durs.put(15,
			PatternProxy(Pseq([1.5],inf)).asStream);
		~a.put(31,
			Tdef(\task15, {
				var delta, voice;
				loop {
					delta = ~durs[15].next;
					voice = ~voiceManager[15].next;
					~sound[15].setParam(voice,\amp,~idim[15]);
					~sound[15].setParam(voice,\pan_slew,rrand(0.1,2));
					~sound[15].setParam(voice,\index,~dimi[15].linlin(0,1,0,24));
					~sound[15].setParam(voice,\freq_slew,[0,0.1].choose);
					~sound[15].trigger(voice,(~noted[47].next+36).midicps);
					delta.yield;
				}
			}).clock_(~timer).quant_(4)
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
			Tdef(\task16, {
				var delta, starter, ender;
				loop {
					delta = ~noted[64].next+1;
					starter = ~noted[64].next.linlin(0,32,0,1);
					ender = starter+~idim[17].linlin(0,1,0.01,0.1);
					~player[48].set(\t_trig,1,\start,starter,\end,ender,\loops,1,\amp,~idim[16],\bus,~fb.index);
					delta.yield;
				}
			}).clock_(~timer).quant_(4)
		)
	);

	(
		~note.put(65,
			PatternProxy(Pseq(~b.rotate(17), inf)));
		~noted.put(65,
			~note[65].asStream);
		~a.put(49,
			Tdef(\task17, {
				var delta, scaledtime;
				loop {
					delta = ~noted[65].next+1;
					scaledtime = ~noted[65].next.linlin(0,32,-2,2);
					~player[48].set(\rate, scaledtime);
					delta.yield;
				}
			}).clock_(~timer).quant_(4)
		)
	);

	//sample 2
	(
		~note.put(66,
			PatternProxy(Pseq(~b.rotate(18), inf)));
		~noted.put(66,
			~note[66].asStream);
		~a.put(50,
			Tdef(\task18, {
				var delta, starter, ender;
				loop {
					delta = ~noted[66].next+1;
					starter = ~noted[66].next.linlin(0,32,0,1);
					ender = starter+~idim[19].linlin(0,1,0.01,0.1);
					~player[49].set(\t_trig,1,\start,starter,\end,ender,\loops,1,\amp,~idim[18],\bus,~fb.index);
					delta.yield;
				}
			}).clock_(~timer).quant_(4)
		)
	);

	(
		~note.put(67,
			PatternProxy(Pseq(~b.rotate(19), inf)));
		~noted.put(67,
			~note[67].asStream);
		~a.put(51,
			Tdef(\task19, {
				var delta, scaledtime;
				loop {
					delta = ~noted[67].next+1;
					scaledtime = ~noted[67].next.linlin(0,32,-2,2);
					~player[49].set(\rate, scaledtime);
					delta.yield;
				}
			}).clock_(~timer).quant_(4)
		)
	);

	//sample 3
	(
		~note.put(68,
			PatternProxy(Pseq(~b.rotate(20), inf)));
		~noted.put(68,
			~note[68].asStream);
		~a.put(52,
			Tdef(\task20, {
				var delta, starter, ender;
				loop {
					delta = ~noted[68].next+1;
					starter = ~noted[68].next.linlin(0,32,0,1);
					ender = starter+~idim[21].linlin(0,1,0.01,0.1);
					~player[50].set(\t_trig,1,\start,starter,\end,ender,\loops,1,\amp,~idim[20],\bus,~fb.index);
					delta.yield;
				}
			}).clock_(~timer).quant_(4)
		)
	);

	(
		~note.put(69,
			PatternProxy(Pseq(~b.rotate(21), inf)));
		~noted.put(69,
			~note[69].asStream);
		~a.put(53,
			Tdef(\task21, {
				var delta, scaledtime;
				loop {
					delta = ~noted[69].next+1;
					scaledtime = ~noted[69].next.linlin(0,32,-2,2);
					~player[50].set(\rate, scaledtime);
					delta.yield;
				}
			}).clock_(~timer).quant_(4)
		)
	);

	//sample 4
		(
		~note.put(70,
			PatternProxy(Pseq(~b.rotate(22), inf)));
		~noted.put(70,
			~note[70].asStream);
		~a.put(54,
			Tdef(\task22, {
				var delta, starter, ender;
				loop {
					delta = ~noted[70].next+1;
					starter = ~noted[70].next.linlin(0,32,0,1);
					ender = starter+~idim[23].linlin(0,1,0.01,0.1);
					~player[51].set(\t_trig,1,\start,starter,\end,ender,\loops,1,\amp,~idim[22],\bus,~fb.index);
					delta.yield;
				}
			}).clock_(~timer).quant_(4)
		)
	);

	(
		~note.put(71,
			PatternProxy(Pseq(~b.rotate(23), inf)));
		~noted.put(71,
			~note[71].asStream);
		~a.put(55,
			Tdef(\task23, {
				var delta, scaledtime;
				loop {
					delta = ~noted[71].next+1;
					scaledtime = ~noted[71].next.linlin(0,32,-2,2);
					~player[51].set(\rate, scaledtime);
					delta.yield;
				}
			}).clock_(~timer).quant_(4)
		)
	);

		//sample 5
	(
		~note.put(72,
			PatternProxy(Pseq(~b.rotate(24), inf)));
		~noted.put(72,
			~note[72].asStream);
		~a.put(56,
			Tdef(\task24, {
				var delta, starter, ender;
				loop {
					delta = ~noted[72].next+1;
					starter = ~noted[72].next.linlin(0,32,0,1);
					ender = starter+~idim[25].linlin(0,1,0.01,0.1);
					~player[52].set(\t_trig,1,\start,starter,\end,ender,\loops,1,\amp,~idim[24],\bus,~fb.index);
					delta.yield;
				}
			}).clock_(~timer).quant_(4)
		)
	);

	(
		~note.put(73,
			PatternProxy(Pseq(~b.rotate(25), inf)));
		~noted.put(73,
			~note[73].asStream);
		~a.put(57,
			Tdef(\task25, {
				var delta, scaledtime;
				loop {
					delta = ~noted[73].next+1;
					scaledtime = ~noted[73].next.linlin(0,32,-2,2);
					~player[52].set(\rate, scaledtime);
					delta.yield;
				}
			}).clock_(~timer).quant_(4)
		)
	);

			//sample 6
	(
		~note.put(74,
			PatternProxy(Pseq(~b.rotate(26), inf)));
		~noted.put(74,
			~note[74].asStream);
		~a.put(58,
			Tdef(\task26, {
				var delta, starter, ender;
				loop {
					delta = ~noted[74].next+1;
					starter = ~noted[74].next.linlin(0,32,0,1);
					ender = starter+~idim[27].linlin(0,1,0.01,0.1);
					~player[53].set(\t_trig,1,\start,starter,\end,ender,\loops,1,\amp,~idim[26],\bus,~fb.index);
					delta.yield;
				}
			}).clock_(~timer).quant_(4)
		)
	);

	(
		~note.put(75,
			PatternProxy(Pseq(~b.rotate(27), inf)));
		~noted.put(75,
			~note[75].asStream);
		~a.put(59,
			Tdef(\task27, {
				var delta, scaledtime;
				loop {
					delta = ~noted[75].next+1;
					scaledtime = ~noted[75].next.linlin(0,32,-2,2);
					~player[53].set(\rate, scaledtime);
					delta.yield;
				}
			}).clock_(~timer).quant_(4)
		)
	);

			//sample 7
	(
		~note.put(76,
			PatternProxy(Pseq(~b.rotate(28), inf)));
		~noted.put(76,
			~note[76].asStream);
		~a.put(60,
			Tdef(\task28, {
				var delta, starter, ender;
				loop {
					delta = ~noted[76].next+1;
					starter = ~noted[76].next.linlin(0,32,0,1);
					ender = starter+~idim[29].linlin(0,1,0.01,0.1);
					~player[54].set(\t_trig,1,\start,starter,\end,ender,\loops,1,\amp,~idim[28],\bus,~fb.index);
					delta.yield;
				}
			}).clock_(~timer).quant_(4)
		)
	);

	(
		~note.put(77,
			PatternProxy(Pseq(~b.rotate(29), inf)));
		~noted.put(77,
			~note[77].asStream);
		~a.put(61,
			Tdef(\task29, {
				var delta, scaledtime;
				loop {
					delta = ~noted[77].next+1;
					scaledtime = ~noted[77].next.linlin(0,32,-2,2);
					~player[54].set(\rate, scaledtime);
					delta.yield;
				}
			}).clock_(~timer).quant_(4)
		)
	);

			//sample 8
	(
		~note.put(78,
			PatternProxy(Pseq(~b.rotate(30), inf)));
		~noted.put(78,
			~note[78].asStream);
		~a.put(62,
			Tdef(\task30, {
				var delta, starter, ender;
				loop {
					delta = ~noted[78].next+1;
					starter = ~noted[78].next.linlin(0,32,0,1);
					ender = starter+~idim[31].linlin(0,1,0.01,0.1);
					~player[55].set(\t_trig,1,\start,starter,\end,ender,\loops,1,\amp,~idim[30],\bus,~fb.index);
					delta.yield;
				}
			}).clock_(~timer).quant_(4)
		)
	);

	(
		~note.put(79,
			PatternProxy(Pseq(~b.rotate(31), inf)));
		~noted.put(79,
			~note[79].asStream);
		~a.put(63,
			Tdef(\task31, {
				var delta, scaledtime;
				loop {
					delta = ~noted[79].next+1;
					scaledtime = ~noted[79].next.linlin(0,32,-2.0,2.0);
					~player[55].set(\rate, scaledtime);
					delta.yield;
				}
			}).clock_(~timer).quant_(4)
		)
	);

	//bank 3
	//sample 1
	(
		~note.put(96,
			PatternProxy(Pseq(~b.rotate(32), inf)));
		~noted.put(96,
			~note[96].asStream);
		~a.put(80,
			Tdef(\task32, {
				var delta, starter, ender;
				loop {
					delta = ~noted[96].next+1;
					starter = ~noted[96].next.linlin(0,32,0,1);
					ender = starter+~idim[33].linlin(0,1,0.01,0.1);
					~player[56].set(\t_trig,1,\start,starter,\end,ender,\loops,1,\amp,~idim[32],\bus,~fb.index);
					delta.yield;
				}
			}).clock_(~timer).quant_(4)
		)
	);

	(
		~note.put(97,
			PatternProxy(Pseq(~b.rotate(33), inf)));
		~noted.put(97,
			~note[81].asStream);
		~a.put(81,
			Tdef(\task33, {
				var delta, scaledtime;
				loop {
					delta = ~noted[97].next+1;
					scaledtime = ~noted[97].next.linlin(0,32,-2,2);
					~player[56].set(\rate, scaledtime);
					delta.yield;
				}
			}).clock_(~timer).quant_(4)
		)
	);

	//sample 2
	(
		~note.put(98,
			PatternProxy(Pseq(~b.rotate(34), inf)));
		~noted.put(98,
			~note[98].asStream);
		~a.put(82,
			Tdef(\task34, {
				var delta, starter, ender;
				loop {
					delta = ~noted[98].next+1;
					starter = ~noted[98].next.linlin(0,32,0,1);
					ender = starter+~idim[35].linlin(0,1,0.01,0.1);
					~player[57].set(\t_trig,1,\start,starter,\end,ender,\loops,1,\amp,~idim[34],\bus,~fb.index);
					delta.yield;
				}
			}).clock_(~timer).quant_(4)
		)
	);

	(
		~note.put(99,
			PatternProxy(Pseq(~b.rotate(35), inf)));
		~noted.put(99,
			~note[99].asStream);
		~a.put(83,
			Tdef(\task35, {
				var delta, scaledtime;
				loop {
					delta = ~noted[99].next+1;
					scaledtime = ~noted[99].next.linlin(0,32,-2,2);
					~player[57].set(\rate, scaledtime);
					delta.yield;
				}
			}).clock_(~timer).quant_(4)
		)
	);

	//sample 3
	(
		~note.put(100,
			PatternProxy(Pseq(~b.rotate(36), inf)));
		~noted.put(100,
			~note[100].asStream);
		~a.put(84,
			Tdef(\task36, {
				var delta, starter, ender;
				loop {
					delta = ~noted[100].next+1;
					starter = ~noted[100].next.linlin(0,32,0,1);
					ender = starter+~idim[37].linlin(0,1,0.01,0.1);
					~player[58].set(\t_trig,1,\start,starter,\end,ender,\loops,1,\amp,~idim[36],\bus,~fb.index);
					delta.yield;
				}
			}).clock_(~timer).quant_(4)
		)
	);

	(
		~note.put(101,
			PatternProxy(Pseq(~b.rotate(37), inf)));
		~noted.put(101,
			~note[101].asStream);
		~a.put(85,
			Tdef(\task37, {
				var delta, scaledtime;
				loop {
					delta = ~noted[101].next+1;
					scaledtime = ~noted[101].next.linlin(0,32,-2,2);
					~player[58].set(\rate, scaledtime);
					delta.yield;
				}
			}).clock_(~timer).quant_(4)
		)
	);

	//sample 4
		(
		~note.put(102,
			PatternProxy(Pseq(~b.rotate(38), inf)));
		~noted.put(102,
			~note[102].asStream);
		~a.put(86,
			Tdef(\task38, {
				var delta, starter, ender;
				loop {
					delta = ~noted[102].next+1;
					starter = ~noted[102].next.linlin(0,32,0,1);
					ender = starter+~idim[39].linlin(0,1,0.01,0.1);
					~player[59].set(\t_trig,1,\start,starter,\end,ender,\loops,1,\amp,~idim[38],\bus,~fb.index);
					delta.yield;
				}
			}).clock_(~timer).quant_(4)
		)
	);

	(
		~note.put(103,
			PatternProxy(Pseq(~b.rotate(39), inf)));
		~noted.put(103,
			~note[103].asStream);
		~a.put(87,
			Tdef(\task39, {
				var delta, scaledtime;
				loop {
					delta = ~noted[103].next+1;
					scaledtime = ~noted[103].next.linlin(0,32,-2,2);
					~player[59].set(\rate, scaledtime);
					delta.yield;
				}
			}).clock_(~timer).quant_(4)
		)
	);

		//sample 5
	(
		~note.put(104,
			PatternProxy(Pseq(~b.rotate(40), inf)));
		~noted.put(104,
			~note[104].asStream);
		~a.put(88,
			Tdef(\task40, {
				var delta, starter, ender;
				loop {
					delta = ~noted[104].next+1;
					starter = ~noted[104].next.linlin(0,32,0,1);
					ender = starter+~idim[41].linlin(0,1,0.01,0.1);
					~player[60].set(\t_trig,1,\start,starter,\end,ender,\loops,1,\amp,~idim[40],\bus,~fb.index);
					delta.yield;
				}
			}).clock_(~timer).quant_(4)
		)
	);

	(
		~note.put(105,
			PatternProxy(Pseq(~b.rotate(41), inf)));
		~noted.put(105,
			~note[105].asStream);
		~a.put(89,
			Tdef(\task41, {
				var delta, scaledtime;
				loop {
					delta = ~noted[105].next+1;
					scaledtime = ~noted[105].next.linlin(0,32,-2,2);
					~player[60].set(\rate, scaledtime);
					delta.yield;
				}
			}).clock_(~timer).quant_(4)
		)
	);

			//sample 6
	(
		~note.put(106,
			PatternProxy(Pseq(~b.rotate(42), inf)));
		~noted.put(106,
			~note[106].asStream);
		~a.put(90,
			Tdef(\task42, {
				var delta, starter, ender;
				loop {
					delta = ~noted[106].next+1;
					starter = ~noted[106].next.linlin(0,32,0,1);
					ender = starter+~idim[43].linlin(0,1,0.01,0.1);
					~player[61].set(\t_trig,1,\start,starter,\end,ender,\loops,1,\amp,~idim[42],\bus,~fb.index);
					delta.yield;
				}
			}).clock_(~timer).quant_(4)
		)
	);

	(
		~note.put(107,
			PatternProxy(Pseq(~b.rotate(43), inf)));
		~noted.put(107,
			~note[107].asStream);
		~a.put(91,
			Tdef(\task43, {
				var delta, scaledtime;
				loop {
					delta = ~noted[107].next+1;
					scaledtime = ~noted[107].next.linlin(0,32,-2,2);
					~player[61].set(\rate, scaledtime);
					delta.yield;
				}
			}).clock_(~timer).quant_(4)
		)
	);

			//sample 7
	(
		~note.put(108,
			PatternProxy(Pseq(~b.rotate(44), inf)));
		~noted.put(108,
			~note[108].asStream);
		~a.put(92,
			Tdef(\task44, {
				var delta, starter, ender;
				loop {
					delta = ~noted[108].next+1;
					starter = ~noted[108].next.linlin(0,32,0,1);
					ender = starter+~idim[45].linlin(0,1,0.01,0.1);
					~player[62].set(\t_trig,1,\start,starter,\end,ender,\loops,1,\amp,~idim[44],\bus,~fb.index);
					delta.yield;
				}
			}).clock_(~timer).quant_(4)
		)
	);

	(
		~note.put(109,
			PatternProxy(Pseq(~b.rotate(45), inf)));
		~noted.put(109,
			~note[109].asStream);
		~a.put(93,
			Tdef(\task45, {
				var delta, scaledtime;
				loop {
					delta = ~noted[109].next+1;
					scaledtime = ~noted[109].next.linlin(0,32,-2,2);
					~player[62].set(\rate, scaledtime);
					delta.yield;
				}
			}).clock_(~timer).quant_(4)
		)
	);

			//sample 8
	(
		~note.put(110,
			PatternProxy(Pseq(~b.rotate(46), inf)));
		~noted.put(110,
			~note[110].asStream);
		~a.put(94,
			Tdef(\task46, {
				var delta, starter, ender;
				loop {
					delta = ~noted[110].next+1;
					starter = ~noted[110].next.linlin(0,32,0,1);
					ender = starter+~idim[47].linlin(0,1,0.01,0.1);
					~player[63].set(\t_trig,1,\start,starter,\end,ender,\loops,1,\amp,~idim[46],\bus,~fb.index);
					delta.yield;
				}
			}).clock_(~timer).quant_(4)
		)
	);

	(
		~note.put(111,
			PatternProxy(Pseq(~b.rotate(47), inf)));
		~noted.put(111,
			~note[111].asStream);
		~a.put(95,
			Tdef(\task47, {
				var delta, scaledtime;
				loop {
					delta = ~noted[111].next+1;
					scaledtime = ~noted[111].next.linlin(0,32,-2,2);
					~player[63].set(\rate, scaledtime);
					delta.yield;
				}
			}).clock_(~timer).quant_(4)
		)
	);

	//bank 4
	~bufs = Array.fill(16,{0});
	~rates = Array.fill(16,{0});
	~amps = Array.fill(16, {0});

	(
		~durs.put(16,
			PatternProxy(Pseq([1/4],inf)).asStream);
		~bufs.put(0,
			PatternProxy(Pseq([d[\l][1], d[\m][3], d[\h][1]], inf)).asStream);
		~rates.put(0,
			PatternProxy(Pseq([0.5, 1, 0.25, 5, 0.75, 2, 4], inf)).asStream);
		~amps.put(0,
			PatternProxy(Pseq([0.95, Pexprand(0.5,0.75,0.7)], inf)).asStream);
		~a.put(112,
			Tdef(\task48, {
				var delta;
				loop {
					delta = ~durs[16].next;
					Synth(\bufPlay,
						[
							\buf: ~bufs[0].next,
							\rate: ~rates[0].next,
							\amp: ~amps[0].next*~idim[48],
							\cutoff: ~dimi[48].linexp(0,1,500,15000),
							\bus: ~fb.index
						]
					);
					delta.yield;
				}
			}).clock_(~timer).quant_(4)
		)
	);

	(
		~durs.put(17,
			PatternProxy(Pseq([2],inf)).asStream);
		~bufs.put(1,
			PatternProxy(Pseq([d[\zk][1], d[\zs][0]], inf)).asStream);
		~rates.put(1,
			PatternProxy(Pseq([1], inf)).asStream);
		~amps.put(1,
			PatternProxy(Pseq([1], inf)).asStream);
		~a.put(113,
			Tdef(\task49, {
				var delta;
				loop {
					delta = ~durs[17].next;
					Synth(\bufPlay,
						[
							\buf: ~bufs[1].next,
							\rate: ~rates[1].next,
							\amp: ~amps[1].next*~idim[49],
							\cutoff: ~dimi[49].linexp(0,1,500,15000),
							\bus: ~fb.index
						]
					);
					delta.yield;
				}
			}).clock_(~timer).quant_(4)
		)
	);

	(
		~durs.put(18,
			PatternProxy(Pseq([1/4, 1/4, 6/4, 1/3, 1/3, 4/3, 1/4, 1/4, 6/4, 1/3, 1/3, 1/3, 1/3, 2/3], inf)).asStream);
		~bufs.put(2,
			PatternProxy(Prand(d[\zm], inf)).asStream);
		~rates.put(2,
			PatternProxy(Pseq([1], inf)).asStream);
		~amps.put(2,
			PatternProxy(Pseq([1], inf)).asStream);
		~a.put(114,
			Tdef(\task50, {
				var delta;
				loop {
					delta = ~durs[18].next;
					Synth(\bufPlay,
						[
							\buf: ~bufs[2].next,
							\rate: ~rates[2].next,
							\amp: ~amps[2].next*~idim[50],
							\cutoff: ~dimi[50].linexp(0,1,500,15000),
							\bus: ~fb.index
						]
					);
					delta.yield;
				}
			}).clock_(~timer).quant_(4)
		)
	);

	(
		~durs.put(19,
			PatternProxy(Pseq([1/4], inf)).asStream);
		~bufs.put(3,
			PatternProxy(Prand(d[\zp], inf)).asStream);
		~rates.put(3,
			PatternProxy(Pseq([1], inf)).asStream);
		~amps.put(3,
			PatternProxy(Pseq([0.95, Pexprand(0.5,0.75,0.7)], inf)).asStream);
		~a.put(115,
			Tdef(\task51, {
				var delta;
				loop {
					delta = ~durs[19].next;
					Synth(\bufPlay,
						[
							\buf: ~bufs[3].next,
							\rate: ~rates[3].next,
							\amp: ~amps[3].next*~idim[51],
							\cutoff: ~dimi[51].linexp(0,1,500,15000),
							\bus: ~fb.index
						]
					);
					delta.yield;
				}
			}).clock_(~timer).quant_(4)
		)
	);

	(
		~durs.put(20,
			PatternProxy(Pseq([1/4, 1/4, 1/4, 3/2, 1/4, 1/4, 1/4], inf)).asStream);
		~bufs.put(4,
			PatternProxy(Prand(d[\zp], inf)).asStream);
		~rates.put(4,
			PatternProxy(Pseq([1], inf)).asStream);
		~amps.put(4,
			PatternProxy(Pseq([0.95, Pexprand(0.5,0.75,0.7)], inf)).asStream);
		~a.put(116,
			Tdef(\task52, {
				var delta;
				loop {
					delta = ~durs[20].next;
					Synth(\bufPlay,
						[
							\buf: ~bufs[4].next,
							\rate: ~rates[4].next,
							\amp: ~amps[4].next*~idim[52],
							\cutoff: ~dimi[52].linexp(0,1,500,15000),
							\bus: ~fb.index
						]
					);
					delta.yield;
				}
			}).clock_(~timer).quant_(4)
		)
	);

	(
		~durs.put(21,
			PatternProxy(Pseq([1/4, 1/4, 1/4, 3/2, 1/4, 1/4, 1/4, 1/4, 1/4, 1/4, 1/4, 1/4], inf)).asStream);
		~bufs.put(5,
			PatternProxy(Pseq([d[\l][1], d[\m][3], d[\h][1]], inf)).asStream);
		~rates.put(5,
			PatternProxy(Pseq([0.5, 1, 0.25, 5, 0.75, 2, 4], inf)).asStream);
		~amps.put(5,
			PatternProxy(Pseq([1], inf)).asStream);
		~a.put(117,
			Tdef(\task53, {
				var delta;
				loop {
					delta = ~durs[21].next;
					Synth(\bufPlay,
						[
							\buf: ~bufs[5].next,
							\rate: ~rates[5].next,
							\amp: ~amps[5].next*~idim[53],
							\cutoff: ~dimi[53].linexp(0,1,500,15000),
							\bus: ~fb.index
						]
					);
					delta.yield;
				}
			}).clock_(~timer).quant_(4)
		)
	);

	(
		~durs.put(22,
			PatternProxy(Pseq([1/2], inf)).asStream);
		~bufs.put(6,
			PatternProxy(Pseq([d[\zk][4]], inf)).asStream);
		~rates.put(6,
			PatternProxy(Pseq([1], inf)).asStream);
		~amps.put(6,
			PatternProxy(Pseq([1], inf)).asStream);
		~a.put(118,
			Tdef(\task54, {
				var delta;
				loop {
					delta = ~durs[22].next;
					Synth(\bufPlay,
						[
							\buf: ~bufs[6].next,
							\rate: ~rates[6].next,
							\amp: ~amps[6].next*~idim[54],
							\cutoff: ~dimi[54].linexp(0,1,500,15000),
							\bus: ~fb.index
						]
					);
					delta.yield;
				}
			}).clock_(~timer).quant_(4)
		)
	);

	(
		~durs.put(23,
			PatternProxy(Pseq([1, 5, 1, 1/2, 1/2], inf)).asStream);
		~bufs.put(7,
			PatternProxy(Prand(d[\zm], inf)).asStream);
		~rates.put(7,
			PatternProxy(Pseq([1], inf)).asStream);
		~amps.put(7,
			PatternProxy(Pseq([1], inf)).asStream);
		~a.put(119,
			Tdef(\task55, {
				var delta;
				loop {
					delta = ~durs[23].next;
					Synth(\bufPlay,
						[
							\buf: ~bufs[7].next,
							\rate: ~rates[7].next,
							\amp: ~amps[7].next*~idim[55],
							\cutoff: ~dimi[55].linexp(0,1,500,15000),
							\bus: ~fb.index
						]
					);
					delta.yield;
				}
			}).clock_(~timer).quant_(4)
		)
	);

	(
		~durs.put(24,
			PatternProxy(Pseq([1, 1/2, 1/2, 1, 5], inf)).asStream);
		~bufs.put(8,
			PatternProxy(Prand(d[\zp], inf)).asStream);
		~rates.put(8,
			PatternProxy(Pseq([1], inf)).asStream);
		~amps.put(8,
			PatternProxy(Pseq([1], inf)).asStream);
		~a.put(120,
			Tdef(\task56, {
				var delta;
				loop {
					delta = ~durs[24].next;
					Synth(\bufPlay,
						[
							\buf: ~bufs[8].next,
							\rate: ~rates[8].next,
							\amp: ~amps[8].next*~idim[56],
							\cutoff: ~dimi[56].linexp(0,1,500,15000),
							\bus: ~fb.index
						]
					);
					delta.yield;
				}
			}).clock_(~timer).quant_(4)
		)
	);

	(
		~durs.put(25,
			PatternProxy(Pseq([1/2, 1/2, 1, 5, 1], inf)).asStream);
		~bufs.put(9,
			PatternProxy(Prand(d[\zp], inf)).asStream);
		~rates.put(9,
			PatternProxy(Pseq([1], inf)).asStream);
		~amps.put(9,
			PatternProxy(Pseq([1], inf)).asStream);
		~a.put(121,
			Tdef(\task57, {
				var delta;
				loop {
					delta = ~durs[25].next;
					Synth(\bufPlay,
						[
							\buf: ~bufs[9].next,
							\rate: ~rates[9].next,
							\amp: ~amps[9].next*~idim[57],
							\cutoff: ~dimi[57].linexp(0,1,500,15000),
							\bus: ~fb.index
						]
					);
					delta.yield;
				}
			}).clock_(~timer).quant_(4)
		)
	);

	(
		~durs.put(26,
			PatternProxy(Pseq([1/2, 1, 5, 1, 1/2], inf)).asStream);
		~bufs.put(10,
			PatternProxy(Prand(d[\zp], inf)).asStream);
		~rates.put(10,
			PatternProxy(Pseq([1], inf)).asStream);
		~amps.put(10,
			PatternProxy(Pseq([1], inf)).asStream);
		~a.put(122,
			Tdef(\task58, {
				var delta;
				loop {
					delta = ~durs[26].next;
					Synth(\bufPlay,
						[
							\buf: ~bufs[10].next,
							\rate: ~rates[10].next,
							\amp: ~amps[10].next*~idim[58],
							\cutoff: ~dimi[58].linexp(0,1,500,15000),
							\bus: ~fb.index
						]
					);
					delta.yield;
				}
			}).clock_(~timer).quant_(4)
		)
	);

	(
		~durs.put(27,
			PatternProxy(Pseq([1], inf)).asStream);
		~bufs.put(11,
			PatternProxy(Pseq([d[\zk][1], d[\zs][0]], inf)).asStream);
		~rates.put(11,
			PatternProxy(Pseq([1], inf)).asStream);
		~amps.put(11,
			PatternProxy(Pseq([1], inf)).asStream);
		~a.put(123,
			Tdef(\task59, {
				var delta;
				loop {
					delta = ~durs[27].next;
					Synth(\bufPlay,
						[
							\buf: ~bufs[11].next,
							\rate: ~rates[11].next,
							\amp: ~amps[11].next*~idim[59],
							\cutoff: ~dimi[59].linexp(0,1,500,15000),
							\bus: ~fb.index
						]
					);
					delta.yield;
				}
			}).clock_(~timer).quant_(4)
		)
	);

	(
		~durs.put(28,
			PatternProxy(Pseq([1.5], inf)).asStream);
		~bufs.put(12,
			PatternProxy(Prand(d[\zm], inf)).asStream);
		~rates.put(12,
			PatternProxy(Pseq([1], inf)).asStream);
		~amps.put(12,
			PatternProxy(Pseq([1], inf)).asStream);
		~a.put(124,
			Tdef(\task60, {
				var delta;
				loop {
					delta = ~durs[28].next;
					Synth(\bufPlay,
						[
							\buf: ~bufs[12].next,
							\rate: ~rates[12].next,
							\amp: ~amps[12].next*~idim[60],
							\cutoff: ~dimi[60].linexp(0,1,500,15000),
							\bus: ~fb.index
						]
					);
					delta.yield;
				}
			}).clock_(~timer).quant_(4)
		)
	);

	(
		~durs.put(29,
			PatternProxy(Pseq([1.5], inf)).asStream);
		~bufs.put(13,
			PatternProxy(Pseq([d[\zk][1]], inf)).asStream);
		~rates.put(13,
			PatternProxy(Pseq([1], inf)).asStream);
		~amps.put(13,
			PatternProxy(Pseq([1], inf)).asStream);
		~a.put(125,
			Tdef(\task61, {
				var delta;
				loop {
					delta = ~durs[29].next;
					Synth(\bufPlay,
						[
							\buf: ~bufs[13].next,
							\rate: ~rates[13].next,
							\amp: ~amps[13].next*~idim[61],
							\cutoff: ~dimi[61].linexp(0,1,500,15000),
							\bus: ~fb.index
						]
					);
					delta.yield;
				}
			}).clock_(~timer).quant_(4)
		)
	);

	(
		~durs.put(30,
			PatternProxy(Pseq([1/3], inf)).asStream);
		~bufs.put(14,
			PatternProxy(Prand(d[\zm], inf)).asStream);
		~rates.put(14,
			PatternProxy(Pseq([1], inf)).asStream);
		~amps.put(14,
			PatternProxy(Pseq([1], inf)).asStream);
		~a.put(126,
			Tdef(\task62, {
				var delta;
				loop {
					delta = ~durs[30].next;
					Synth(\bufPlay,
						[
							\buf: ~bufs[14].next,
							\rate: ~rates[14].next,
							\amp: ~amps[14].next*~idim[62],
							\cutoff: ~dimi[62].linexp(0,1,500,15000),
							\bus: ~fb.index
						]
					);
					delta.yield;
				}
			}).clock_(~timer).quant_(4)
		)
	);

	(
		~durs.put(31,
			PatternProxy(Pseq([1/3], inf)).asStream);
		~bufs.put(15,
			PatternProxy(Prand(d[\zp], inf)).asStream);
		~rates.put(15,
			PatternProxy(Pseq([1], inf)).asStream);
		~amps.put(15,
			PatternProxy(Pseq([1], inf)).asStream);
		~a.put(127,
			Tdef(\task63, {
				var delta;
				loop {
					delta = ~durs[31].next;
					Synth(\bufPlay,
						[
							\buf: ~bufs[15].next,
							\rate: ~rates[15].next,
							\amp: ~amps[15].next*~idim[63],
							\cutoff: ~dimi[63].linexp(0,1,500,15000),
							\bus: ~fb.index
						]
					);
					delta.yield;
				}
			}).clock_(~timer).quant_(4)
		)
	);
}))
