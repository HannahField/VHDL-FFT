include("../JHDL.jl")
using FFTW
using Random

struct FFTFrame<:Frame
    real::Int32
    imag::Int32

    valid::Bool
end

struct FFTGenerics<:Generics
    logN::Integer
    FFT_MODE::Bool
    PRINT_INVALID::Bool
end

EVM(X, X_hat) = sqrt(sum(abs2.(X-X_hat))/sum(abs2.(X)))
dB(x) = 20*log10(x)

function parse_frame(FFTFrame, fields)
    FFTFrame(parse.(Int, fields)...)
end

function compare(sim::Simulation, actual::AbstractVector{FFTFrame})
    if length(sim.expected_data) != length(actual)
        return false
    elseif any(map(n -> sim.expected_data[n].valid != actual[n].valid, 1:length(sim.expected_data)))
        return false
    else
        e_c = map(n -> sim.expected_data[n].real + 1im*sim.expected_data[n].imag, 1:length(sim.expected_data))
        a_c = map(n -> actual[n].real + 1im*actual[n].imag, 1:length(actual))
        return EVM(e_c, a_c) < sim.tol
    end
end

logN::Int8 = 12
N = 2^logN

rng = Xoshiro(42)

r = to_Q_format.(randn(rng, N)/2^18, 1, 31)
i = to_Q_format.(randn(rng, N)/2^18, 1, 31)



in_frames = map(n -> FFTFrame.(r[n], i[n], true), 1:N)

expected = map(x -> FFTFrame(round.(Int, real(x)), round.(Int, imag(x)), true), fft(Int32.(r) + 1im*Int32.(i)))


generics = FFTGenerics(logN, true, false)

testbench = Testbench(["src/fft_pkg.vhd", "src/FFT_stage.vhd", "src/FFT.vhd", "testbenches/TB_framework.vhd"], "TB", "testing/")



sim = Simulation(testbench, generics, "samples.txt", "output.txt", "5ms", in_frames, expected, 0.01)

verify(sim)
