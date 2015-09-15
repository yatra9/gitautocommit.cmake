cmake_policy(SET CMP0011 NEW)
cmake_policy(SET CMP0007 NEW)
cmake_policy(SET CMP0012 NEW)

if (NOT DEFINED prebuild AND NOT DEFINED postbuild)
  # included
  
  include(CMakeParseArguments)

  set(GIT_AUTOCOMMIT_CMAKESCRIPT ${CMAKE_CURRENT_LIST_FILE}
     CACHE INTERNAL "this script")

  function(GIT_AUTOCOMMIT target)
    set(VAR_PREFIX "GIT_AUTOCOMMIT")
    set(cache_vars
        GITEXE advanced "" "/path/to/git"
        CONFIGF_FROM noarg "" "configure_file from"
        CONFIGF_TO noarg "" "configure_file to"
        CONFIGF_ARGN noarg "" "configure_file argn"
        CONFIGURE_ONLY noarg 0 "only configure_file"
        AUTHORTEMPLATE usual "automatic commit (@CONF_AUTHOR_NAME@) <@CONF_AUTHOR_EMAIL@>"
                "author of commit message (use @CONF_AUTHOR_NAME@ and @CONF_AUTHOR_EMAIL@)"
        AUTOGENBRANCH_NAMETEMPLATE usual "autogen/@CURRENT_BRANCH_NAME@/@BRANCH_N@"
                "auto-generated branch name template (use @CURRENT_BRANCH_NAME@ and @BRANCH_N@)"
        COMMIT_MESSAGE usual "auto commit" "commit message"
        GIT_REPOSITORY usual ${CMAKE_CURRENT_SOURCE_DIR} "git repository"
        AUTOGENBRANCH_STARTNUM advanced 0 "start number of auto-generated branch name"
        AUTOGENBRANCH_MATCHREGEX advanced ""
                "regex expression that maches auto-generated brancehs (or empty string for automatic guess)"
        MESSAGE_PREFIX advanced "git-autocommit: " "message prefix"
       )
    list(LENGTH cache_vars cache_vars_len)
    math(EXPR cache_vars_len0 "${cache_vars_len}-1")

    set(options "CONFIGURE_ONLY")
    set(oneValueArgs "")
    set(multiValueArgs CONFIGURE_FILE)
    foreach(i RANGE 0 ${cache_vars_len0} 4)
      list(GET cache_vars ${i} varname)
      math(EXPR ip "${i}+1")
      list(GET cache_vars ${ip} varkind)
      if (NOT "${varkind}" STREQUAL "noarg")
        list(APPEND oneValueArgs ${varname})
      endif()
    endforeach()
    cmake_parse_arguments(${VAR_PREFIX} "${options}" "${oneValueArgs}" "${multiValueArgs}" ${ARGN} )
    
    # set GITEXE
    set(var_GITEXE "${VAR_PREFIX}_GITEXE")
    if ("${${var_GITEXE}}" STREQUAL "")
      find_package(Git QUIET)
      if(NOT GIT_FOUND)
        message(FATAL_ERROR "git not found")
      endif()
      set(${var_GITEXE} ${GIT_EXECUTABLE})
    endif()
    
    # set CONFIGF_FROM, CONFIGF_TO, and CONFIGF_ARGN
    set(var_CONFIGURE_FILE "${VAR_PREFIX}_CONFIGURE_FILE")
    set(var_CONFIGF_FROM "${VAR_PREFIX}_CONFIGF_FROM")
    set(var_CONFIGF_TO "${VAR_PREFIX}_CONFIGF_TO")
    set(CONFIGURE_FILE ${${var_CONFIGURE_FILE}})
    message("CONFIGURE_FILE=[${CONFIGURE_FILE}]")
    list(LENGTH CONFIGURE_FILE var_CONFIGURE_FILE_len)
    if (var_CONFIGURE_FILE_len LESS 2)
      message(FATAL_ERROR "syntax error!! CONFIGURE_FILE needs at least 2 arguments")
    endif()
    list(GET CONFIGURE_FILE 0 cf_from0)
    list(GET CONFIGURE_FILE 1 cf_to0)
    list(REMOVE_AT CONFIGURE_FILE 0 1)
    set("${VAR_PREFIX}_CONFIGF_ARGN" "\"${CONFIGURE_FILE}\"")
    # retrive abstract paths (emulate configure_file)
    if(NOT IS_ABSOLUTE ${cf_from0})
      get_filename_component(cf_from0 "${CMAKE_CURRENT_SOURCE_DIR}/${cf_from0}" ABSOLUTE)
    endif()
    set(${var_CONFIGF_FROM} ${cf_from0})
    if(NOT IS_ABSOLUTE ${cf_to0})
      get_filename_component(cf_to0 "${CMAKE_CURRENT_BINARY_DIR}/${cf_to0}" ABSOLUTE)
    endif()
    if(IS_DIRECTORY ${cf_to0})
      get_filename_component(cf_fromn ${${var_CONFIGF_FROM}} NAME)
      get_filename_component(cf_to0 "${cf_to0}/${cf_fromn}" ABSOLUTE)
    endif()
    set(${var_CONFIGF_TO} ${cf_to0})
    
    
    set(comargs "")
    foreach(i RANGE 0 ${cache_vars_len0} 4)
      list(GET cache_vars ${i} varname0)
      set(varname "${VAR_PREFIX}_${varname0}")
      math(EXPR ip "${i}+1")
      list(GET cache_vars ${ip} varkind)
      math(EXPR ip2 "${i}+2")
      list(GET cache_vars ${ip2} vardefault)
      math(EXPR ip3 "${i}+3")
      list(GET cache_vars ${ip3} vardoc)
      if ("${${varname}}" STREQUAL "")
        set(${varname} "${vardefault}")
      endif()
      if ("${varkind}" STREQUAL "noarg")
        set(${varname} ${${varname}} CACHE INTERNAL "${vardoc}")
      else()
        set(${varname} ${${varname}} CACHE STRING "${vardoc}")
        if (NOT "${varkind}" STREQUAL "usual")
          mark_as_advanced(${varname})
        endif()
      endif()
      set(${varname0} $CACHE{${varname}})
      list(APPEND comargs -D${varname0}=${${varname0}})
      if (CONFIGURE_ONLY)
        break()
      endif()
    endforeach()
    message("comargs=[${comargs}]")

    set(prebuild_target "gitautocommit_prebuild_${target}")
    set(comment_mes "${MESSAGE_PREFIX}check git status on ${GIT_REPOSITORY}")
    add_custom_target(${prebuild_target}
                       COMMAND ${CMAKE_COMMAND} -Dprebuild=ON ${comargs}
                           -P ${GIT_AUTOCOMMIT_CMAKESCRIPT}
                       COMMENT "${comment_mes}"
                       WORKING_DIRECTORY ${GIT_REPOSITORY}
                       VERBATIM)
                       
    set_target_properties(${prebuild_target} PROPERTIES EchoString "${comment_mes}")
    add_dependencies(${target} ${prebuild_target})

  endfunction()

