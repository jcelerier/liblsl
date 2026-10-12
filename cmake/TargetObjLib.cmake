# Create object library so all files are only compiled once
add_library(lslobj OBJECT
        ${lslsources}
#        ${lslheaders}  # Headers are added later using FILE_SET
)

# Set the includes/headers for the lslobj target
# Note: We cannot use the PUBLIC_HEADER property of the target,
#  because it flattens the include directories.
# Note: IME, this approach is less error prone than target_include_directories
target_sources(lslobj
    INTERFACE
        FILE_SET HEADERS  # special set name; implies TYPE.
        BASE_DIRS include
        FILES ${lslheaders}
)

# Link system libs
# (boost might be bundled or system)
target_link_libraries(lslobj PRIVATE lslboost Threads::Threads)
if(MINGW)
    target_link_libraries(lslobj PRIVATE bcrypt)
    # Clang targeting MinGW defines none of the macros Asio probes for threads, so it would fall back to null_thread.
    target_compile_definitions(lslobj PUBLIC ASIO_HAS_THREADS=1)
endif()
if(UNIX AND NOT APPLE)
    # check that clock_gettime is present in the stdlib, link against librt otherwise
    include(CheckSymbolExists)
    check_symbol_exists(clock_gettime time.h HAS_GETTIME)
    if(NOT HAS_GETTIME)
        target_link_libraries(lslobj PRIVATE rt)
    endif()
    if(LSL_DEBUGLOG)
        target_link_libraries(lslobj PRIVATE dl)
    endif()
elseif(WIN32)
    target_link_libraries(lslobj PRIVATE iphlpapi winmm mswsock ws2_32)
endif()

# Compiler settings
target_compile_definitions(lslobj
    PRIVATE
        LIBLSL_EXPORTS
        LOGURU_DEBUG_LOGGING=$<BOOL:${LSL_DEBUGLOG}>
    PUBLIC
        ASIO_NO_DEPRECATED
        $<$<CXX_COMPILER_ID:MSVC>:LSLNOAUTOLINK>  # don't use #pragma(lib) in CMake builds
)
if(WIN32)
    target_compile_definitions(lslobj
            PRIVATE
            _CRT_SECURE_NO_WARNINGS
            PUBLIC
            _WIN32_WINNT=${LSL_WINVER}
    )
    if(BUILD_SHARED_LIBS)
        #        set_target_properties(lslobj
        #            PROPERTIES
        #                WINDOWS_EXPORT_ALL_SYMBOLS ON
        #        )
    endif(BUILD_SHARED_LIBS)
endif()

# Compiler settings
target_compile_definitions(lslobj
    PRIVATE
        LIBLSL_EXPORTS
        LOGURU_DEBUG_LOGGING=$<BOOL:${LSL_DEBUGLOG}>
    PUBLIC
        ASIO_NO_DEPRECATED
        $<$<CXX_COMPILER_ID:MSVC>:LSLNOAUTOLINK>  # don't use #pragma(lib) in CMake builds
)
if(WIN32)
    target_compile_definitions(lslobj
            PRIVATE
            _CRT_SECURE_NO_WARNINGS
            PUBLIC
            _WIN32_WINNT=${LSL_WINVER}
    )
    if(BUILD_SHARED_LIBS)
        #        set_target_properties(lslobj
        #            PROPERTIES
        #                WINDOWS_EXPORT_ALL_SYMBOLS ON
        #        )
    endif(BUILD_SHARED_LIBS)
endif(WIN32)

# A static liblsl does not export its C API from whatever links it.
if(LSL_BUILD_STATIC)
    target_compile_definitions(lslobj PRIVATE LIBLSL_STATIC)
endif()

# Standalone Asio's extern "C" names equal Boost.Asio's (without its version namespace); keep ours apart.
target_compile_definitions(lslobj
    PUBLIC
        asio_detail_posix_thread_function=liblsl_asio_detail_posix_thread_function
        asio_signal_handler=liblsl_asio_signal_handler
)

# Bundled Asio, pugixml and loguru live in their own namespaces, so no other copy in the program can resolve against ours.
target_compile_definitions(lslobj PUBLIC asio=lsl_asio loguru=lsl_loguru $<$<BOOL:${LSL_BUNDLED_PUGIXML}>:pugi=lsl_pugi>)

# Link in 3rd party dependencies
# - loguru and asio header-only
target_include_directories(lslobj
    # Note: We use `SYSTEM` to suppress warnings from 3rd party headers and put these at the end of the include path.
    # Note: We use `PUBLIC` because 'internal tests' import individual source files and link lslobj.
    SYSTEM PUBLIC
        $<BUILD_INTERFACE:${CMAKE_CURRENT_SOURCE_DIR}/thirdparty/loguru>
        $<BUILD_INTERFACE:${CMAKE_CURRENT_SOURCE_DIR}/thirdparty/asio>
)
if(NOT LSL_OPTIMIZATIONS)
    # build one object file for Asio instead of once every time an Asio function is called. See
    # https://think-async.com/Asio/asio-1.18.2/doc/asio/using.html#asio.using.optional_separate_compilation
    target_sources(lslobj PRIVATE thirdparty/asio_objects.cpp)
    target_compile_definitions(lslobj
        PUBLIC
            ASIO_SEPARATE_COMPILATION
            ASIO_DISABLE_VISIBILITY
    )
endif()

# - pugixml
# Note: We use `PUBLIC` because 'internal tests' import individual source files and link lslobj.
if(LSL_BUNDLED_PUGIXML)
    target_sources(lslobj PRIVATE thirdparty/pugixml/pugixml.cpp)
    target_include_directories(lslobj
        PUBLIC
            $<BUILD_INTERFACE:${CMAKE_CURRENT_SOURCE_DIR}/thirdparty/pugixml>
    )
else()
    target_link_libraries(lslobj PUBLIC pugixml::pugixml)
endif()
