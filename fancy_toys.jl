# This is a collection of toys under the Yggdrasil tree for the good <s>kids</s>
# developers.  These utilities can be employed in builder files.

using BinaryBuilder, Pkg, LibGit2
# Note: if you only need `get_addable_spec`, just add the following line to your recipe
# instead of including this file.  This is reexported here for backward compatibility.
using BinaryBuilderBase: get_addable_spec, AbstractSource, SetupSource, DirectorySource
using Downloads

"""
    should_build_platform(platform) -> Bool

Return whether the tarballs for the given `platform` should be built.

This is useful when the builder has different platform-dependent elements
(sources, script, products, etc...) that make it hard to have a single
`build_tarballs` call.
"""
function should_build_platform(platform)
    # If you need inspiration for how to use this function, look at the builder
    # for Git:
    # https://github.com/JuliaPackaging/Yggdrasil/blob/c3e3c4a96c723306b4da23fc6d05f12995b21ed8/G/Git/build_tarballs.jl#L76-L93

    # Get the list of platforms requested from the command line.  This should be
    # the only argument not prefixed with "--".
    requested_platforms = filter(arg -> !occursin(r"^--.*", arg), ARGS)

    if isone(length(requested_platforms))
        # `requested_platforms` has only one element: the comma-separated list
        # of platform.  We'll run the platform only if it's in the list
        return any(platforms_match.(Ref(platform), split(requested_platforms[1], ",")))
    else
        # `requested_platforms` doesn't have only one element: if its length is
        # zero, no platform has been explicitely passed from the command line
        # and we we'll run all platforms, otherwise we don't know what to do, so
        # let's return false to be safe.
        return iszero(length(requested_platforms))
    end
end

struct AptPkgSource <: AbstractSource
    apt_sources::Vector{AptSource}
    keys::Vector{AptKey}
    pkg_specs::Vector{AptPkgSpec}
    selections::Vector{AptPkgSpec}
    target::String
end

AptPkgSource(apt_sources::Vector{AptSource}, keys::Vector{AptKey}, pkg_specs::Vector{AptPkgSpec}, target::String; selections = AptPkgSpec[]) = AptPkgSource(apt_sources, keys, pkg_specs, selections, target)

struct AptSource
    url::String
    dist::String
    components::Vector{String}
end

struct AptKey
    key_url::String
    fingerprint::String
end

struct AptPkgSpec
    apt_source::AptSource
    name::String
    version::Union{VersionNumber, Nothing}
    hash::Union{String, Nothing}
    depends::Vector{String}
    filename::Union{String, Nothing}
end

AptPkgSpec(name::String; version = nothing, hash = nothing, depends = String[], filename = nothing) = AptPkgSpec(name, version, hash, depends, filename)

function create_file_sources(apt_pkg_source::AptPkgSource; work_dir::String = tempname())::Vector{FileSource}
    pkg_specs = resolve(apt_pkg_source, work_dir)
    file_sources = [create_file_source(pkg_spec, apt_pkg_source, work_dir) for pkg_spec in pkg_specs]
    return file_sources
end

function generate_manifest(file_sources::Vector{FileSource})::String
    file_names = [file_source.filename for file_source in file_sources]
    return join(file_names, "\n")
end

function create_file_source(pkg_spec::AptPkgSpec, apt_pkg_source::AptPkgSource, work_dir::String)::FileSource
    url = create_url(pkg_spec.filename, pkg_spec.apt_source)
    temp_path = joinpath(work_dir, basename(pkg_spec.filename))
    download(url, temp_path)
    pkg_spec.hash = "" # TODO compute sha256
    rm(temp_path)
    return FileSource(url, pkg_spec.hash)
end

function resolve(apt_pkg_source::AptPkgSource, work_dir::String)::Vector{AptPkgSpec}
    # TODO verify(apt_pkg_source.keys)
    pkg_index = create_pkg_index(apt_pkg_source, work_dir)
    pkg_specs = resolve(apt_pkg_source, pkg_index)
    return pkg_specs
end

create_dist_url(rel_path::String, source::AptSource) = "$(source.url)/dists/$(source.dist)/$(rel_path)"
create_url(rel_path::String, source::AptSource) = "$(source.url)/$(rel_path)"

function resolve(apt_pkg_source::AptPkgSource, pkg_index::Dict{String,AptPkgSpec})::Vector{AptPkgSpec}
    # TODO find proper solution to constraint satisfaction problem given
    # * apt_pkg_source.pkg_specs
    # * apt_pkg_source.selections
    # * pkg_index
    # TODO Proper handling of a list of AptPkgSpec - do not just concatenate
    pkg_specs = AptPkgSpec[]
    for pkg_spec in apt_pkg_source.pkg_specs
        pkg_specs = vcat(pkg_specs, resolve(pkg_spec, pkg_index))
    end
    return pkg_specs
