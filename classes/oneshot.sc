OneShot {

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

				SynthDef("OneShot", {
					arg t_gate = 0,
					rate = 1,
					cutoff,
					resonance,
					amp,
					pan,
					pan_slew,
					buf,
					bus;

					var sig = PlayBuf.ar(1, buf, BufRateScale.ir(buf) * rate, t_gate)*amp;

					var filter = MoogFF.ar(
						in: sig,
						freq: cutoff,
						gain: resonance
					);

					var signal = Pan2.ar(
						filter,
						pan.lag3(pan_slew)
					);

					Out.ar(bus,signal * amp);
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
			\cutoff, 8000,
			\resonance, 3,
			\amp, 0.5,
			\pan, 0,
			\pan_slew, 0.5,
			\buf, [0,1],
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
		arg voiceKey, buf;
		if(singleVoices[voiceKey].isPlaying, {
			voiceParams[voiceKey][\buf] = buf;
			singleVoices[voiceKey].set(\buf, buf);
			singleVoices[voiceKey].set(\t_gate, 1);
		},{
			voiceParams[voiceKey][\buf] = buf;
			Synth.new("OneShot", voiceParams[voiceKey].getPairs, singleVoices[voiceKey]);
			singleVoices[voiceKey].set(\t_gate, 1);
			NodeWatcher.register(singleVoices[voiceKey],true);
		});
	}

	trigger {
		arg voiceKey, buf;
		if(
			voiceKey == 'all', {
				voiceKeys.do({
					arg vK;
					this.playVoice(vK, buf);
				});
			},
			{
				this.playVoice(voiceKey, buf);
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