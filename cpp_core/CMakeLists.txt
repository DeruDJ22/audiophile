cmake_minimum_required(VERSION 3.18)
project(kuroakai_audio VERSION 1.0.0 LANGUAGES C CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

# Configure Export Macro Symbol
add_definitions(-DKUROAKAI_EXPORTS)

# Source and Include Specifications
include_directories(
    ${CMAKE_CURRENT_SOURCE_DIR}/include
    ${FFMPEG_INCLUDE_DIR}
    ${MINIAUDIO_INCLUDE_DIR}
)

set(SOURCE_FILES
    src/kuroakai_engine.cpp
)

# Build Target: Shared Library for dart:ffi
add_library(kuroakai_audio SHARED ${SOURCE_FILES})

# Compiler Warnings & Optimization Flags
if(MSVC)
    target_compile_options(kuroakai_audio PRIVATE /W4 /O2 /EHsc)
else()
    target_compile_options(kuroakai_audio PRIVATE -Wall -Wextra -O3 -fPIC)
endif()

# Platform-Specific Audio Subsystem Linking
if(WIN32)
    # WASAPI / Multimedia Windows System Libraries
    target_link_libraries(kuroakai_audio PRIVATE
        ksuser
        winmm
        ole32
        avcodec
        avformat
        swresample
        avutil
    )
elseif(ANDROID)
    # Android NDK OpenSL ES / AAudio / Oboe System Libraries
    find_library(LOG_LIB log)
    find_library(AAUDIO_LIB aaudio)
    find_library(OPENSLES_LIB OpenSLES)
    
    target_link_libraries(kuroakai_audio PRIVATE
        ${LOG_LIB}
        ${AAUDIO_LIB}
        ${OPENSLES_LIB}
        avcodec
        avformat
        swresample
        avutil
    )
endif()

# Install Specs for Flutter Integration
install(TARGETS kuroakai_audio
    RUNTIME DESTINATION ${CMAKE_INSTALL_PREFIX}/bin
    LIBRARY DESTINATION ${CMAKE_INSTALL_PREFIX}/lib
    ARCHIVE DESTINATION ${CMAKE_INSTALL_PREFIX}/lib
)
