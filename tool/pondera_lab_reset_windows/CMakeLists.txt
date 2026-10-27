cmake_minimum_required(VERSION 3.20)

project(pondera_lab_reset_windows LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_CXX_EXTENSIONS OFF)
set(CMAKE_MSVC_RUNTIME_LIBRARY "MultiThreaded$<$<CONFIG:Debug>:Debug>")

add_library(pondera_reset_core STATIC
  src/reset_service.cpp
  src/windows_system_adapter.cpp
)

target_include_directories(pondera_reset_core PUBLIC src)
target_compile_definitions(pondera_reset_core PRIVATE UNICODE _UNICODE NOMINMAX)
target_compile_options(pondera_reset_core PRIVATE /W4 /permissive- /utf-8)
target_link_libraries(pondera_reset_core PRIVATE advapi32 shell32)

add_executable(pondera_lab_reset WIN32
  src/main.cpp
  src/app.rc
)

target_compile_definitions(pondera_lab_reset PRIVATE UNICODE _UNICODE NOMINMAX)
target_compile_options(pondera_lab_reset PRIVATE /W4 /permissive- /utf-8)
target_link_libraries(pondera_lab_reset PRIVATE pondera_reset_core comctl32)
target_link_options(pondera_lab_reset PRIVATE /MANIFEST:NO)

include(CTest)
if(BUILD_TESTING)
  add_executable(pondera_reset_tests tests/reset_service_test.cpp)
  target_compile_definitions(pondera_reset_tests PRIVATE UNICODE _UNICODE NOMINMAX)
  target_compile_options(pondera_reset_tests PRIVATE /W4 /permissive- /utf-8)
  target_link_libraries(pondera_reset_tests PRIVATE pondera_reset_core)
  add_test(NAME pondera_reset_tests COMMAND pondera_reset_tests)
endif()
