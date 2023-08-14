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
					arg out = 0,
					stopGate = 1,
					rate = 1,
					cutoff,
					resonance,
					amp,
					pan,
					pan_slew,
					reverb_amount,
					room_size,
					damp,
					buf,
					bus;

					var sig = PlayBuf.ar(1, buf, BufRateScale.ir(buf) * rate, doneAction:2)*amp;

					var filter = MoogFF.ar(
						in: sig,
						freq: cutoff,
						gain: resonance
					);

					var signal = Pan2.ar(
						FreeVerb.ar(
							filter,
							reverb_amount,
							room_size,
							damp
						),
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
			\reverb_amount, 0.33,
			\room_size, 0.5,
			\damp, 0,
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
		singleVoices[voiceKey].set(\stopGate, -1.05);
		voiceParams[voiceKey][\buf] = buf;
		Synth.new("OneShot", [\buf, buf] ++ voiceParams[voiceKey].getPairs, singleVoices[voiceKey]);
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