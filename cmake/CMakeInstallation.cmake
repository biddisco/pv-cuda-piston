string( TOLOWER "${PROJECT_NAME}" PROJECT_LOWER_NAME )
string( TOUPPER "${PROJECT_NAME}" PROJECT_UPPER_NAME )

#-----------------------------------------------------------------------------
# Add Target(s) to CMake Install for import into other projects
#-----------------------------------------------------------------------------
if (NOT (${PROJECT_NAME}_IS_SUBPROJECT OR ${PROJECT_NAME}_EXTERNALLY_CONFIGURED))
  install (
      EXPORT ${${PROJECT_NAME}_EXPORTED_TARGETS}
      DESTINATION ${${PROJECT_NAME}_INSTALL_CMAKE_DIR}/${${PROJECT_NAME}_PACKAGE}
      FILE ${${PROJECT_NAME}_PACKAGE}-targets.cmake
      COMPONENT configinstall
  )
endif ()

#-----------------------------------------------------------------------------
# Export all exported targets to the build tree for use by parent project
#-----------------------------------------------------------------------------
#if (NOT (${PROJECT_NAME}_IS_SUBPROJECT OR ${PROJECT_NAME}_EXTERNALLY_CONFIGURED))
  EXPORT (
      TARGETS ${${PROJECT_NAME}_LIBRARIES_TO_EXPORT} ${${PROJECT_NAME}_LIB_DEPENDENCIES}
      FILE ${PROJECT_BINARY_DIR}/${PROJECT_NAME}-targets.cmake
  )
#endif ()

#-----------------------------------------------------------------------------
# The generated config file will use these vars for substitution
# we only make copies of the vars so the project-name can be substituted
# and the templates for generated files can be mostly copied between projects
#-----------------------------------------------------------------------------
set (PROJECT_PACKAGE_NAME        ${${PROJECT_UPPER_NAME}_PACKAGE})
set (PROJECT_VERSION_MAJOR       ${${PROJECT_UPPER_NAME}_VERSION_MAJOR})
set (PROJECT_VERSION_MINOR       ${${PROJECT_UPPER_NAME}_VERSION_MINOR})
set (PROJECT_VERSION_RELEASE     ${${PROJECT_UPPER_NAME}_VERSION_RELEASE})
set (PROJECT_VERSION_STRING      ${${PROJECT_UPPER_NAME}_PACKAGE_STRING})
set (PROJECT_LIBRARIES_TO_EXPORT ${${PROJECT_UPPER_NAME}_LIBRARIES_TO_EXPORT})

#-----------------------------------------------------------------------------
# Generate the project-config file in the BUILD directory
#-----------------------------------------------------------------------------
configure_file (
    ${CMAKE_CURRENT_LIST_DIR}/config.cmake.build.in 
    ${PROJECT_BINARY_DIR}/${PROJECT_LOWER_NAME}-config.cmake
)

#-----------------------------------------------------------------------------
# Configure the project-config-version.cmake file in the build directory
#-----------------------------------------------------------------------------
#if (NOT ${PROJECT_NAME}_EXTERNALLY_CONFIGURED)
  configure_file (
     ${CMAKE_CURRENT_LIST_DIR}/config-version.cmake.in
       ${PROJECT_BINARY_DIR}/${PROJECT_LOWER_NAME}-config-version.cmake @ONLY
  )
  install (
      FILES  ${PROJECT_BINARY_DIR}/CMakeFiles/${PROJECT_LOWER_NAME}-config-version.cmake
      DESTINATION ${${PROJECT_NAME}_INSTALL_CMAKE_DIR}/${${PROJECT_NAME}_PACKAGE}
      COMPONENT configinstall
  )
#endif (NOT ${PROJECT_NAME}_EXTERNALLY_CONFIGURED)


#-----------------------------------------------------------------------------
# Configure the project-config.cmake file for the INSTALL directory
#-----------------------------------------------------------------------------
#if (NOT ${PROJECT_NAME}_EXTERNALLY_CONFIGURED)
  # create a temporary file with all substitutions
#  configure_file (
#     ${CMAKE_CURRENT_LIST_DIR}/config.cmake.install.in
#       ${PROJECT_BINARY_DIR}/CMakeFiles/${PROJECT_LOWER_NAME}-config.cmake
#  )
  # createa rule to install the temp file
#  install (
#      FILES  ${PROJECT_BINARY_DIR}/CMakeFiles/${${PROJECT_NAME}_PACKAGE}-config.cmake
#      DESTINATION ${${PROJECT_NAME}_INSTALL_CMAKE_DIR}/${${PROJECT_NAME}_PACKAGE}
#      COMPONENT configinstall
#  )
#endif (NOT ${PROJECT_NAME}_EXTERNALLY_CONFIGURED)

#-----------------------------------------------------------------------------
# Configure the project-config-version .cmake file for the INSTALL directory
#-----------------------------------------------------------------------------
#if (NOT ${PROJECT_NAME}_EXTERNALLY_CONFIGURED)
#  configure_file (
#     ${CMAKE_CURRENT_LIST_DIR}/config-version.cmake.in
#       ${PROJECT_BINARY_DIR}/CMakeFiles/${PROJECT_NAME}-config-version.cmake @ONLY
#  )
#  install (
#      FILES  ${PROJECT_BINARY_DIR}/CMakeFiles/${PROJECT_NAME}-config-version.cmake
#      DESTINATION ${${PROJECT_NAME}_INSTALL_CMAKE_DIR}/${${PROJECT_NAME}_PACKAGE}
#      COMPONENT configinstall
#  )
#endif (NOT ${PROJECT_NAME}_EXTERNALLY_CONFIGURED)


