cmake_minimum_required(VERSION 3.18)
project(kuroakai_audio VERSION 1.0.0 LANGUAGES C CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

# Configure Export Macro Symbol
add_definitions(-DKUROAKAI_EXPORTS)

# Source and Include Specifications
include_directories(
    ${CMAKE_CURRENT_SOURCE_DIR}/include
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
    )
elseif(ANDROID)
    # Android NDK System Libraries
    find_library(LOG_LIB log)
    find_library(OPENSLES_LIB OpenSLES)
    find_library(AAUDIO_LIB aaudio)

    set(ANDROID_LIBS ${LOG_LIB} ${OPENSLES_LIB})
    if(AAUDIO_LIB)
        list(APPEND ANDROID_LIBS ${AAUDIO_LIB})
    endif()

    target_link_libraries(kuroakai_audio PRIVATE
        ${ANDROID_LIBS}
    )
endif()

# Install Specs for Flutter Integration
install(TARGETS kuroakai_audio
    RUNTIME DESTINATION ${CMAKE_INSTALL_PREFIX}/bin
    LIBRARY DESTINATION ${CMAKE_INSTALL_PREFIX}/lib
    ARCHIVE DESTINATION ${CMAKE_INSTALL_PREFIX}/lib
)
