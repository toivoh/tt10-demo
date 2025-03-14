## Intro

Curly / Medieval presents

![](orion-iron-ion.png)

my contribution to the Tiny Tapeout 10 demo competition (which unfortunately got cancelled due the Efabless shutdown).
Code, graphics, and music by Curly (Toivo Henningsson) of Medieval.

The demo was originally written for the Sky130 process (see the sky130 branch), but was updated to the IHP process before submission.

## How it works

The demo code contains a few different parts, mainly:

- Logo
- Star field
- Floating point unit; used for the twister and spiralling balls
- Synthesizer and sequencer

The video output is produced in VGA mode 640x480 @60 Hz.
The logic is clocked at 50.4 MHz, giving two clock cycles per pixel.

### Logo
Just like in https://github.com/toivoh/tt08-demo, the logo is made of big pixels (32x32 this time vs 16x16 before), where each big pixel is split along the diagonal into two triangles.
The title is chosen so that the logo should hopefully compress well (and also alludes to the space theme and the echo feeling in the music). The dimensions of the characters are chosen so that patterns should repeat at a scale of 4 pixels, to try to make them more visible to the tool's logic minimizer.

### Star field
The star field keeps track of the current x and y coordinates with two extra subpixel bits of precision, increasing x or y by up to 4 units in each step. This is to allow the antialiasing effect where stars can move a fraction of a pixel per frame; since the output is RGB222, 2 subpixel position bits are enough.
The size of the step to take to the next x or y value is taken from a coarse table that is made so that the resulting x and y curve should be similar to turning in space. The table entries have higher precision, so that they can cause a dithering between e g increments of 2 and 3 or 3 and 4.

The distribution of stars is computed using a pseudorandom function that depends on the current x and y value. This is inspired by the pseudorandom function used in the synth (see below). The algorithm can be described as

	{r0, dr} = bitshuffle({jx, jy}, pattern1)
	r = r0
	for i=1:2
		r = bitshuffle(r, pattern2) + dr
		r = bitshuffle(r, pattern3)

	intensity = r[5:4]
	if intensity == 0: intensity = 1
	if r[3:0] != 0: intensity = 0

where `ix, iy` are input bits for the current position where we should determine if there is a star, and its brightness.
`bitshuffle(x, pattern)` permutes the bits of `x` using the fixed `pattern`. This can be done with only wires, so should be cheap.
The combination of addition and bit shuffling means that the effects of input bits propagate in a quite unpredictable way to affect the output bits, creating a pseudorandom behavior.
To find good star patterns, I simulated random bit shuffles with a script until I found a pattern that I liked.

The input to the random algorithm is not the full pixel positions `ix` and `iy`, but `jx = ix>>2` and `jy = iy>>1`.
Only every fourth x pixel position and every second y pixel position can hold a star, with black in between.
This allows the random algorithm time to converge before the star's intensity is needed.

A typical way to do the antialiasing of the stars would be to calculate numbers `px` and `py` that described how well the star aligns with the current x and y position, and use `px*py` to modulate the intensity. To save on logic, `min(px, py)` is used instead.
A small lookup table is then used to calculate the 2 bit pixel value from `min(px, py)` and the star's intensity.

