# Overview
A standalone FFT/IFFT module in VHDL made for use in an FPGA based Software Defined Radio transmitter, enabling the use of technologies like OFDM and SC-FDMA. It was developed in conjunction with my bachelor project, on the [Design and Implementation of a Digital Baseband Transmitter for an FPGA-Based Software Defined Radio](https://github.com/HannahField/VHDL-SDR)

It was developed for the Terasic DE25 development and education board, which is based on an Altera Agilex 5 platform.

## Interface Contract
The module is real-time streaming, radix-2, with a maximum of N = 4096.

It is based on a simple valid-in interface, which, when asserted high, will cause the module to load the current input values into RAM. Once a full N samples have been loaded, the FFT will commence, ensuring that it is not possible to supply the module with an insufficient number of samples.

There are two data inputs, one for each of the real and imaginary parts, and they are std_logic_vectors of size 32. The samples should be provided in natural order.

The valid_out signal will be asserted when the outputs from the module are valid, and are streamed in natural order.

The size of the FFT is parametric with a generic, meaning it cannot be changed during run-time.

Currently the mode-select is changeable during run-time, but must be held constant. In the future this will be changed such that the mode select will be latched upon initiation of a new transform. FFT mode will be selected if mode = 1, and IFFT mode when mode = 0.

The samples do not need to be fed continuously, and any length of break between frames is acceptable. If there is a break in samples during a frame, the filling of the internal buffer will simply pause, and will resume as more samples are input. Currently, if you wish to reset the internal input buffer, you must first ensure any active transform has finished, as asserting the reset signal will reset the entire module. This will also be a future fix.

The reset signal is active high and synchronous.

The FFT transform performs no scaling, and as such there is the risk of overflowing or underflowing. In this case, the module will clamp rather than allow overflowing or underflowing.

The IFFT transform divides by N to fit the convention for the IDFT.

## API
### Generics
| Name | Description |
|---|---|
| N | Transform size. Must be a power of two up to 4096.|
### Ports
| Signal | Direction | Width | Description|
|---|---|---|---|
| CLK | in | 1 | System clock |
| INPUT_RE | in | 32 | std\_logic\_vector real input sample |
| INPUT_IM | in | 32 | std\_logic\_vector input sample |
| OUTPUT_RE | out | 32 | std\_logic\_vector output sample |
| OUTPUT_IM | out | 32 | std\_logic\_vector output sample |
| VALID_IN | in | 1 | Indicates that input data is valid|
| VALID_OUT | out | 1 | Indicates that output data is valid |
| RST | in | 1 | Active-high synchronous reset |
| MODE | in | 1 | FFT when `1`, IFFT when `0` |

## Architecture
The architecture is loosely based on a Single-Path Delay Feedback architecture with Decimation-In-Time.

The input buffer consists of a set of Ping-Pong RAMs of size N, with the input being stored in bit-reversed order in the current write-buffer, as to enable Decimation-In-Time with natural order inputs. Once the write-buffer is full, it will switch to read mode, from which it will be streamed into the FFT module. When this switch happens, the other RAM becomes the current write-buffer, allowing for continuous natural order streaming despite the Decimation-In-Time architecture.

The module consists for logN stages, $0 \leq s < logN$, each with a size of $M = 2^{s+1}$, delay of $D = 2^s$, and a counter $0 \leq i < M$. For each stage, a butterfly operation is performed on cycles for which $D \leq i < M$, between the current input and the D'th previous input:
\
$$Y_0[k]=X\left[i-D\right]+WX[i]$$
\
$$Y_1[k]=X\left[i-D\right]-WX[i]$$
\
Where W is the twiddle factor:
\
$$W = e^{\pm2\pi j (i-D)/D}$$
\
Where - is for the FFT and + is for the IFFT.

The first output, $Y_0$, is output immediately, while the second output is stored in another delay buffer, which is flushed as FIFO once all M/2 butterflies have been completed.

The output of every stage but the last is then wired up as the input to the next, including their valid_out/valid_in signals, which then automatically propagates the signal through the module. 

Internally, the inputs are converted to a custom dual 32-bit complex type, consisting of two signed 32 bit integers, one for each of the real and imaginary. The multiplication is a custom implemented operation between a complex 32-bit number and a complex 16-bit number, which just outputs a 48-bit complex number. The addition/subtraction is then implemented between two 48-bit complex numbers, of each which gets resized to 49-bits, added/subtracted, then divided by $2^15$, as the twiddle factors are Q1.15 numbers, and then resized (with saturation), to 32-bit complex numbers. As such, the internal data width is 32-bit.

Below is a small example of a stage, with M = 4, d = 2:

|i |  Current Input | Current Output | Delay Queue | Output Queue|
|---|---|---|---|---|
|0|X[0]|none|[\_\_\_\_\_,\_\_\_\_\_\_]|[\_\_\_\_\_\_,\_\_\_\_\_\_\_]|
|1|X[1]|none|[$`X[0]`$,\_\_\_\_\_]|[\_\_\_\_\_\_,\_\_\_\_\_\_\_]|
|2|X[2]|$`Y_{0}[0]`$|[$`X[0`$],$`X[1]`$]|[$`Y_1[0]`$,\_\_\_\_\_\_]|
|3|X[3]|$`Y_{0}[1]`$|[\_\_\_\_\_,$`X[1]`$]|[$`Y_1[0]`$,$`Y_1[1]`$]|
|4|none|$`Y_1[0]`$|[\_\_\_\_\_,\_\_\_\_\_\_]|[\_\_\_\_\_\_,$`Y_1[1]`$]|
|5|none|$`Y_1[1]`$|[\_\_\_\_\_,\_\_\_\_\_\_]|[\_\_\_\_\_\_,\_\_\_\_\_\_\_]|




## Testing and Verification
Testing of the FFT/IFFT module will only be done via simulation, but its use in the previously mentioned SDR is documented [here](https://github.com/HannahField/VHDL-SDR), where the output of the DAC is sampled via an analog discovery 2, and decoded in Julia, yielding an EVM of around -40 dB for both OFDM and SC-FDMA.

### Testbench
So far there is just one testbench which currently includes 4 different tests. The testbench can be seen in /testbenches, and the results can be seen in /notebooks.

But as a preview, the simulated EVM is around 0.0002 for all tests, which is around -74 dB.

### Resource Utilization and Timing Requirements
Compiled for the Terasic DE25, which is based on an Agilex 5 platform, with a clock period of 20 ns and N = 4096 yields:

 - 6,183 / 46,800 ALMs (13%)
 - 1,048,320 / 7,331,840 Memory Bits (14%)
 - 86 / 358 RAM blocks (24%)
 - 69 / 188 DSP blocks (37%)
 - 5.272 ns slack, yielding $`F_{max}\approx68`$ MHz
