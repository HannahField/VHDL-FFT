abstract type Frame end
abstract type Generics end

function parse_frame end
function compare end

struct Testbench
    sources::Vector{String}
    name::String
    build_directory::String
end

struct Simulation{G<:Generics,I<:Frame,O<:Frame}
    testbench::Testbench
    generics::G

    input_path::String
    output_path::String

    stop_time::String

    input_data::Vector{I}
    expected_data::Vector{O}

    tol::AbstractFloat
end


function simulate(sim::Simulation{G,I,O})::Vector{O} where {G<:Generics,I<:Frame,O<:Frame}
    build_directory = abspath(sim.testbench.build_directory)

    input_path = joinpath(build_directory, sim.input_path)
    output_path = joinpath(build_directory, sim.output_path)

    mkpath(build_directory)

    isfile(output_path) && rm(output_path)

    write_test_data(sim.input_data, input_path)

    println("Building project...")

    GHDL_build(sim.testbench)

    println("Running testbench $(sim.testbench.name)...")

    GHDL_run(sim)

    isfile(output_path) || throw(ErrorException("The testbench did not produce \"$(sim.output_path)\""))

    actual_data = read_test_data(O, output_path)

    return actual_data
end


function verify(sim::Simulation{G,I,O})::Bool where {G<:Generics,I<:Frame,O<:Frame}

    actual_data = simulate(sim)

    println("Comparing results...")

    passed = compare(sim, actual_data)

    println(passed ? "PASS" : "FAIL")

    return passed
end


function to_Q_format(x::Real, N::Integer, M::Integer)::BigInt

    N >= 1 || throw(ArgumentError("N must include at least one sign bit"))

    M >= 0 || throw(ArgumentError("M must be nonnegative"))

    scale::BigInt = big(1) << M

    limit::BigInt = big(1) << (M+N-1)

    y::BigInt = round(BigInt, x * scale)

    # Check if the number will fit
    if (y >= limit || y < -limit)
        throw(OverflowError("$x does not fit in signed Q$N.$M"))
    end
    return y
end

write_field(io::IO, value) = print(io, value)
write_field(io::IO, value::Bool) = print(io, Int(value))


function write_test_data(data::AbstractVector{<:Frame}, filename::AbstractString="samples.txt")::Nothing
    open(filename, "w") do io
        for (line_index, line) in enumerate(data)
            for (field_index, field) in enumerate(fieldnames(typeof(line)))
                field_index > 1 && print(io, ",")
                write_field(io, getfield(line, field))
            end
            line_index < length(data) && println(io)
        end
    end
    return nothing
end

function read_test_data(::Type{T}, filename::AbstractString="results.txt",)::Vector{T} where {T<:Frame}
    data = T[]
    open(filename, "r") do io
        for (line_number, line) in enumerate(eachline(io))
            stripped_line = strip(line)

            isempty(stripped_line) && continue

            fields = strip.(split(stripped_line, ","))

            frame = try
                parse_frame(T, fields)
            catch error
                throw(ArgumentError("Failed to parse line $line_number of \"$filename\"."))*sprint(showerror, error)
            end
            push!(data, frame)
        end
    end
    return data
end


generic_value(value::Integer) = string(value)
generic_value(value::Bool) = value ? "'1'" : "'0'"
generic_value(value::String) = value
generic_value(value::BitArray) = "\""*join(Int.(value))*"\""

function convert_generics(generics::Generics)::Vector{String}
    generics_strings = String[]
    for generic in fieldnames(typeof(generics))
        value = getfield(generics, generic)
        push!(generics_strings, "-g$(generic)=$(generic_value(value))")
    end
    return generics_strings
end


function GHDL_build(testbench::Testbench)::Nothing

    build_directory = abspath(testbench.build_directory)

    sources = abspath.(testbench.sources)

    mkpath(build_directory)

    run(Cmd(
        `ghdl -i --std=08
            $sources`;
        dir=build_directory
    ))

    run(Cmd(
        `ghdl -m --std=08
            $(testbench.name)`;
        dir=build_directory
    ))
    return nothing
end

function GHDL_run(sim::Simulation)::Nothing

    build_directory = abspath(sim.testbench.build_directory)


    mkpath(build_directory)

    generics = convert_generics(sim.generics)
    push!(generics, "-gINPUT_FILE="*sim.input_path)
    push!(generics, "-gOUTPUT_FILE="*sim.output_path)


    run(Cmd(
        `ghdl -r --std=08
            $(sim.testbench.name)
            $generics
            --stop-time=$(sim.stop_time)
            --ieee-asserts=disable`;
        dir=build_directory
    ))
    return nothing
end