### Floating point unit - twister and spiralling balls effects
The demo contains a small floating point unit for approximate floating point calculations, with 5 exponent bits and 11 mantissa bits.
The FPU implements addition and subtraction in a similar way to most FPUs.
It also supports approximate operations for multiplication and square root (approximate division could be supported as well, but wasn't needed).
The approximate operations assume that the concatenation of exponent and mantissa bits are a logarithmic representation of the floating point number: multiply adds `{exponent, mantissa}`, while square root shifts it right by one. The result is quite inaccurate, but good enough for the computations needed, and contributes some interesting jaggedness to the twister. These cheap approximations of multiply and square root were the motivation to use an FPU in the first place.

Conversion from fixed point to floating point is done by creating a floating point number with a fixed exponent and placing the fixed point number (with its sign bit inverted) in the mantissa, which produces a floating point number representation of `fixed_point_number+bias`. The bias is then subtracted.
To convert in the other direction, the bias is added to a floating point number, and the fixed point result is read out from the mantissa.

The FPU code uses the approximation `cos(0.5*pi*t) = 1 - t^2, abs(t) <= 1`. There didn't seem to be a point in making a more accurate representation given the inaccuracy of the multiplication.

The ALU has a single accumulator register and 5 general purpose registers.
One of the inputs to the ALU is always the accumulator, while the other can come from a register, constant, or time varying fixed point value from the outside.
The result is always written to the accumulator, and the value in the accumulator can then be written to one of the other registers.

#### Twister and spiral of balls effects
These are implemented by running a short FPU program during horizontal blanking before each scan line starts (different programs for different effects).
The program computes up to five x positions for the scan line, which are used to draw horizontal spans of light and dark blue.
The x positions share space with the mantissas in the FPU registers. The programs are written in such a way that they use fewer and fewer FPU registers as they are being overwritten with x positions.

#### Breaking down FPU instructions into cycles
To save area, each FPU instruction is broken into up to 3 single-cycle micro-operations:

- Add/sub:
	- Determine which argument has the largest magnitude
	- Add/Subtract
	- Normalize, calculating the correct exponent and shifting the mantissa to the right position
- Multiply:
	- Calculate carry out from mantissa sum
	- Add `{exponent, mantissa}`
- Single cycle instructions:
	- Load
	- Square root

The FPU code is stored as instructions rather than micro-operations, which should save some area.
One instruction is executed every 4 cycles, which lets the program code be indexed by a running timer.

The logic that represents the program ROM for the FPU has quite high latency.
A multicycle timing constraint is used to allow data paths that go through the program ROM to take two cycles. This means that no micro-operation is executed until the second cycle of running each instruction. (The multicycle constraint turned out not to be needed for the IHP version, and was removed.)

### Synthesizer
The synthesizer produces output samples at 63 kHz, 10 bit resolution.
This gives it 800 cycles (half a scan line) per sample, and the usable ouput range of PWM values is 0 - 800.
One voice sample is calculated in 64 cycles, which gives time to calculate 12 voices at the same time, plus a little time to update for the next sample.
On average, the voices need to have a peak amplitude <= 64 steps to fit into the output range; one step per cycle.

The voices are used as follows:

- 4x2 melody/harmony voices: 4 channels with 2 voices per channel with detuning to get a fatter sound
	- The frequency is slightly higher for one of the voices in each pair than the other
- Prenoise: the pedal tone with rhythmically changing timbre that runs throughout most of the demo
- Bass drum
- Hihat
- Visualization voice - not heard, used to produce the visible waveforms on screen
	- Can calculate two waveforms per scan line

#### Aliasing considerations
The waveforms are designed to keep aliasing artifacts relatively low:

- The melody/harmony waveforms use piecewise linear sections without a too steep slope, and avoid slopes of less than one unit per sample, which keeps aliasing down.
- The bass drum has a similar approach, using a clipped triangle wave that gradually sinks in frequency.
- The prenoise waveform is kept at a power of 2 frequency, since it would be hard to antialias. The music has been written around this limitation, with the prenoise as a pedal tone/ostinato.
	- Initially, the pedal tone is the tonic note.
	- After the music modulates down by a fifth towards the end, the pedal tone is now the fifth instead.
- The hihat is pure noise and doesn't need any antialiasing considerations.

To gradually reduce the volume of each voice, it is clamped to a decreasing maximum amplitude.
This simple method changes the waveform as the volume reduces, but keeps the slopes in their original range. If the volume had been reduced by multiplication, increasing aliasing artifacts would results as the effective range gets reduced.

#### ALU
The synthesizer is based around a small ALU, with a small set of registers

- 11 bit accumulator
- 10 bit output accumulator
- 10 bit output register
- 23 bit oscillator divided into low and high 11 bit parts plus top bit
- two flag bits (predicates)

The oscillator is used to calculate the phase of the waveforms, keep track of time in the demo, index the notes for the music and to know which frame to display.

#### Calculating voice phases from the shared oscillator
There are no registers to keep track of the phases of different synth voices.
Instead, for each sample of a voice that needs to be computed, the first 30 cycles are used to compute `phase = (freq * osc) >> n` to produce an 11 bit phase in the accumulator. The bits above 11 are truncateed, since the waveform repeats after one phase.
`freq` varies between 256 and 511 to choose a note, while `n` selects the octave.

The product `phase = (freq * osc) >> n` is calculated using shifts and adds (at most one of each per cycle), discarding low order bits when they are not needed anymore, and high order bits that will not be needed.
To illustrate the method, say that we want to calculate bits `10:3` of the product of an 8 bit and an 11 bit number.
The calculation can be visualized as follows:

	             ********
	            ********
	           ********
	          ********
	         ?*******|
	        ??****** |
	       ???*****  |
	      ????****   |
	     ?????***    |
	    ??????**     |
	 + ???????*      |
	---------------------
	= ????????********???

We have 11 product terms to add up, each with 8 bits.

- We proceed from the smallest term, adding up terms.
- In the first phase, the bottom bit in the current sum is not needed in the final output, so it can be dropped since no later term will change it (they are all shifted further to the left).
- In the second phase, we are out of bottom bits to ignore, and we can instead start to ignore top bits in the terms, since they are above the range of bits needed in the result.
- By changing the number of steps in the first phase, we can change the shift amount `n`.

This way, we can use the same number of bits to store each intermediate result as is needed to store the final result.
The implementation proceeds by shifting the intermediate result right by one for each step, switching to rotate right when coming to the second phase (to preserve the bits that are rotated out). When all relevant terms have been added, the result will have been rotated back to the correct position.

#### Evaluating waveforms using a single accumulator as intermediate storage
The synth ALU has only a single intermediate register to work with, the accumulator (to save area).
To evaluate a piecewise linear function (which the melodic/harmonic waveforms are made of), it first evaluates one or several conditions on the current accumulator value to know which piece of the piecewise linear function that it should evaluate, storing the results in the predicates. Then, it can use the predicate values to choose how to transform the accumulator.

#### Melody/harmony voices
There are two waveforms used for the melody/harmony voices: saw like and pulse like.
An ideal sawtooth wave includes a sudden jump every period, and an ideal pulse wave contains two.
To simulate a gradually closing lowpass filter, these jumps have been changed to ramps.
The slope of the ramps is gradually decreased as a note ages.

#### Bass drum
The bass drum approximates a clamped triangle wave with exponentially decreasing frequency.
This was a bit challenging to implement, since there is no register to store the bass drum's phase between samples, instead it has to be recalculated at each sample from the linearly increasing oscillator.

The bass drum uses a variation on the multiplication algorithm, takeing the lower bits of the oscillator and calculating an approximate square.
Let `x` be the relevant oscillator bits in fixed point. As `x` goes from 0 to one, the function

	y = (2-x)^2 mod 1

wraps around 3 times, with the slope at the end being half of the slope at the beginning.
Several such quadratic sections are shifted into decreasing octaves to give an approximation of an exponentially decaying frequency.
The square approximation is calculated using a variation of the multiplication algorithm described above. It uses only 8 slopes per octave, which seems to be barely enough to give the impression of a continuously descending pitch, but allows the algorithm to use the top 11 bits of the oscillator as one of its inputs.

The bass drum phase is used to evaluate a triangle wave, which is clamped to gradually reduce its volume.

#### Hihat
The hihat is created by noise clamped to a decreasing amplitude.
This kind of noise is traditionally created with a Linear Feedback Shift Register (LFSR), but that would have required space for registers to hold the LFSR state.
Instead, a new noise value is calculated for each sample based on the oscillator, using the algorithm

	acc = osc_low
	for i=0:3
		acc = bitshuffle(acc, pattern) + osc_high
		acc = acc + (acc >> 1)

The `pattern` used for shuffling is fixed, all it needs is an 11-bit wide multiplexer.
After four iterations, the result sounds like noise.

#### Prenoise pedal tone
The prenoise waveform used as a pedal tone is computed using a simplification of the noise algorithm above, with only one iteration:

	acc = <selected bits from osc>
	acc = bitshuffle(acc, pattern)
	acc = acc + rotate_right(acc, 1)  # could use acc *= 3 instead

The permutation used in the `bitshuffle` step is the same as in the noise case above, and has been chosen for the sonic results it produces in the prenoise case.
The result is a waveform with a power of 2 period that changes timbre in a rhythmic manner.

#### Visualization voice
The visualization voice can evaluate the waveform from any of the other voices, using the current scanline's y position instead of the oscillator, to keep the waveform steady from frame to frame. Two waveforms can be evaluated per scan line, one to be shown on the left side of the screen and one on the right side.
The synth is synchronized with the display output so that a new visualization waveform sample is computed in the middle of each scan line and one in hblank.
There are 3 registers to store the evaluated waveforms, to keep track of two waveforms and have access to the value from the previous scanline when a waveform is displayed.

#### Sequencer
The notes to play are taken from logic that represents a note ROM, and it has quite high latency.
Out of the 64 cycles used to compute each voice sample, the first cycle is used to wait for the output from the note ROM to stabilize, and the synthesizer doesn't do anything with the note data until the second cycle. This is accomplished with a multicycle timing constraint. (The multicycle constraint turned out not to be needed for the IHP version, and was removed.)

The note ROM contains data for 4 channels. For each channel and time position `pos`, it outputs an enable flag, a note value (note and octave), and an age value `t0`.
The actual age is computed as `t = t0 + pos` (with wraparound). This allows `t0` to be piecewise constant in the note ROM. The age `t` is filled out with low order bits from the oscillator, and used to modulate the waveform and volume of notes as they age.
Weaker notes can be achieved by starting them at a higher age.

## How to test

Plug in a [TinyVGA](https://github.com/mole99/tiny-vga) compatible Pmod on the TT08 demo board's out Pmod.
Plug in a Pmod compatible with [Mike's audio Pmod](https://github.com/MichaelBell/tt-audio-pmod) on the TT08 demo board's bidir Pmod.
Set all inputs to zero to get the default behavior.
The demo starts directly after reset.

## External hardware

This project needs

-  a [TinyVGA](https://github.com/mole99/tiny-vga) VGA Pmod.
- [Mike's audio Pmod](https://github.com/MichaelBell/tt-audio-pmod).
