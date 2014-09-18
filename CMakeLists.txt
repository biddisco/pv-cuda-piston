project("pv_cuda_piston")

#--------------------------------------------------
# cmake old/new compatibility
#--------------------------------------------------
cmake_minimum_required(VERSION 2.8)

#--------------------------------------------------
# cmake policies
# see http://www.cmake.org/cmake/help/v2.8.12/cmake.html#section_Policies
#--------------------------------------------------
foreach(p
    CMP0003 
    CMP0017 
    CMP0023 
    )
  if(POLICY ${p})
    cmake_policy(SET ${p} NEW)
  endif()
endforeach()

#-----------------------------------------------------------------------------
# Basic naming/config stuff here
#-----------------------------------------------------------------------------
set(pv_cuda_piston_VERS_MAJOR   0)
set(pv_cuda_piston_VERS_MINOR   9)
set(pv_cuda_piston_VERS_RELEASE 0)

set (pv_cuda_piston_PACKAGE                "pv_cuda_piston")
set (pv_cuda_piston_PACKAGE_NAME           "pv_cuda_piston")
set (pv_cuda_piston_PACKAGE_VERSION        "${pv_cuda_piston_VERS_MAJOR}.${pv_cuda_piston_VERS_MINOR}.${pv_cuda_piston_VERS_RELEASE}")
set (pv_cuda_piston_PACKAGE_VERSION_MAJOR  "${pv_cuda_piston_VERS_MAJOR}.${pv_cuda_piston_VERS_MINOR}")
set (pv_cuda_piston_PACKAGE_VERSION_MINOR  "${pv_cuda_piston_VERS_RELEASE}")
set (pv_cuda_piston_PACKAGE_VERSION_STRING "${pv_cuda_piston_PACKAGE_VERSION}")
set (pv_cuda_piston_PACKAGE_SOVERSION      "${pv_cuda_piston_SOVERS_MAJOR}.${pv_cuda_piston_SOVERS_RELEASE}.${pv_cuda_piston_SOVERS_MINOR}")
set (pv_cuda_piston_PACKAGE_STRING         "${pv_cuda_piston_PACKAGE_NAME} ${pv_cuda_piston_PACKAGE_VERSION_STRING}")
set (pv_cuda_piston_PACKAGE_TARNAME        "${pv_cuda_piston_PACKAGE}")
set (pv_cuda_piston_PACKAGE_URL            "http://www.cscs.ch")
set (pv_cuda_piston_PACKAGE_BUGREPORT      "help@cscs.ch")

#--------------------------------------------------
# Location of cmake files
#--------------------------------------------------
SET(CMAKE_MODULE_PATH ${CMAKE_MODULE_PATH} "${CMAKE_CURRENT_SOURCE_DIR}/cmake")

#--------------------------------------------------
# Find and Use ParaView
#--------------------------------------------------
IF (ParaView_SOURCE_DIR)
  IF(PARAVIEW_BUILD_QT_GUI)
    INCLUDE(${QT_USE_FILE})
  ENDIF(PARAVIEW_BUILD_QT_GUI)
  include_directories(
    ${PARAVIEW_INCLUDE_DIRS}
    ${PARAVIEW_GUI_INCLUDE_DIRS}
    ${VTK_INCLUDE_DIR}
  )
ELSE (ParaView_SOURCE_DIR)
  FIND_PACKAGE(ParaView REQUIRED)
  INCLUDE(${PARAVIEW_USE_FILE})
ENDIF (ParaView_SOURCE_DIR)

# --------------------------------------------------------------
# Optional Boost : until we solve tuple issue on mac
#
# Mac OSX : compilation
# Mac clang requires -stdlib=libc++ for #include <tuple>
# Mac cuda  requires -stdlib=libstdc++ 
# Therefore, use boost::tuple and compile paraview with -stdlib=libstdc++ 
# --------------------------------------------------------------
if (APPLE) 
# AND CMAKE_CXX_COMPILER MATCHES ".*clang")
  set(BOOST_TUPLE_DEFAULT ON)
else()
  set(BOOST_TUPLE_DEFAULT OFF)
endif ()

option(PV_CUDA_PISTON_USE_BOOST_TUPLE "Use boost::tuple instead of std::tuple" ${BOOST_TUPLE_DEFAULT})
if(PV_CUDA_PISTON_USE_BOOST_TUPLE)
  OPTION(Boost_USE_FIND_NO_MODULE "If cmake installed boost, use NO_MODULE in find package" OFF)
  if(Boost_USE_FIND_NO_MODULE)
    find_package(Boost NO_MODULE)
  else(Boost_USE_FIND_NO_MODULE)
    find_package(Boost 1.41.0)
  endif(Boost_USE_FIND_NO_MODULE)

  include_directories(
    ${Boost_INCLUDE_DIR}
    ${Boost_INCLUDE_DIRS}
  )
  add_definitions(-DPV_CUDA_PISTON_USE_BOOST_TUPLE)
