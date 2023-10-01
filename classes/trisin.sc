TriSin {

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

				SynthDef("TriSin", {
					arg t_gate = 0,
					index,
					modnum,
					modeno,
					freq,
					phase,
					cutoff,
					resonance,
					cutoff_env,
					attack,
					release,
					amp,
					pan,
					freq_slew,
					amp_slew,
					pan_slew,
					bus;

					var slewed_freq = freq.lag3(freq_slew);
					var modfreq = (modnum/modeno)*slewed_freq;

					var envelope = EnvGen.kr(
						envelope: Env.new(
							[0,0,1,0],
							times: [0.01,attack,release],
							curve: [0, 4, -4])
						,
						gate: t_gate
					);

					var sig = LFTri.ar(
						slewed_freq + (index*modfreq*SinOsc.ar(modfreq)),
						phase,
						amp)*envelope;

					var filter = MoogFF.ar(
						in: sig,
						freq: Select.kr(cutoff_env > 0, [cutoff, cutoff * envelope]),
						gain: resonance
					);

					var signal = Pan2.ar(
						filter*envelope,
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
			\modnum, 1,
			\modeno, 1,
			\index, 1,
			\phase, 0,
			\cutoff, 8000,
			\cutoff_env, 1,
			\resonance, 3,
			\attack, 0,
			\release, 0.4,
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
		if(singleVoices[voiceKey].isPlaying, {
			voiceParams[voiceKey][\freq] = freq;
			singleVoices[voiceKey].set(\freq, freq);
			singleVoices[voiceKey].set(\t_gate, 1);
		},{
			voiceParams[voiceKey][\freq] = freq;
			Synth.new("TriSin", voiceParams[voiceKey].getPairs, singleVoices[voiceKey]);
			singleVoices[voiceKey].set(\t_gate, 1);
			NodeWatcher.register(singleVoices[voiceKey],true);
		});
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