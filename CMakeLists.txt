cmake_minimum_required(VERSION 3.10)

# Set the project name
project(MyProject)

# Add the executable
add_executable(MyExecutable main.cpp)

# Add the definition to suppress the warning
target_compile_definitions(MyExecutable PRIVATE _CRT_SECURE_NO_WARNINGS)

# Add other necessary compiler flags and source files here