endif()

#--------------------------------------------------
# Set project include directories
#--------------------------------------------------
include_directories(
  "${PROJECT_SOURCE_DIR}"
  "${PROJECT_BINARY_DIR}"
)

#--------------------------------------------------
# Find CUDA and Thrust
#--------------------------------------------------
find_package(CUDA REQUIRED)
find_package(CUDAThrust REQUIRED)

if (WIN32 AND ${CUDA_VERSION} VERSION_LESS "5.5")
  set(NEED_PATH_HACK_FOR_VISUAL_STUDIO 1)
  message("set(NEED_PATH_HACK_FOR_VISUAL_STUDIO 1)")
endif()

include_directories(${CUDATHRUST_INCLUDE_DIRS})

#--------------------------------------------------
# Find piston header library
#--------------------------------------------------
find_path(PISTON_INCLUDE
  PistonCodingStyle.xml
  "${CMAKE_CURRENT_SOURCE_DIR}/piston"
  DOC "PISTON library's root source directory where PistonCodingStyle.xml can be found")

if(NOT PISTON_INCLUDE)
  message(FATAL_ERROR "pv-cuda-piston requires PISTON headers")
endif()

add_definitions(-DPV_CUDA_PISTON_USE_PISTON)

# the dll export flag added by cmake is not passed to NVCC, so
# we will add it manually here
add_definitions(-Dpv_cuda_piston_EXPORTS)

include_directories(
  ${PISTON_INCLUDE}
  ${CMAKE_CURRENT_SOURCE_DIR}/piston
)

#--------------------------------------------------
# optional build of representation classes 
#--------------------------------------------------
option(PV_CUDA_PISTON_BUILD_REPRESENTATION "Build special representations for transparent depth sorting" ON)
if(PV_CUDA_PISTON_BUILD_REPRESENTATION)

  #--------------------------------------------------
  # pv-zoltan : Required for depth sort
  #--------------------------------------------------
  find_package(pv_zoltan NO_MODULE REQUIRED)
  if(NOT pv_zoltan_FOUND)
    message(FATAL_ERROR "pv-cuda-piston requires pv_zoltan")
  endif()
  include_directories(${pv_zoltan_INCLUDE_DIR})
 
endif()
#--------------------------------------------------
# OBSOLETE : SUPPORT OLD CUDA ON WINDOWS
# module definitions we'll need for piston flags/cuda etc
#--------------------------------------------------
#include(vtkModuleMacros)
#
#if(MSVC AND NEED_PATH_HACK_FOR_VISUAL_STUDIO)
#  # generate the list of dependencies based on our module definition file
#  vtk_module_impl()
#
#  # remove a bunch of cruft that VTK adds in here about modules autoinit
#  # first get the old setting and store it
#  get_directory_property(TEMP_include_directories include_directories)
#  get_directory_property(TEMP_COMPILE_DEFINITIONS COMPILE_DEFINITIONS)
#  # clear compile defs 
#  set_directory_properties(PROPERTIES COMPILE_DEFINITIONS "")
#  # shorten the include dirs so nvcc doesn't crumble under the entire VTK/ParaView/Qt path
#  set_directory_properties(PROPERTIES include_directories "${${vtk-module}_DEPENDS_INCLUDE_DIRS};${PISTON_INCLUDE}")
#endif(MSVC AND NEED_PATH_HACK_FOR_VISUAL_STUDIO)

#--------------------------------------------------
# Define sources using PISTON 
#--------------------------------------------------
set(CUDA_PISTON_SRCS
  vtkDataSetToPiston.cxx
  vtkPistonAlgorithm.cxx
  vtkPistonDataObject.cxx
  vtkPistonPolygonsPainter.cxx
  vtkCUDAPiston.cxx
)

#--------------------------------------------------
# Define CUDA compiled source files
#--------------------------------------------------
set(CUDA_PISTON_CUDA_SRCS
  vtkPistonConverters.cu
  vtkPistonMapper.cu
)

#--------------------------------------------------
# Create a single library containing all the cuda compiled code
#--------------------------------------------------
# set this, otherwise C_SOURCES is empty in Visual Studio  
set(CUDA_ATTACH_VS_BUILD_RULE_TO_CUDA_FILE OFF) 

# call the cuda wrapper
cuda_add_library(pv_cuda_piston_culib ${CUDA_PISTON_CUDA_SRCS} STATIC)

#--------------------------------------------------
# OBSOLETE : SUPPORT OLD CUDA ON WINDOWS
# put the include dirs back to what they were
#--------------------------------------------------
#if(MSVC AND NEED_PATH_HACK_FOR_VISUAL_STUDIO)
#  # put the include dirs back to what they were
#  set_directory_properties(PROPERTIES include_directories "${TEMP_include_directories}")
#  set_directory_properties(PROPERTIES COMPILE_DEFINITIONS "${TEMP_COMPILE_DEFINITIONS}")
#endif(MSVC AND NEED_PATH_HACK_FOR_VISUAL_STUDIO)

