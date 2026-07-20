abstract type Frame end
abstract type Generics end

function parse_frame end
function compare_frames end


function to_Q_format(x::Real, N::Integer, M::Integer)::BigInt

    N >= 1 || throw(ArgumentError("N must include at least one sign bit"))

    M >= 0 || throw(ArgumentError("M must be nonnegative"))

    scale::BigInt = big(1) << M

    limit::BigInt = big(1) << (M+N-1)

    y::BigInt = round(BigInt, x * scale)

    # Check if the number will fit
    if (y >= limit || y < -limit)
        throw(OverflowError("$x does not fit in signed QN.M"))
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
            catch
                throw("Failed to parse line $line_number of \"$filename\".")
            end
            push!(data, frame)
        end
    end
    return data
end

function compare(expected::AbstractVector{T}, actual::AbstractVector{T}; tol::Integer=0)::Bool where {T<:Frame}
    if (length(expected) != length(actual))
        println("Frame count mismatch")
        return false
    end

    for index in eachindex(expected, actual)
        result = compare_frames(expected[index], actual[index]; tol=tol)

        if (!result)
            println("Test failed at frame $index")
            return false
        end
    end
    return true
end

