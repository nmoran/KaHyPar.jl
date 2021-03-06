using BinaryProvider # requires BinaryProvider 0.3.0 or later
using Libdl

# Parse some basic command-line arguments
const verbose = "--verbose" in ARGS
const prefix = Prefix(get([a for a in ARGS if a != "--verbose"], 1, joinpath(@__DIR__, "usr")))

products = [
    LibraryProduct(prefix.path*"/boost/lib",["libboost_program_options"], :libboost_program_options),
    LibraryProduct(prefix.path*"/lib64", ["libkahypar"], :libkahypar)
]

#Download binaries from hosted location
bin_prefix = "https://github.com/jalving/KaHyParBuilder/releases/download/v1.0/"
# Listing of files generated by BinaryBuilder:
download_info = Dict(
    Linux(:x86_64, libc=:glibc, compiler_abi=CompilerABI(:gcc7)) => ("$bin_prefix/KaHyParBuilder.v1.0.0.x86_64-linux-gnu-gcc7.tar.gz", "9adfcd18ff54d6612a07ea440f55bc275e554826cb24767681081b5944ce08ef"),
)

custom_library = false
if haskey(ENV,"JULIA_KAHYPAR_LIBRARY_PATH")
    custom_products = [LibraryProduct(ENV["JULIA_KAHYPAR_LIBRARY_PATH"],["libkahypar"], :libkahypar)]
    #NOTE:  need to be able to find libboost program options
    poi = dlopen_e("libboost_program_options.so")
    if poi == C_NULL
        error("Could not find libboost_program_options.so")
    end

    if all(satisfied(p; verbose=verbose) for p in custom_products)
        products = custom_products
        custom_library = true
    else
        error("Could not install custom libraries from $(ENV["JULIA_KAHYPAR_LIBRARY_PATH"]) .\n To fall back to BinaryProvider call delete!(ENV,\"JULIA_KAHYPAR_LIBRARY_PATH\") and run build again.")
    end
end

#Download from repo
if !custom_library
    # Install unsatisfied or updated dependencies:
    unsatisfied = any(!satisfied(p; verbose=verbose) for p in products)
    dl_info = choose_download(download_info, platform_key_abi())
    if dl_info === nothing && unsatisfied
        # If we don't have a compatible .tar.gz to download, complain.
        # Alternatively, you could attempt to install from a separate provider,
        # build from source or something even more ambitious here.
        error("Your platform (\"$(Sys.MACHINE)\", parsed as \"$(triplet(platform_key_abi()))\") is not supported by this package!")
    end

    # If we have a download, and we are unsatisfied (or the version we're
    # trying to install is not itself installed) then load it up!
    if unsatisfied || !isinstalled(dl_info...; prefix=prefix)
        # Download and install binaries
        install(dl_info...; prefix=prefix, force=true, verbose=verbose)
    end
    #need to open libboost so KaHyPar will register as satisfied
    boost_p = products[1]
    dlopen_e(boost_p.dir_path*"/libboost_program_options.so")
end

#Open program options
# Write out a deps.jl file that will contain mappings for our products
#NOTE: isolate doesn't work because libboost needs to be open in this context to load kahypar
write_deps_file(joinpath(@__DIR__, "deps.jl"), products, verbose=verbose,isolate = false)
