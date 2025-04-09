# This file contains code that helps to query from the registry to determine the format

## Code dealing with Blocks 
@with_kw struct Block
    IMAX::Int64
    JMAX::Int64
    KMAX::Int64
    X::Array{Float64,3}
    Y::Array{Float64,3}
    Z::Array{Float64,3}
end

export Block, ReadMultiBlock, WriteMultiBlock
""" Reads a chunk X, Y, or Z variable from an ASCII Plot3D file

    Args
        f: IO
        IMAX (Int64): 
        JMAX (Int64):
        KMAX (Int64):

    Returns
        Array 3 dimensions for either X,Y, or Z
    """
function ReadPlot3DChunkBinary(f::IO,IMAX::Int64,JMAX::Int64,KMAX::Int64)::Array{Float64,3}
    A = Array{Float64,3}(undef,IMAX,JMAX,KMAX)
    for k in 1:KMAX
        for j in 1:JMAX
            for i in 1:IMAX
                A[i,j,k] = Float64(read(f,Float32))
            end
        end
    end
    return A
end

"""
    ReadPlot3DChunkASCII(f::IO,IMAX::Int64,JMAX::Int64,KMAX::Int64)::Array{Float64,3}

    Args
        f (io): 
"""
function ReadPlot3DChunkASCII(f::IO,IMAX::Int64,JMAX::Int64,KMAX::Int64)::Array{Float64,3}
    tokenArray = Array{Float64,1}(undef,IMAX*JMAX*KMAX)
    i=1
    while i <= length(tokenArray)
        words = split(strip(readline(f))," ")
        for w in words
            tokenArray[i] = parse(Float64,w)
            i+=1
        end
    end
    tokenArray = reshape(tokenArray,(KMAX,JMAX,IMAX))
    return permutedims(tokenArray,[3,2,1])
end

""" Reads a multi-block Plot3D Binary
    Args 
        filename (string): Name of file to read
        binary (Bool): read binary file or ascii
"""
function ReadMultiBlock(filename::String;binary::Bool=false)
    blocks = Block[]
    if isfile(filename)
        if binary
            io = open(filename,"r")
            NBLOCKS = Int64(read(io,Int32))
            IMAX = Int64[NBLOCKS]; JMAX = Int64[NBLOCKS]; KMAX = Int64[NBLOCKS]
            for i in 1:NBLOCKS
                IMAX[i] = Int64(read(io,Int32))
                JMAX[i] = Int64(read(io,Int32))
                KMAX[i] = Int64(read(io,Int32))
            end
            for i in 1:NBLOCKS
                X = ReadPlot3DChunkBinary(io,IMAX[i],JMAX[i],KMAX[i])
                Y = ReadPlot3DChunkBinary(io,IMAX[i],JMAX[i],KMAX[i])
                Z = ReadPlot3DChunkBinary(io,IMAX[i],JMAX[i],KMAX[i])
                b = Block(IMAX=IMAX[i],JMAX=JMAX[i],KMAX=KMAX[i],X=X,Y=Y,Z=Z)
                push!(blocks,b)
            end
            close(io)
        else
            io = open(filename,"r")
            NBLOCKS = parse(Int64,readline(io))
            IMAX = Array{Int64,1}(undef,NBLOCKS); JMAX = Array{Int64,1}(undef,NBLOCKS); KMAX = Array{Int64,1}(undef,NBLOCKS)
            for i in 1:NBLOCKS
                line = strip(readline(io))
                a,b,c = split(line," ")
                IMAX[i] = parse(Int64,a)
                JMAX[i] = parse(Int64,b)
                KMAX[i] = parse(Int64,c)
            end
            for i in 1:NBLOCKS
                X = ReadPlot3DChunkASCII(io,IMAX[i],JMAX[i],KMAX[i])
                Y = ReadPlot3DChunkASCII(io,IMAX[i],JMAX[i],KMAX[i])
                Z = ReadPlot3DChunkASCII(io,IMAX[i],JMAX[i],KMAX[i])
                b = Block(IMAX=IMAX[i],JMAX=JMAX[i],KMAX=KMAX[i],X=X,Y=Y,Z=Z)
                push!(blocks,b)
            end
            close(io)
        end
    end
    return blocks
end

## End Blocks

function WritePlot3DBlockBinary(f::IO,B::Block,double_precision::Bool=true)
    """Write binary plot3D block which contains X,Y,Z
        default format is Big-Endian

    Args:
        f (IO): file handle
        B (Block): writes a single block to a file
        double_precision (bool): writes to binary using double precision
    """
    function write_var(V::Array)
        for k in 1:B.KMAX
            for j in 1:B.JMAX
                for i in 1:B.IMAX
                    if !double_precision
                        write(f,Float32(V[i,j,k]))
                    else
                        write(f,Float64(V[i,j,k]))
                    end
                end
            end
        end
    end
    write_var(B.X)
    write_var(B.Y)
    write_var(B.Z)
end

function WritePlot3DBlockASCII(f,B::Block,columns::Int=6)
    """Write plot3D block in ascii format 

    Args:
        f (IO): file handle
        B (Block): writes a single block to a file
        columns (int, optional): Number of columns in the file. Defaults to 6.
    """
    function write_var(V::Array{AbstractFloat,3})
        bNewLine = false
        indx = 0
        for k in 1:B.KMAX
            for j in 1:B.JMAX
                for i in 1:B.IMAX
                    @printf(f,"%8.8f ",V[i,j,k])
                    bNewLine=False
                    indx+=1
                    if (indx % columns) == 0
                        @printf(f,"\n")
                        bNewLine=true
                    end
                end
            end
        end
    end

    if !bNewLine
        f.write('\n')
    end
    write_var(B.X)
    write_var(B.Y)
    write_var(B.Z)
end


function WriteMultiBlock(filename::String,blocks::Array{Block,1},binary::Bool=true,double_precision::Bool=true)
    """Writes blocks to a Plot3D file

    Args:
        filename (str): name of the file to create 
        blocks (List[Block]): List containing all the blocks to write
        binary (bool, optional): Binary big endian. Defaults to True.
        double_precision (bool, optional). Writes to binary file using double precision. Defaults to True
    """
    if binary
        f = open(filename,'w')
        write(f,Int32(length(blocks)))
        for b in blocks
            IMAX,JMAX,KMAX = b.X.shape
            write(f,Int32(IMAX))
            write(f,Int32(JMAX))
            write(f,Int32(KMAX))
        end
        for b in blocks
            WritePlot3DBlockBinary(f,b,double_precision)
        end
        close(f)
    else # ascii 
        f = open(filename,'w')
        @printf(f,"%d\n",length(blocks))

        for b in blocks
            IMAX,JMAX,KMAX = shape(b.X)
            @printf(f,"%d %d %d\n",IMAX,JMAX,KMAX)
        end
        for b in blocks
            WritePlot3DBlockASCII(f,b)
        end
    end
end