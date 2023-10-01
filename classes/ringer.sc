Ringer {

	classvar <voiceKeys;

	var <globalParams;
	var <voiceParams;
	var <voiceGroup;
	var <singleVoices;

	*initClass {
		voiceKeys = [ \1, \2, \3, \4, \5, \6, \7, \8];
		StartUp.add {
			var s = Server.default;

			s.waitForBoot {

				SynthDef("Ringer", {
					arg out = 0,
					stopGate = 1,
					index,
					freq,
					amp,
					pan,
					freq_slew,
					amp_slew,
					pan_slew,
					bus;

					var envelope = EnvGen.kr(
						envelope: Env.perc(
							attackTime: 0.01,
							releaseTime: index.abs*2,
							level: 1
						),
						gate: stopGate,
						doneAction: 2
					);

					var sig = Ringz.ar(
						Impulse.ar(0),
						freq,
						index,
						amp
					)*envelope;

					var signal = Pan2.ar(
						sig*envelope,
						pan.lag3(pan_slew)
					);


					Out.ar(bus,signal * amp.lag3(amp_slew));
				}).add;
			} //waitForBoot
		} //StartUp
	} //initClass

	*new {
		^super.new.init;
	}

	init {
		var s = Server.default;

		voiceGroup = Group.new(s);

		globalParams = Dictionary.newFrom([
			\freq, 400,
			\index, 3,
			\amp, 0.5,
			\pan, 0,
			\freq_slew, 0,
			\amp_slew, 0.05,
			\pan_slew, 0.5,
			\bus, 0;
		]);
		singleVoices = Dictionary.new;
		voiceParams = Dictionary.new;
		voiceKeys.do({
			arg voiceKey;
			singleVoices[voiceKey] = Group.new(voiceGroup);
			voiceParams[voiceKey] = Dictionary.newFrom(globalParams);
		});
	}

	playVoice {
		arg voiceKey, freq;
		singleVoices[voiceKey].set(\stopGate, -1.05);
		voiceParams[voiceKey][\freq] = freq;
		Synth.new("Ringer", [\freq, freq] ++ voiceParams[voiceKey].getPairs, singleVoices[voiceKey]);
	}

	trigger {
		arg voiceKey, freq;
		if(
			voiceKey == 'all', {
				voiceKeys.do({
					arg vK;
					this.playVoice(vK, freq);
				});
			},
			{
				this.playVoice(voiceKey, freq);
			}
		);
	}

	adjustVoice {
		arg voiceKey, paramKey, paramValue;
		singleVoices[voiceKey].set(paramKey, paramValue);
		voiceParams[voiceKey][paramKey] = paramValue
	}

	setParam {
		arg voiceKey, paramKey, paramValue;
		if(
			voiceKey == 'all', {
				voiceKeys.do({
					arg vK;
					this.adjustVoice(vK, paramKey, paramValue);
				});
			},
			{
				this.adjustVoice(voiceKey, paramKey, paramValue);
			}
		);
	}

	freeAllNotes {
		voiceGroup.set(\stopGate, -1.05);
	}

	free {
		voiceGroup.free;
	}

}