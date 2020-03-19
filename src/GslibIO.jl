# ------------------------------------------------------------------
# Licensed under the ISC License. See LICENCE in the project root.
# ------------------------------------------------------------------

module GslibIO

using FileIO
using Printf
using DelimitedFiles

using GeoStatsBase

"""
    load(file)

Load grid properties from `file`.
"""
function load(file::File{format"GSLIB"})
  open(file) do f
    fs = stream(f)

    # skip header
    skipchars(_ -> false, fs, linecomment='#')

    # read dimensions
    nx, ny, nz = parse.(Int,     split(readline(fs)))
    ox, oy, oz = parse.(Float64, split(readline(fs)))
    sx, sy, sz = parse.(Float64, split(readline(fs)))

    # read property names
    vars = Symbol.(split(readline(fs)))

    # read property values
    X = readdlm(fs)

    # create data dictionary
    data = OrderedDict([vars[j] => reshape(X[:,j], nx, ny, nz) for j in 1:size(X,2)])

    RegularGridData(data, (ox,oy,oz), (sx,sy,sz))
  end
end

"""
    load_legacy(filename, dims; origin=(0.,0.,0.), spacing=(1.,1.,1.))

Load legacy GSLIB `filename` into a grid with `dims`, `origin` and `spacing`.
"""
function load_legacy(filename::AbstractString, dims::NTuple{3,Int};
                     origin=(0.,0.,0.), spacing=(1.,1.,1.))
  open(filename) do fs
    # skip header
    readline(fs)

    # number of properties
    nvars = parse.(Int, readline(fs))

    # properties names
    vars = [Symbol(readline(fs)) for i in 1:nvars]

    # read property values
    X = readdlm(fs)

    # create data dictionary
    data = OrderedDict([vars[i] => reshape(X[:,i], dims) for i in 1:nvars])

    RegularGridData(data, origin, spacing)
  end
end

"""
    save(file, properties, propsize; [optional parameters])

Save 1D `properties`, which originally had 3D size `propsize`.
"""
function save(file::File{format"GSLIB"},
              properties::Vector{V}, propsize::Tuple;
              origin=(0.,0.,0.), spacing=(1.,1.,1.),
              header="", propnames="") where {T<:Real,V<:AbstractArray{T,1}}
  # default property names
  isempty(propnames) && (propnames = ["prop$i" for i=1:length(properties)])
  @assert length(propnames) == length(properties) "number of property names must match number of properties"

  # convert vector of names to a long string
  propnames = join(propnames, " ")

  # collect all properties in a big matrix
  P = hcat(properties...)

  open(file, "w") do f
    # write header
    write(f, "# This file was generated with GslibIO.jl\n")
    !isempty(header) && write(f, "#\n# "*header*"\n")

    # write dimensions
    write(f, @sprintf("%i %i %i\n", propsize...))
    write(f, @sprintf("%f %f %f\n", origin...))
    write(f, @sprintf("%f %f %f\n", spacing...))

    # write property name and values
    write(f, "$propnames\n")
    writedlm(stream(f), P, ' ')
  end
end

"""
    save(file, properties, [optional parameters])

Save 3D `properties` by first flattening them into 1D properties.
"""
function save(file::File{format"GSLIB"}, properties::Vector{A};
              kwargs...) where {T<:Real,A<:AbstractArray{T,3}}
  # sanity checks
  @assert length(Set(size.(properties))) == 1 "properties must have the same size"

  # retrieve grid size
  propsize = size(properties[1])

  # flatten and proceed with pipeline
  flatprops = [prop[:] for prop in properties]

  save(file, flatprops, propsize, kwargs...)
end

"""
    save(file, property)

Save single 3D `property` by wrapping it into a singleton collection.
"""
function save(file::File{format"GSLIB"},
              property::A; kwargs...) where {T<:Real,A<:AbstractArray{T,3}}
  save(file, [property]; kwargs...)
end

"""
    save(file, grid)

Save `grid` of type `RegularGridData` to file.
"""
function save(file::File{format"GSLIB"}, grid::RegularGridData{<:Any,3})
  propnames = sort(collect(keys(variables(grid))))
  properties = [vec(grid[propname]) for propname in propnames]
  save(file, properties, size(grid), origin=origin(grid),
       spacing=spacing(grid), propnames=propnames)
end

end