#------------------------------------------------------
# MPI support
#------------------------------------------------------
IF (PARAVIEW_USE_MPI)
  FIND_PACKAGE(MPI)   
  include_directories(${MPI_INCLUDE_PATH})
ELSE (PARAVIEW_USE_MPI)

ENDIF (PARAVIEW_USE_MPI)

# --------------------------------------------------
# Plugin config
# --------------------------------------------------
set(XML_PATH   "${CMAKE_CURRENT_SOURCE_DIR}")
set(SRC_PATH   "${CMAKE_CURRENT_SOURCE_DIR}")

if(PV_CUDA_PISTON_BUILD_REPRESENTATION)
  set(DEPTH_SORT_CODE 
    ${CMAKE_CURRENT_SOURCE_DIR}/vtkDepthSortRepresentation.cxx
  )
  set(ZOLTAN_LIBS pv_zoltan)
  set(DEPTH_SORT_XML 
    ${XML_PATH}/vtkDepthSortRepresentation.xml
  )
endif()

#--------------------------------------------------
# Define plugin sources
#--------------------------------------------------
SET(PLUGIN_NAME ${PROJECT_NAME})
ADD_PARAVIEW_PLUGIN(
  ${PLUGIN_NAME}
  "1.0" 

  SERVER_MANAGER_XML
    ${DEPTH_SORT_XML}

  SERVER_MANAGER_SOURCES
    ${CMAKE_CURRENT_SOURCE_DIR}/vtkDepthSortDefaultPainter.cxx
    ${CMAKE_CURRENT_SOURCE_DIR}/vtkDepthSortPainter.cxx
    ${CMAKE_CURRENT_SOURCE_DIR}/vtkDepthSortPolyData2.cxx
    ${CMAKE_CURRENT_SOURCE_DIR}/vtkDepthSortPolygonsPainter.cxx
    ${CMAKE_CURRENT_SOURCE_DIR}/vtkTwoScalarsToColorsPainter.cxx
    ${DEPTH_SORT_CODE}

  SERVER_SOURCES
    ${CUDA_PISTON_SRCS}
  #  ${CUDA_PISTON_CUDA_C_SRCS}

  GUI_INTERFACES 
    ${ZOLTAN_IFACE}

  GUI_SOURCES
    ${ZOLTAN_IFACE_SRCS}
    ${ZOLTAN_MOC_SRCS}
    ${ZOLTAN_UI_SOURCES}

  GUI_RESOURCE_FILES
#    ${XML_PATH}/pv_cuda_piston_Filters.xml
)

if(CMAKE_COMPILER_IS_GNUCXX AND NOT PV_CUDA_PISTON_USE_BOOST_TUPLE)
  message("Adding C++Ox flag for Depth Sort")
  set_source_files_properties(${CMAKE_CURRENT_SOURCE_DIR}/vtkDepthSortPolyData2.cxx PROPERTIES COMPILE_FLAGS "-std=c++0x")
endif()

#--------------------------------------------------
# setup plugin linking
#--------------------------------------------------
TARGET_LINK_LIBRARIES(${PLUGIN_NAME} 
  PUBLIC
    vtksys
    ${ZOLTAN_LIBS}
    pv_cuda_piston_culib
    ${CUDA_LIBRARIES}
)

#--------------------------------------------------------
# Create the module import/export configuration header.
#--------------------------------------------------------
CONFIGURE_FILE(${PROJECT_SOURCE_DIR}/module_configure.h.in
               ${PROJECT_BINARY_DIR}/pv_cuda_piston_configure.h
               @ONLY IMMEDIATE)

#-----------------------------------------------------------------------------
# Configure the project-config.cmake file for the build directory
#-----------------------------------------------------------------------------
set (${PROJECT_NAME}_INCLUDES_BUILD_TIME
  "${PROJECT_SOURCE_DIR}"
  "${PROJECT_BINARY_DIR}"
  "${PROJECT_SOURCE_DIR}/piston"
  "${pv_zoltan_INCLUDE_DIR}"
  "${CUDATHRUST_INCLUDE_DIRS}"
  "${PISTON_INCLUDE}"
)
include(CMakeInstallation)

#--------------------------------------------------
# Install
#--------------------------------------------------
SET(INSTALL_PATH 
  "${CMAKE_INSTALL_PREFIX}/lib/paraview-${PARAVIEW_VERSION_MAJOR}.${PARAVIEW_VERSION_MINOR}"
)

INSTALL(
  TARGETS 
    ${PLUGIN_NAME}
  DESTINATION ${INSTALL_PATH}
)