elseif(DEFINED prebuild)
  # must be set ${GITEXE} ${AUTOGENBRANCH_STARTNUM} ${AUTOGENBRANCH_NAMETEMPLATE} ${COMMIT_MESSAGE} ${MESSAGE_PREFIX}
  # optional ${AUTHORTEMPLATE} ${AUTOGENBRANCH_MATCHREGEX} ${CONFIGURE_ONLY} ${CONFIGF_FROM} ${CONFIGF_TO} ${CONFIGF_ARGN}

  # place-holders for templates
  set(phBRANCH_N "BRANCH_N")
  set(phCURRENT_BRANCH_NAME "CURRENT_BRANCH_NAME")
  set(phCURRENT_BRANCH_FULL_NAME "CURRENT_BRANCH_FULL_NAME")

  set(phCONF_AUTHOR_NAME "CONF_AUTHOR_NAME")
  set(phCONF_AUTHOR_EMAIL "CONF_AUTHOR_EMAIL")

  set(phGIT_COMMIT_SHA "GIT_COMMIT_SHA")


  macro(execute_git)
    execute_process(COMMAND ${GITEXE} ${ARGN}
                    RESULT_VARIABLE comres
                    OUTPUT_VARIABLE comout0
                    ERROR_VARIABLE comerr0)
    string(STRIP "${comout0}" comout)
    string(STRIP "${comerr0}" comerr)
  endmacro()

  function(is_autogen_branch branchname result)
    if (DEFINED AUTOGENBRANCH_MATCHREGEX AND NOT AUTOGENBRANCH_MATCHREGEX STREQUAL "")
      set(matchstring "${AUTOGENBRANCH_MATCHREGEX}")
    else()
      if (NOT "${AUTOGENBRANCH_NAMETEMPLATE}" MATCHES "^${AUTOGENBRANCH_NAMETEMPLATE}$")
        # ${AUTOGENBRANCH_NAMETEMPLATE} contains special regex characters
        # TODO: FIX me
        message(FATAL_ERROR "${MESSAGE_PREFIX}invalid character(s) in branch name template \"${AUTOGENBRANCH_NAMETEMPLATE}\". set variable AUTOGENBRANCH_MATCHREGEX")
      endif()
      set(${phBRANCH_N} "[0-9]+")
      set(${phCURRENT_BRANCH_NAME} ".*")
      set(${phCURRENT_BRANCH_FULL_NAME} ".*")
      string(CONFIGURE ${AUTOGENBRANCH_NAMETEMPLATE} matchstring)
    endif()
    if (branchname MATCHES "^${matchstring}$")
      set(${result} 1 PARENT_SCOPE)
    else()
      set(${result} 0 PARENT_SCOPE)
    endif()
  endfunction()

  function(autocommit_author tmpt result)
    if (tmpt MATCHES "@${phCONF_AUTHOR_NAME}@")
      execute_git(config --get user.name)
      set(${phCONF_AUTHOR_NAME} "${comout}")
    endif()
    if (tmpt MATCHES "@${phCONF_AUTHOR_EMAIL}@")
      execute_git(config --get user.email)
      set(${phCONF_AUTHOR_EMAIL} "${comout}")
    endif()
    string(CONFIGURE "${tmpt}" res @ONLY)
    set(${result} ${res} PARENT_SCOPE)
  endfunction()

  execute_git(rev-parse HEAD)
  if (NOT ${comres} EQUAL 0)
    message(FATAL_ERROR "${MESSAGE_PREFIX}${comerr}")
  endif()
  set(${phGIT_COMMIT_SHA} "${comout}")

  execute_git(status -s -uall)
  if (NOT ${comres} EQUAL 0)
    message(FATAL_ERROR "${MESSAGE_PREFIX}${comerr}")
  endif()
  set(statusout "${comout}")
  
  if (NOT "${CONFIGURE_ONLY}" AND NOT statusout STREQUAL "")
    #message(STATUS "process automatic commit")
    
    # obtain current branch name
    execute_git(symbolic-ref --short HEAD)
    if (NOT ${comres} EQUAL 0)
      message(FATAL_ERROR "${MESSAGE_PREFIX}could not identify current branch (you are in remote tracking branchs, tag, detached HEAD, etc...?)")
    endif()
    set(${phCURRENT_BRANCH_NAME} "${comout}")

    execute_git(symbolic-ref HEAD)
    if (NOT ${comres} EQUAL 0)
      message(FATAL_ERROR "${MESSAGE_PREFIX}could not identify current branch (you are in remote tracking branchs, tag, detached HEAD, etc...?)")
    endif()
    set(${phCURRENT_BRANCH_FULL_NAME} "${comout}")

    # determine whether or not we are already in auto-generated branch
    is_autogen_branch(${${phCURRENT_BRANCH_NAME}} comres)
    if (${comres} EQUAL 0)
      # determine new branch name
      set(${phBRANCH_N} ${AUTOGENBRANCH_STARTNUM})
      while(1)
        string(CONFIGURE ${AUTOGENBRANCH_NAMETEMPLATE} new_branchname @ONLY)
        execute_git(rev-parse -q --verify ${new_branchname})
        if (NOT ${comres} EQUAL 0)
          break()
        endif()
        math(EXPR ${phBRANCH_N} "${${phBRANCH_N}}+1")
      endwhile()
      
      #create and checkout new branch
      message(STATUS "${MESSAGE_PREFIX}create new branch ${new_branchname}")
      # tracking to local branch requires full-ref branch name for git version < 2.3.0
      execute_git(checkout -b ${new_branchname} --track ${${phCURRENT_BRANCH_FULL_NAME}})
      if (NOT ${comres} EQUAL 0)
        message(FATAL_ERROR "${MESSAGE_PREFIX}git checkout -b failed: ${comerr}")
      endif()
      set(${phCURRENT_BRANCH_NAME} ${new_branchname})
    endif()
    
    #stage
    message(STATUS "${MESSAGE_PREFIX}commit to branch ${${phCURRENT_BRANCH_NAME}}")
    execute_git(add --all .)
    if (NOT ${comres} EQUAL 0)
      message(FATAL_ERROR "${MESSAGE_PREFIX}git add failed: ${comerr}")
    endif()
    
    #commit
    if (DEFINED AUTHORTEMPLATE AND NOT AUTHORTEMPLATE STREQUAL "")
      autocommit_author("${AUTHORTEMPLATE}" nauthor)
      execute_git(commit -m ${COMMIT_MESSAGE} --author=${nauthor})
    else()
      execute_git(commit -m ${COMMIT_MESSAGE})
    endif()
    if (NOT ${comres} EQUAL 0)
      message(FATAL_ERROR "${MESSAGE_PREFIX}git commit failed: ${comerr}")
    endif()
    
    execute_git(rev-parse HEAD)
    if (NOT ${comres} EQUAL 0)
      message(FATAL_ERROR "${MESSAGE_PREFIX}git rev-parse failed: ${comerr}")
    endif()
    set(${phGIT_COMMIT_SHA} "${comout}")
    set(statusout "")
  endif()

  if ("${statusout}" STREQUAL "" AND NOT "${CONFIGF_TO}" STREQUAL "" AND NOT "${CONFIGF_ARGN}" STREQUAL "")
    message("==do configure==")
  endif()

elseif(DEFINED postbuild)

endif()