end

function resolve(pkg_spec::AptPkgSpec, pkg_index::Dict{String,AptPkgSpec})::Vector{AptPkgSpec}
    pkg_specs = AptPkgSpec[]
    for dep in pkg_spec.depends
        if !haskey(pkg_index, dep)
            debug "Skipping $dep - not found in pkg_index"
            continue
        end
        pkg_specs = vcat(pkg_specs, resolve(pkg_index[dep], pkg_index))
    end
    return pkg_specs
end

function create_pkg_index(apt_pkg_source::AptPkgSource, work_dir::String)::Dict{String,AptPkgSpec}
    release_url = create_dist_url("Release")
    release_path = joinpath(work_dir, basename(release_url))
    download(release_url, release_path)
    release_str = read(release_path, String)
    release_archs = match(r"^Architectures: (\w+( \w+)*)$"m, release_str)
    release_md5sums = eachmatch(r"^MD5Sum:\n((^\s+.+$\n)+)"m, release_str)
    release_packages = eachmatch(r"(^\s+(\w+)\s+(\w+)\s+([\.\w\/-]+\/Packages)$\n)+"sm, first(release_md5sums).captures[1])
    pkg_index = Dict{String,AptPkgSpec}()
    for release_arch in split(release_archs.captures[1], " ")
        release_arch_package = first(filter(p -> contains(p.captures[4], release_arch), collect(release_packages)))
        release_arch_packages_rel_path = release_arch_package.captures[4]
        release_arch_packages_path = joinpath(work_dir, release_arch_packages_rel_path)
        download(create_dist_url(release_arch_packages_rel_path), release_arch_packages_path)
        release_arch_packages_str = read(release_arch_packages_path, String)
        for pkg_spec_match in eachmatch(r"(^Package:.+$\n(^.+$\n)+)"m, release_arch_packages_str)
            pkg_name_match = match(r"(^Package: (?<name>.+)$\n)"m, pkg_spec_match.match)
            pkg_deps_match = match(r"(^Depends: (?<deps>.+)$\n)"m, pkg_spec_match.match)
            pkg_deps_match_str = pkg_deps_match !== nothing ? pkg_deps_match.captures[2] : ""
            pkg_deps_matches = [m.captures[2] for m in eachmatch(r"(([\w\-\+]+)(\s*\(([=<>]{1,2})\s*([^)]+)\))?)+(, )?"m, pkg_deps_match_str)]
            pkg_filename_match = match(r"(^Filename: (?<filename>.+)$\n)"m, pkg_spec_match.match)
            pkg_name = pkg_name_match.captures[2]
            pkg_filename = pkg_filename_match.captures[2]
            pkg_deps = pkg_deps_match !== nothing ? pkg_deps_match.captures[2] : ""
            pkg_spec = AptPkgSpec(pkg_name, pkg_deps_matches, pkg_filename)
            push!(pkg_index, pkg_name => pkg_spec)
        end
    end
    return pkg_index
end

function download_source(source::AptPkgSource; verbose::Bool = false, downloads_dir = storage_dir("downloads"))
    pkg_specs = resolve(apt_pkg_source, downloads_dir)
    install_manifest = generate_manifest(pkg_specs)

    for pkg_spec in pkg_specs
        download_with_retry(create_url(pkg_spec.rel_path, pkg_spec.apt_source), joinpath(downloads_dir, basename(pkg_spec.filename)))
    end
    @info "Writing install manifest to $(joinpath(src_path, "install.manifest"))"
    write(joinpath(downloads_dir, "install.manifest"), join(install_manifest, "\n"))

    follow_symlinks = false
    return SetupSource{DirectorySource}(abspath(src_path), "", source.target, follow_symlinks)
end

function download_with_retry(url, path)
    downloaded = false
    download_attempts = 0
    while !downloaded
        try
            download(url, path)
            downloaded = true
        catch
            if download_attempts < 3
                @warn "Download failed - retrying in three secs..."
                sleep(3)
                download_attempts = download_attempts + 1
            else
                throw
            end
        end
    end
end

function download(url, path)
    if isfile(path)
        @info "Cached file found in $(path)"
        return true
    else
        mkpath(dirname(path))
        @info "Downloading $(url) to $(path)..."
        
        rm(path; force=true)
        Downloads.download(url, path)
    end
end
